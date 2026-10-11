# in1-indexer: prices and market data load from the live indexer (I4)

Audit finding I4 (also `ios-signing.md` S-1, `live-env.md` LIVE-1, LIVE-6 and
LIVE-13, `verdicts.md` S-1 and DYN-IOS).

## Why

On 10 October the app's own client failed to load asset prices from the live
indexer (`https://pi.soramitsu.io/graphql`, "PI") 20 times out of 20. Every
user saw a wallet total of "$0" and loading placeholders where prices belong.
Balances and sending were not affected.

There were two independent causes, and a third problem behind them:

1. **Decoding.** PI sends `volumeDayUSD` and `volumeWeekUSD` as JSON numbers.
   The client decoded every quantity from a JSON string only, so the first
   asset of the first page failed and the whole catalog with it. A unit test
   asserted this behaviour.
2. **Checkpoint rule.** Every request was bracketed by two health requests
   that had to be identical, and every page of a multi-page read had to carry
   the same health record. PI indexes a block every six seconds and its
   finalized head moves about three seconds earlier, so a 30-request read of
   the asset catalog could not complete for a user more than about 110 ms
   from the server. `staleCheckpoint` had no retry and no fallback.
3. **No backoff, no sharing.** Each price consumer walked the catalog on its
   own (the fiat service and the market-cap service in parallel, up to 60
   requests per wallet refresh), and a failed walk was repeated on the next
   screen visit.

The review of every other production query against the live endpoint found
one more mismatch: PI identifies a pool as `<base>-<target>`, while the APY
lookup searched the catalog for the pool's reserves account. Pool APY could
not be found for any pool.

## What changed

All changes are in the indexer client and its consumers. No key, account,
signing or migration code is touched.

### 1. Decoding (`PIIndexerClient.swift`)

- The asset query asks only for what the wallet shows:
  `id priceUSD liquidity priceChangeDay`. The two volume fields, `supply`,
  `liquidityBooks` and `priceChangeWeek` had no reader. `PIAsset` has the same
  four fields. Pages are about 40% smaller.
- `PIQuantity` now decodes from a JSON string **or** a JSON number. A number
  is read from the exact text of the response (`PINumberLexemes`, built on the
  existing strict parser, and only when a number is actually met), never
  through `Double` or `Decimal`, so no digit is lost. Exponent forms are
  rewritten digit for digit (`1e-7` is `0.0000001`). A plain `JSONDecoder`
  without the response text still rejects a number, as before.
- `priceChangeDay` accepts a number (today's form) or a decimal string.
- Review of the other production queries, sent to the live endpoint on
  11 October with the app's headers and compared field by field with the
  decoders: `MobileHealth`, `MobileConfig`, `MobileConfigBase`,
  `MobileAssets` (10 pages, 957 assets), `MobilePoolXYKs` (5 pages, 432
  pools), `MobileReferrerRewards` and `MobileHistory` (772 rows of 8 active
  accounts). The two volume fields were the only type mismatch. The two
  rejections that already have fallbacks are unchanged (history all-roles
  filter, referral rewards ordered by timestamp).

### 2. Checkpoint rule, retry, last good value, backoff

- **Forward-only rule**, the one the Android client applies
  (`requireSettledResponseCheckpoint`, `isConsistentPageCheckpoint`).
  `settledResponseCheckpoint` accepts a postflight health record of the same
  indexer (service, endpoint, schema, chain, genesis) at the same or a later
  block and attributes the response to the later checkpoint, which bounds
  every row. `validatePageCheckpoint` lets the pages of a live read follow
  the indexer forward. Still rejected: a checkpoint that went backwards,
  another service or chain, another block at the same height, cached pages
  from different checkpoints, and any mix of cached and live pages.
- **The forward move is bounded** (review round 2). A postflight more than
  20 blocks (two minutes) after its preflight, or a multi-page read whose
  pages are more than 50 blocks (five minutes) apart, is `staleCheckpoint`
  and the read starts again. This is the case of an app that was suspended
  in the middle of a read: pages received hours ago are never completed
  with a new checkpoint and saved as fresh. Android has no such bound.
- A count that changes or a row that repeats between two pages is still an
  invalid response when the checkpoint did not move. When it did move,
  between two pages or between one page's own two health reads, it means a
  row was added while reading, and the read starts again.
- **A PI that is not ready is not another service** (review round 2).
  `validateHealth` reports a wrong service, schema, chain, network or
  endpoint as `invalidServiceIdentity`, as before. The readiness fields
  (`ok`, `repositoryReady`, `workerAvailable`, `workerReady`,
  `workerReadinessReason`, `workerLifecycle`, `workerStartupComplete`) of
  the right service now give `staleCheckpoint`, so a PI that is restarting
  takes the bounded retry and then the last good value, also on a cold
  start.
- **Bounded retry.** A read that ends in `staleCheckpoint` is run again at
  most twice (0.4 s and 0.8 s apart). Exactly one level retries: a single
  request retries itself, a multi-page read retries as a whole.
- **Last good value.** A complete asset, pool or referral-reward catalog is
  saved after every successful live read (one file in `Caches/PIIndexer`, at
  most 24 hours old when used). When PI is unreachable, overloaded
  (408/429/5xx) or cannot give a consistent fresh checkpoint after the retry,
  the last good catalog is returned, also after an app restart. A response
  that does not decode or fails validation is never replaced by older data.
  Activity falls back to its own validated history cache in the same cases.
- **Fewer requests.** The postflight health read of one page is the preflight
  of the next: a walk costs two requests per page plus one (21 for the asset
  catalog instead of 30). All production clients share one URL session, so
  the connection is reused.
- **One shared catalog with backoff** (`PICatalogStore`, `PICatalogs`). The
  fiat service, the market-cap operation and the APY service read the same
  catalog, and one read serves all callers. A live catalog is reused for 10
  minutes (assets) or 1 minute (pools), as before. After a failed read the
  next attempt waits 15 s, 30 s, 60 s, 120 s, then 300 s; until then callers
  get the last good catalog, or the error, without any request.
  `PriceInfoService` no longer keeps its first answer for the rest of the
  session.
- **Ages count the time the phone sleeps** (review round 2). The store
  measures freshness, backoff and the 24-hour limit with
  `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)`, which keeps counting while
  the device is asleep; `ProcessInfo.systemUptime` does not. Prices loaded
  at 09:00 are old at 12:00 even if the phone was locked in between. When
  the app returns to the foreground the backoff is cleared and the screens
  ask again. A snapshot read from disk keeps the age it had when it was
  saved, so it cannot be shown for more than 24 hours in total.
- **A caller does not wait when there is anything to show** (review rounds
  2 and 3). While a read is on its way the store returns the catalog it
  holds at once, whatever its age up to 24 hours. It is returned as current
  when it is live, younger than 30 minutes (assets) or 10 minutes (pools)
  and PI answered the last time it was asked; otherwise it carries its
  time. On the first call of a run the store also reads the catalog an
  earlier run saved on disk (`savedAllAssets`, `savedAllPoolXYKs`: no
  request), so a cold start shows yesterday's prices with their time
  instead of waiting for the walk. Only a caller with nothing at all to
  show waits. The store posts `PICatalogs.pricesDidChange` when a read
  ends; the wallet lists, Asset Details, Explore and pool details then draw
  again.
- **One rule for old data** (review rounds 2 and 3). The store keeps
  showing its last good catalog after exactly the failures the client
  accepts for its saved snapshot (`PIIndexerClient.allowsLastGoodValue`: PI
  unreachable, overloaded, not ready, or without a consistent fresh
  checkpoint). Once PI has answered with a response that does not decode or
  fails validation, that is an error in the store too: the wallet says
  "Price unavailable" instead of showing the prices from before, also while
  the next read is on its way and after a return to the foreground, until a
  read succeeds or fails in the accepted way.
- **An offline catalog read fails at once** (review round 3). The shared
  catalog client has its own URL session with `waitsForConnectivity` off.
  The other production reads (Activity, configuration, referral rewards)
  keep the session that waits.

### 3. A failed price load never looks like a zero balance

- The wallet totals ("Liquid assets" and "Pooled assets") show
  **"Price unavailable"** in small secondary text when no price is known, and
  the loading placeholder while loading. "$0" appears only when prices are
  known and the value really is zero.
- While the notice is shown the wallet asks again by itself (20 s, then twice
  as long each time, up to 5 minutes), so it is replaced without any action
  by the user. The price service applies its own backoff, so asking is cheap.
- A pool's TVL (Explore and pool details) is not shown as "$0" when the base
  asset has no price. The Explore pool list keeps the reserves it read from
  the node for the session and works the values out again from them
  whenever prices change (review round 3; see there).
- **The other screens** (review round 2). An unknown price was still turned
  into 0 on the screens behind the wallet. Now:
  - Asset Details: the price reads "Price unavailable"; the value of the
    holding and of the frozen balance, and the rows of the frozen-balance
    sheet, have no fiat text. The screen draws at once from balances
    (Send, Receive and Swap included) and fills prices in when they arrive.
  - Explore currencies: a row without a price shows no price and no market
    cap, and sorts last.
  - Swap, send, add and remove liquidity, farm rewards: the network fee
    and "minimum received" rows have no fiat text ("0.0007 XOR", not
    "0.0007 XOR $0").
  - Farms: TVL and APR have no text when a price they need is not known.
- **Old prices say so** (review round 2). When the wallet total is valued
  with the last good catalog because PI cannot be read, a line under it
  reads "Prices as of 09:02" (with the date when it is not today;
  Japanese: "09:02 時点の価格"), and the wallet keeps asking for current
  prices.
- **Placeholders end** (review round 2). Once the price read has finished,
  a wallet asset or pool row without a price shows nothing where the value
  and the 24-hour change go, instead of a loading placeholder that never
  ends. The same for TVL in the Explore pool list and in pool details.
  These screens value themselves again when prices arrive. The Explore pool
  cell clears what a reused cell showed before.
- **Explore pools reload** (review round 2). When the node gives no pools
  the list asks again after 2 s, 4 s, 8 s and so on up to one minute, no
  longer every 2 s, and stops when the screen that owns it is released.
- Pool APY is looked up by asset pair. PI publishes `strategicBonusApy` as 0
  for all 432 pools today; a rate of zero is not shown as "0% APY". In the
  Explore pool list the APY loading placeholder ends once the read has
  finished without a rate; before, it stayed for good.

### 4. Device clock

- PI's timestamps are compared with the time in the `Date` header of the same
  response, not with the device clock, when the two are within 26 hours of
  each other (`PIIndexerClient.responseClock`). A device whose clock is
  minutes or hours off, or set to the wrong time zone, loads prices and
  Activity normally.
- A missing or malformed header, or one further than 26 hours from the device
  clock, falls back to the device clock, so the check is never weaker than
  before.
- Cached entries record the clock offset they were saved with, so the last
  good catalog also works on a device with a wrong clock.

### 5. Remote feature flags in App Store builds

The production PI publishes `nexusAvailable`, `polkamarktVisible` and
`tairaDefaultVisible` as `true`.

- `applyPIMobileConfig` first passes the configuration through
  `ProductSurfacePolicy.admitted`. Under `F_RELEASE` this sets all five
  optional flags to off, so an App Store build stores them as off and
  publishes no mutation authority. Nodes, the explorer URL and the type
  registry URL pass through.
- The stored flags are also read through the policy: `nexusEnabled`,
  `polkamarktEnabled` and `isTairaEnabled` are `false` in an App Store build
  even when an earlier build (TestFlight, or a candidate before this fix)
  stored `true`. A Taira choice made in a tester build is kept in storage and
  ignored.
- Readers of the stored flags outside the UI entry points, traced:
  - `NexusTransactionCoordinator.sendAvailabilityAllows` (send gate; it also
    needs `ProductionMutationQualification.nexusSends`, which is `false`);
  - `PolkamarktTransactionCoordinator` (quote, state and trade gates; reached
    only from the Polkamarkt screens);
  - `WalletRecoveryExporter` lists the keys for the recovery export.
  No background task, network request or account derivation reads them.
  With the mask all of these read "off" in an App Store build.

## User-visible effect

- USD values appear again in the wallet list, the totals, asset details,
  send, swap, pools and Explore, and the 24-hour change appears next to each
  asset.
- When prices cannot be loaded the totals read "Price unavailable", not "$0",
  and recover by themselves. No other screen shows "$0" for a value whose
  price is not known. Prices from the last successful load (at most 24
  hours old) are shown when PI is down, with "Prices as of <time>" under
  the wallet total.
- Prices are refreshed when the app comes back after the phone was locked
  for a while.
- No APY is shown for pools while PI reports 0 (the same as before this fix,
  where the lookup could not match).
- Nothing changes for keys, accounts, balances, sending or receiving.

## Tests

New file `SoraPassportTests/Common/Modernization/PIIndexerLiveContractTests.swift`
and fixtures in `PIIndexerFixtures/` (11 responses captured from the live
indexer on 11 October, unedited, 48 KB).

| Class | What it proves |
|---|---|
| `PIIndexerWireContractTests` (13) | Captured asset, pool, history, referral-reward, health and config responses decode through the production decoder and pass the production validators. The response that failed on 10 October (numeric volumes) decodes. A numeric quantity keeps every digit. |
| `PIIndexerAdvancingReadTests` (25) | The production client against a stub indexer that indexes a block between every two requests: the asset catalog and fiat prices load, and Activity reaches page 2. A backwards step and a count change are retried. A persistently inconsistent, stale or unreachable indexer gives the last good catalog, also to a new client. Wrong data is not hidden. Request counts are bounded. A device clock hours off still loads prices; a `Date` header days off is not trusted. |
| `PIIndexerClockTests` (2) | The `Date` header rule. |
| `PICatalogStoreTests` (22) | Twelve concurrent callers cause one read; reuse while fresh; backoff 15/30/60 s; last good value; recovery. Round 2: a clock that jumps three hours forces a new read; the default clock counts sleep; the foreground clears the backoff; a disk snapshot keeps its real age; a response that cannot be used is not replaced by older data; a recent catalog is served at once while its refresh runs; old prices carry their time. |
| `PIPriceDisplayTests` (12) | Round 2. The production wallet service and cell through "Price unavailable", old prices with their time, and current prices; the wallet asks again on `pricesDidChange`; Asset Details, the network fee row, Explore currencies, Explore pools and farms show no "$0" for an unknown price; the Explore pool reload backs off and stops when released. |
| `WalletFiatTotalTests` (5) | A wallet with tokens and no prices reads "Price unavailable", never "$0"; with prices it reads the sum; English and Japanese text. |
| `PIMarketCapFromCatalogTests` (2) | Market data comes from the shared catalog; another endpoint is refused before any read. |
| `PIRemoteFlagMaskingTests` (4) | The live flags are masked and stored as off in an App Store build. |
| `ExplorePoolScanTests` (5) | Round 3. The pool reserves are read from the node once whatever the prices; concurrent callers share the scan; an empty scan is repeated; two "prices changed" notifications without prices cause no second scan and no placeholder rows; prices that arrive later value the list on screen. |
| `PIActionsDoNotWaitForPricesTests` (5) | Round 3. Receive shows its code, Swap its details, and Supply and Remove Liquidity their fee while the price and APY reads are held back; the fiat texts and the APY are filled in when they arrive. |
| `PIIndexerLiveTests` (2, opt-in) | The production client against the live indexer. |

Changed tests in `WalletModernizationTests.swift` (they asserted the old
behaviour): the pre/post checkpoint test now checks forward acceptance and
backward rejection; the paging test accepts a forward move and rejects a
backward one; the asset-row test no longer requires a numeric volume to fail;
the flag test follows the build's surface policy.

**The new tests fail without the fixes.** With the old behaviour put back in
the production code for one run (quantities from strings only and the two
volume fields decoded; identical health required before, after and across
pages; device clock only; total formatted without a price check; flags passed
through), 14 of the new tests fail and the rest pass:

- decoding: `testResponseWithNumericVolumesDecodes`,
  `testNumericQuantitiesFromTheLiveResponseAreExact`,
  `testQuantityAcceptsStringOrNumberWithoutLosingPrecision`;
- checkpoint: `testAllAssetsCompletesWhileTheIndexerAdvancesOnEveryRequest`,
  `testFiatPricesComeFromAWalkOverAnAdvancingIndexer`,
  `testABackwardsCheckpointIsRetriedAndThenAccepted`,
  `testACountThatChangesWhileTheIndexerAdvancesRestartsTheWalk`;
- clock: `testADeviceClockThatIsHoursOffStillLoadsPrices`,
  `testLastGoodCatalogSavedWithAWrongDeviceClockIsUsable`,
  `testServerDateWithinTheTrustedSkewReplacesTheDeviceClock`;
- wallet total: `testWalletTotalWithoutPricesIsANoticeNotZero`,
  `testFiatServiceReportsNoPricesWhenTheCatalogCannotBeRead`;
- flags: `testAppStoreBuildMasksEveryOptionalFlagThePISends`,
  `testAppStoreBuildStoresTheLiveFlagsAsOff`.

The tree was restored from git afterwards. For the live indexer the "before"
is the audit's own measurement on commit `a521a376`: 0 of 20 and 0 of 5.

### Live test

```
TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1 TEST_RUNNER_SORA_LIVE_PI_ROUNDS=10 \
xcodebuild test-without-building ... \
  -only-testing:SoraPassportTests/PIIndexerLiveTests
```

Each round uses a new client with an empty cache, so a last good catalog can
never stand in for a failed live read. Since review round 3 the catalog
round uses the session of the app's shared catalog client, and also checks
that the two catalogs the walks saved read back whole. Results are in
"Verification" below.

## Verification

Xcode 27.0, simulator `SORA-Fix-net` (iPhone 17 Pro, iOS 27.0), 11 and 12
October 2026. The table is the state after review round 3.

| Check | Result |
|---|---|
| `build-for-testing`, Debug, pinned packages | TEST BUILD SUCCEEDED |
| Whole `SoraPassportTests` target | 581 tests, 0 failures, 4 skipped (the opt-in live tests) |
| Release device compile (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) | BUILD SUCCEEDED; the debug "PI unreachable" switch is not in the binary |
| `Package.resolved` | unchanged |

**Live indexer, production client, empty cache each round** (01:25 to 01:34
UTC, from the build Mac, about 250 ms per request):

| Run | Assets (957, 10 pages) | Pools (432, 5 pages) | Fiat prices | Market data |
|---|---|---|---|---|
| 2 rounds | 2 of 2 | 2 of 2 | 2 of 2 | 2 of 2 |
| 10 rounds | 10 of 10 | 10 of 10 | 10 of 10 | 10 of 10 |

12 of 12 rounds in total; the audit measured 0 of 20 on the candidate. One
asset walk took 5.3 to 7.3 s and one pool walk 2.8 to 3.1 s.

After review round 2 (bounded forward rule; 14:28 to 14:33 UTC): 10 of 10
and 5 of 5 rounds, so 15 of 15, with asset walks of 5.2 to 7.6 s and pool
walks of 2.8 to 4.5 s.

After review round 3 (through the catalog session that does not wait for
connectivity; 15:50 to 15:53 UTC on 11 October): 10 of 10 rounds for
assets, pools, fiat prices and market data, with asset walks of 5.4 to
7.2 s and pool walks of 2.9 to 3.2 s. In every round the two catalogs the
walks saved (957 assets, 432 pools) were read back whole by
`savedAllAssets` and `savedAllPoolXYKs`: the copy a new run shows first
works at the live size. That makes 25 of 25 rounds over the three runs.

The second live
test also read health, the configuration (flags `true`, `true`, `true`, masked
for an App Store build), referral rewards and page 2 of an active account's
Activity (20 rows of 304, signer-only coverage).

**In the app** (Debug build on the simulator, new wallet): the wallet list
shows a 24-hour change for each asset (XOR -10.37%, VAL +75.26%), Explore
shows prices and market caps (XOR $5.4), and the Explore pool list shows TVL
values and no APY. The wallet is empty, so its totals read "$0" with prices
known. The "Price unavailable" state was exercised in unit tests only; PI was
reachable throughout. (Round 2 looked at it through the production wallet
cell; see "Review round 2".)

Not verified: a signed App Store build on a device, a funded wallet, a real
device with a wrong clock, and iOS 16 to 26. Only iOS 27 was run. Reading a
quantity that PI sends as a JSON number depends on `JSONDecoder` reporting
the coding path of the value being decoded; no production query requests
such a field any more, so on an older system the worst case is the behaviour
before this change (a numeric quantity is rejected).

## Human and operations actions

- **Indexer owners:** set `nexusAvailable`, `polkamarktVisible` and
  `tairaDefaultVisible` to `false` on the production PI. The App Store build
  now ignores them, but any other client that trusts them shows a testnet and
  prediction markets.
- **Indexer owners:** `strategicBonusApy` is `0` for all 432 pools. Confirm
  whether that is intended. The app shows no APY while it is 0 and shows the
  value as soon as PI publishes one.
- **Indexer owners (optional):** serialize `volumeDayUSD` and `volumeWeekUSD`
  as strings like the other quantities. 3.9.0 no longer requests them.
- **Android:** `PolkaswapSubscriptionRepositoryImpl` looks up pool APY by
  `reservesAccount`, while PI's pool id is `<base>-<target>`. The same
  mismatch as on iOS; not changed in this task.
- **Release checklist:** add a step "on a funded wallet, the totals and each
  asset show USD values and a 24-hour change" and a step "with the device
  clock set one hour ahead, prices still load".
- **Android:** `PolkaswapIndexerClient` accepts any later checkpoint
  between a request's two health reads and between pages. Add the bounds
  iOS now has (20 blocks per request, 50 per walk).
- **Release checklist:** add a step "lock the phone for 15 minutes with the
  wallet open; on unlock, prices refresh within a few seconds".
- **Scheduled check:** run `PIIndexerLiveTests` daily, like the two
  live-runtime tests, so a wire change on PI is noticed the same day.
- **Release checklist** (review round 3): add the steps "in airplane mode,
  open the app and tap Receive: the QR code and the address appear at
  once", "after a night without the app, open it: yesterday's prices show
  with 'Prices as of', then change to current ones within about ten
  seconds", and "open Explore, Pools, switch airplane mode on and off a few
  times: the list stays and does not go back to placeholders".

## Review round 2 (11 October)

Thirteen findings from the adversarial review, in the order they were sent.
All were checked against the code; every one was real and is fixed.

| # | Finding | What was done |
|---|---|---|
| 1, 7 | Store ages measured with a clock that stops while the device sleeps; disk snapshot stamped with "now" | Continuous clock; backoff cleared on foreground; snapshot keeps its saved time. |
| 2, 6 | "$0" on Asset Details, Explore, fee rows, farms | Prices stay optional at every site; see "The other screens" above. |
| 3 | Forward rule without an upper bound | 20 blocks per request, 50 per walk. |
| 4 | Last good value older and wider than the notes said; no "as of" | Real age; one rule (`allowsLastGoodValue`) in client and store; "Prices as of" under the wallet total. |
| 5, 8 | Every caller waits for a refresh | A recent or last good catalog is returned at once; Asset Details draws first. |
| 9 | Row placeholders never end; reused Explore pool cell | Placeholders end after the price read; cell resets; screens value again on `pricesDidChange`. |
| 10 | Indexer moving within one page's two health reads gave `invalidResponse` | `PIQualifiedRead.checkpointAdvanced` restarts the walk. |
| 11 | A PI that is not ready reported as another service | Readiness gives `staleCheckpoint`. |
| 12 | Unbounded Explore pool reload | Backoff to one minute, weak owner. |
| 13 | No test through `AssetsItemService.setup()`; state never seen | `AssetsItemService` takes its price service by injection; tests through the service and the production cell. |

**The round-2 tests fail without the fixes.** With the old behaviour put
back for one run (snapshot stamped "now", last good value after any error,
every caller waits, no forward bound, no `checkpointAdvanced`, readiness as
`invalidServiceIdentity`, no backoff reset, prices defaulting to 0, no
`priceLoadFinished`, no "as of" text, no `pricesDidChange` observer), 19 of
the new tests fail: 5 in `PICatalogStoreTests`, 6 in
`PIIndexerAdvancingReadTests`, 8 in `PIPriceDisplayTests`. The tree was
restored afterwards.

**Looked at.** `testWalletCardShowsTheNoticeTheTimeOfOldPricesAndTheTotal`
drives the production `AssetsCell` and writes it as an image when
`TEST_RUNNER_SORA_RENDER_DIR` names a directory. The three states were
looked at that way (Japanese): the notice in small secondary text in place
of the total; "$25" with "20:20 時点の価格" under it; "$25" alone. A row
without a price shows its balance and nothing else.

The same states were **not** seen in the running app: the simulator wallet
left by the first round is behind a PIN this round does not have. Debug
builds have a switch for that check, compiled out of Release:

```
SIMCTL_CHILD_SORA_DEBUG_PI_UNREACHABLE=1 xcrun simctl launch <device> co.jp.soramitsu.sora.dev
```

With it the production client fails every request as "not connected". With
a catalog saved in `Library/Caches/PIIndexer` the wallet shows old prices
and their time; after deleting that directory it shows "Price
unavailable".

**Limits of round 2.**
- The "Prices as of" line is on the wallet total only. Asset Details,
  Explore, send and swap show values from the last good catalog without a
  marker (at most 24 hours old, and only while PI cannot be read).
- A snapshot's age across an app restart is measured with the device
  clock, because no monotonic clock survives a reboot. Moving the device
  clock back can make a saved snapshot unusable (it is then discarded);
  moving it forward only makes it expire sooner.
- When PI's answers cannot be decoded, a user who had prices sees "Price
  unavailable" rather than the earlier prices. This is deliberate (one
  rule, no stale data shown as current). Since round 3 the earlier prices
  are shown, with their time, for the seconds until PI's answer is known,
  also on a cold start.

## Review round 3 (12 October)

Two findings from the adversarial review. Both were checked against the
code, both were real, both are fixed.

| # | Finding | What was done |
|---|---|---|
| 1 | While no price was known, every `pricesDidChange` rescanned all pool reserves on the node (about 1,900 `state_getStorage` calls), with overlapping scans and a list that went back to placeholders | The scan is kept for the session and separated from the valuation; callers join a running scan; a notification only values the list again. |
| 2 | Receive, Swap and add/remove liquidity waited for a full walk of PI on every cold start and after every return to the foreground (5 to 8 s; 20 s if PI hangs; 30 s offline) | The store never makes a caller wait when a catalog under 24 hours old exists in memory or on disk; the four screens no longer wait for prices or APY at all; an offline catalog read fails at once. |

### 1. Explore pools: one scan, valued again when prices change

- `ExplorePoolsService` keeps what it read from the node (`ScannedPool`:
  pair, reserves, id) in a small actor, `ReserveScan`, for the life of the
  service, whether or not prices existed at the time. `getPools(with:)`
  works out TVL from the kept reserves and the prices it is given
  (`ExplorePoolsService.value`). A caller that arrives while the scan runs
  joins it; nothing cancels and restarts it. Only a scan that found no pool
  at all (the node was not ready) is not kept, and the next call scans
  again, at the view model's own pace (2 s up to one minute).
- Pools of equal value, which is all of them while no price is known, stay
  in the order of the scan, so the list does not reshuffle each time it is
  valued.
- `ExplorePoolsViewModelService`: a `pricesDidChange` notification no
  longer restarts a load that is still running; that round notices the
  change when it ends and values the list once more. When the list is on
  screen, the notification values it again and replaces it in one step:
  the rows no longer go back to "APY loading" placeholders each time.

Effect on the node: one scan per session of the Explore tab, as in 3.8.6,
whatever PI does. Before this fix a PI outage or a wire change made every
client with Explore opened send 4 scans in 5 minutes and one more every 5
minutes and on every return to the foreground.

### 2. Nobody waits for a walk when there is a catalog to show

**The store** (`PICatalogStore.snapshot()`):

| State when asked | Before | Now |
|---|---|---|
| Live, under 10 min (assets) | at once, no request | the same |
| Live, 10 to 30 min, last read succeeded | at once, read behind it | the same |
| Live, over 30 min (phone was locked, app was in the background) | wait for the walk | at once with "as of"; read behind it |
| From disk or after a failed read, backing off | at once with "as of" | the same |
| The same, after a return to the foreground | wait for the walk | at once with "as of"; read behind it |
| Cold start, catalog under 24 h on disk | wait for the walk | at once with "as of"; read behind it |
| Nothing under 24 h anywhere (first run, two days without the app) | wait | wait (a failed read then gives "Price unavailable") |
| PI's last answer could not be used | error | error, also during the next read and after a foreground return |

- `clearBackoff()` (return to the foreground) now only makes the next read
  start at once. It no longer forgets that the last read failed, so the
  catalog held keeps its time until a read succeeds, and a response that
  could not be used keeps older data hidden.
- The catalog saved on disk is read once per run, when the first caller
  finds nothing in memory. The request to PI is started first, so the file
  does not delay it. A saved catalog keeps its real age (23 hours on disk
  is not shown two hours later) and never replaces a live one.
- `PIIndexerClient.shared`, the client behind the two catalogs, uses a
  session with `waitsForConnectivity = false`. With no connection the
  first health request fails at once with "not connected", which is one of
  the failures after which the last good catalog is shown; the store then
  retries on its schedule (15 s, 30 s, ...) and on the next return to the
  foreground.

**The screens.** With the store alone, a user with no catalog under 24
hours (a first run, or the app unused for two days) would still wait. So
the actions no longer depend on a PI read:

- **Receive**: the QR code and the address are produced first. Prices are
  read only when the screen was opened with a requested amount, and the
  fiat text of that amount is filled in when they arrive.
- **Swap**: the details, and with them the Review button, come from the
  quote and the network fee. Prices are read beside them; when they arrive
  the balance and amount fiat texts and the fee row are filled in.
- **Supply Liquidity**: the fee, which enables the button, comes from the
  fee estimate alone. The APY row appears when the pool catalog has been
  read. An APY read for another pair is never shown.
- **Remove Liquidity**: the same for the fee; prices and APY are filled in
  when they arrive. While the APY is not known its row has no rate; it used
  to read "0% APY".

Pool details already drew its rows without the APY. Send (amount, confirm),
claim rewards and request-amount already read prices in the background.

### Tests of round 3

21 new tests, and 4 existing store tests changed to the new policy:

- `PICatalogStoreTests` (8 new): an old catalog is served at once with its
  time while its read is held back; after a return to the foreground a
  disk-sourced catalog is served at once and a failed live one keeps its
  time; the saved catalog is shown while the first read of a run is on its
  way, and when that read fails; it is read once; it is not shown beyond
  24 hours; with nothing saved the first caller waits; a saved catalog does
  not stand in for a response that could not be used. Changed: the tests
  for "read again after sleep", "reused while fresh", "failed refresh" and
  "a response that cannot be used" now state that the caller is served at
  once and the read replaces the catalog; the last one also covers the
  next read and the foreground.
- `PIIndexerAdvancingReadTests` (3 new): what a live read saved is read
  back by a new client with no request; a new run shows the saved prices
  through the store and `FiatService` while its first read is held back;
  the catalog session does not wait for connectivity.
- `ExplorePoolScanTests` (5) and `PIActionsDoNotWaitForPricesTests` (5):
  see the table under "Tests". They run the production
  `ExplorePoolsService` against a counting JSON-RPC engine, and the
  production `ReceiveViewModel`, `SwapViewModel`,
  `SupplyLiquidityViewModel` and `RemoveLiquidityViewModel` with price and
  APY services that do not answer until the test lets them.

"Served at once" is tested without timing: the loader is held, and the
test fails if the call has not returned after five seconds. The round-2
test `testARecentCatalogIsServedAtOnceWhileItsRefreshRuns` used a
stopwatch and counted the read before it had started; it failed once in
four runs of the whole target while another build was running, and now
holds the loader like the new tests. After that the store tests passed 25
times in a row and the other new classes 10 times in a row.

**The tests fail without the fixes.** With the old behaviour put back for
one run (wait unless live and under `staleFor`; no saved catalog;
`clearBackoff` forgetting the last error; session waiting for
connectivity; pool list not kept without prices; reload on every
notification; fiat awaited before the QR, the swap fee and the liquidity
fee; APY awaited with the fee), 21 tests fail: 9 in `PICatalogStoreTests`
(7 of the new ones and 2 of the changed ones), 2 in
`PIIndexerAdvancingReadTests`, all 5 in `ExplorePoolScanTests` and all 5
in `PIActionsDoNotWaitForPricesTests`. The two new tests that pass either
way cover new code only (reading the saved catalog back, and a saved
catalog after an unusable response). The tree was restored afterwards.

### Limits of round 3

- Old prices carry their time on the wallet total only. Swap, send,
  Receive and the liquidity screens show values from the catalog held
  without a marker, as in round 2; they are replaced when the read ends
  and the screen asks again (Swap asks on every new quote).
- Lists that only display prices still wait for the first catalog when
  none under 24 hours exists: the wallet rows keep their placeholders, and
  "All pools" and the farm lists appear when the read ends (5 to 8 s
  online, at once offline, 20 s if PI accepts the connection and does not
  answer). 3.8.6 had the same dependency with a 60 s timeout.
- With no connection at the first read of a run and nothing saved, prices
  appear with the store's next attempt (15 s later at the earliest, when a
  screen asks) rather than the moment the connection returns.
- Not seen in the running app: the simulator wallet is still behind a PIN
  this round does not have. The Debug build was installed and launched on
  the simulator and reaches the PIN screen; the four screens were driven
  through their production view models in tests.

## Not changed

- `PIMarketCapCatalogValidator.requireExactRequestedCoverage` still requires
  every requested asset to be in PI's catalog. On 11 October PI's 957 assets
  were exactly the 957 `Assets.AssetInfos` entries on chain, and all 185
  bundled whitelist assets were among them.
- Android has no upper bound on the forward checkpoint move; see "Human and
  operations actions".
- The Polkamarkt queries (markets, snapshots, positions, trades, signals) were
  not part of the wire review; App Store builds do not show Polkamarkt. They
  get the forward-only rule and the per-request retry, and keep their
  per-page cache.
