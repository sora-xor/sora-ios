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
  most 24 hours old when used). When PI gave no answer, or cannot give a
  consistent fresh checkpoint after the retry, the last good catalog is
  returned, also after an app restart. "No answer" is (since review round
  4, see there): no connection, a TLS failure, any status from a proxy,
  firewall or sign-in page, 408, 429, 5xx, a 200 that is not JSON, and a
  GraphQL error whose code says the failure is on PI's side. An answer from
  PI that does not decode, fails validation or refuses the query is never
  replaced by older data. Activity falls back to its own validated history
  cache in the same cases.
- **A lost request does not cost the walk** (review round 4). One request
  of a walk that is lost on the way, or fails for a moment on PI's side,
  is asked for again, at most twice per walk; the pages already read are
  kept.
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
  response, not with the device clock (`PIIndexerClient.responseClock`). A
  device whose clock is minutes, hours or days off, or set to the wrong
  time zone, loads prices and Activity normally. Until review round 4 the
  header was used only within 26 hours of the device clock; see there for
  why that limit was removed.
- A missing or malformed header falls back to the device clock.
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
October 2026. The table is the state after review round 3; the numbers of
round 4 are under "Review round 4".

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
  and the screen asks again (Swap asks on every new quote). Since round 4
  the send amount, request amount, claim rewards, farm details and pool
  list screens ask again by themselves when the read ends.
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

## Review round 4 (12 October)

Twelve findings from the adversarial review of the state after round 3
(`318a19ea`), two of them major, numbered here in the order they were
sent. Each was checked against the code. All twelve were real; all are
fixed. Findings 4 and 11 describe the same defect from two sides, and the
retry asked for in 4 is the one of finding 10.

| # | Severity | Finding | What was done |
|---|---|---|---|
| 1 | major | `MarketCapService` kept its own 10-minute cache on top of the shared catalog: yesterday's 24-hour change next to today's prices | The service keeps nothing; every call is worked out from the catalog as it is. |
| 9 | major | A JSON number with exponent `-9223372036854775808` trapped in `abs()` and stopped the app on every launch | The exponent is bounded on its digits before any arithmetic. |
| 2 | minor | Five screens asked for prices once and kept a catalog up to a day old while open | They ask again when a catalog read ends. |
| 3 | minor | A published price of "0" shown as "$0" for the holding and the total | Zero is "no price"; a wallet whose tokens have no price reads "Price unavailable". |
| 4, 11 | minor | Failures where PI gave no answer hid the catalog held | One list of "no answer" failures, which now includes service failures, TLS and transport errors, other statuses and non-JSON answers. |
| 5 | minor | Activity joined a current page and a page saved earlier | Pages of one list are of one kind; a retry row otherwise; the saved list says when it is from. |
| 6 | minor | A device clock more than 26 hours off failed every health check | The server's `Date` is used whenever it parses. |
| 7 | minor | A fractional JSON number in history data failed the whole Activity page for good | Read from the exact text, as quantities are. |
| 8 | minor | Referral reward amounts parsed with a trapping initializer | Whole numbers required at the client; failable conversion in the presenter. |
| 10 | minor | One lost request of the 21 ended the walk | The lost page is asked for again, twice at most per walk. |
| 12 | minor | The catalog walk stopped at 20 pages (2,000 assets) | 100 pages (10,000 rows); the live test watches the size. |

### 1. Market data follows the catalog

`MarketCapService` cached its answer for 600 s by the wall clock and could
not tell what it had sampled. On a cold start the store answers at once
with the catalog saved the day before; the service cached that. About six
seconds later the live catalog arrived, the "Prices as of" line went away,
and the wallet rows, Asset Details and Explore kept yesterday's 24-hour
change and liquidity for ten minutes, possibly with the wrong sign.

The service now holds no state. A call picks the requested rows out of the
catalog in memory (957 rows), through the same operation and the same
validation as before. `PriceInfoService` takes its two services by
injection so that this path can be tested with the production classes.

### 2. A number the app cannot hold is refused, not fatal

`PIQuantity.plainDecimal(fromJSONNumber:)` guarded with
`abs(exponent) <= 4096`. `Int("-9223372036854775808")` is `Int.min`, and
`abs(Int.min)` is an overflow trap. Neither the JSON grammar nor the strict
admission parser limits the digits of an exponent, and since the first
round every numeric quantity of every response reaches this function. The
asset catalog is read as soon as the wallet opens, so one such number in
it stopped the app on every launch.

The exponent's digits are now counted (sign and leading zeros aside, at
most four, at most 4096) before it is converted. `1.5e0003` still reads
`1500`.

### 3. Screens that asked for prices once

Since round 3 the store answers at once with the catalog it holds, up to
24 hours old, and reads PI behind the caller. Send (amount), request
amount, claim rewards, farm details and the pool list read prices once in
`viewDidLoad` and never again. Send opened within the seconds of a
cold-start walk showed the fiat value at yesterday's price for as long as
it stayed open.

Each of them now keeps a `PIPricesObservation` (a small object that calls
back on `PICatalogs.pricesDidChange` and stops when released) and asks
again:

- Send: only the balance text and the value under the amount are written
  again. A warning shown in that place (not enough balance, not enough XOR
  for the fee) is left as it is. The amount, the recipient and the button
  do not change.
- Request amount and claim rewards: their `fiatData` already redraws.
- Farm details: valued again without first being drawn with no values.
- Pool list: rebuilt from the pools it shows, but not while it is being
  edited or searched.

### 4. A price of zero

PI publishes `priceUSD: "0"` for an asset it could not price. In the
captured page that is bridged ETH (`0x0200070000...`), which has liquidity
and a daily volume. The wallet showed "$0" for the holding and, for a
wallet holding only that, "$0" as its total: the state item 3 of this task
removed for a failed price load.

- `PIAsset.fiatData` (used by `FiatService` and the legacy fiat operation)
  gives such an asset no price. Every screen already treats a missing
  price as unknown: no fiat text on the row, on Asset Details "Price
  unavailable", in Explore no price and last in the order, no TVL.
- The liquid total reads "Price unavailable" when the wallet holds tokens
  and none of them has a price. A wallet that holds nothing reads "$0";
  a wallet with some priced tokens reads the sum of those, as before. The
  pooled total follows the same rule. The wallet does not keep asking in
  this state: the prices were read.

The same convention was already in place for a published APY of 0.

### 5. "PI gave no answer" and "PI's answer cannot be used"

The store hides the catalog it holds after a failure that is not on the
accepted list, so the wallet drops to "Price unavailable" and every other
fiat text goes away; Activity shows an error instead of its saved list.
The list was too short. Now accepted, with the last good value shown under
its time:

| Failure | Before | Now |
|---|---|---|
| No connection, timeout, DNS, connection lost | accepted | accepted |
| HTTP 408, 429, 5xx | accepted | accepted |
| Stale or inconsistent checkpoint, PI not ready | accepted | accepted |
| HTTP 200 with GraphQL errors that are all `INTERNAL_SERVER_ERROR`, a timeout code, `SERVICE_UNAVAILABLE` or a rate limit | hidden (`graphQLErrors`) | accepted (`serviceFailure`) |
| TLS cannot be established, untrusted or wrongly dated certificate | hidden | accepted |
| Other transport errors where nothing readable arrived (`badServerResponse`, `cannotParseResponse`, `cannotLoadFromNetwork`, a sign-in requirement) | hidden | accepted |
| HTTP 3xx (never followed), 401, 403, 404 and other statuses | hidden | accepted |
| HTTP 200 that is not `application/json` (a sign-in page) | hidden (`invalidResponse`) | accepted (`foreignResponse`) |
| A JSON answer that does not decode or fails validation, another service or chain, a refused query (GraphQL refusal such as `BAD_USER_INPUT`, HTTP 400 or 422), a cancelled request | hidden | hidden |

A TLS failure is on the accepted list on purpose, although an earlier test
said otherwise. Nothing is read from a connection that failed TLS. What is
shown is what PI itself said earlier, validated then, marked with its time
and at most 24 hours old; a network that can break the connection could
already cause exactly that by dropping it.

`extensions.code` is decoded from GraphQL errors. One refusal among the
errors makes the response a refusal, and so does a missing code, so the
fallbacks for the two known refusals (history all-roles filter, referral
rewards order) work as before. The raw server text is still not kept in
the error.

**Lost requests.** A catalog walk is 21 sequential requests (assets) or 11
(pools), and only a stale checkpoint was retried. One lost request threw
away every page already read, and the wallet waited 20 s or more for the
next try. Now a request that fails in a way that often does not repeat is
asked for again, keeping the pages read:

- what counts: connection lost, a failed TLS handshake, an unreadable
  response, HTTP 500/502/503/504, a service failure reported by PI;
- at most two more tries per logical read (a walk, or a single request
  with its health reads), 0.5 s and 1 s apart;
- a timeout gets one more try, and only when PI already answered earlier
  in the same read. A timeout before anything was read is what "no
  connection" looks like on the session that waits for one; trying again
  would only keep the saved copy waiting behind a second timeout;
- no connection, DNS failure and a rate limit are not tried again;
- the checkpoint rules (forward only, bounded) apply to the page that then
  arrives like to any other. The retry sits at the level that already
  retries a stale checkpoint, so nothing retries at two levels.

### 6. Activity: one list, one moment

Activity's saved pages are keyed by address, page size and page number.
A current page 1 followed by a page 2 saved hours earlier, when the
account had fewer transactions, leaves rows out; the other way round
shows rows twice. The fallback existed before this task for network
errors; this task had widened it to every stale checkpoint, a condition
that can begin between two page loads.

- `SubqueryHistoryOperation.cachedAt` and `HistoryPage.cachedAt` say when
  a page was saved (`nil`: read just now).
- `ActivityViewModel` puts a page under the list only when it continues
  it: current under current, or saved under a saved page that is not
  newer. Otherwise the list stays as it is and one row is added at its
  end, the existing "Some data is not up to date / Refresh" row, which
  loads the list again from its start. Scrolling to the end asks again
  and never adds a second row; when a page that continues the list
  arrives, the row goes away.
- A list that is the saved copy has one quiet line above it: "Activity as
  of 09:02. Newer transactions will appear when the list can be updated."
  (Japanese: 「09:02 時点のアクティビティです。一覧を更新できるようになると、
  新しい取引が表示されます。」), with the date when it is not today.

### 7. Device clock

The server's `Date` replaced the device clock only within 26 hours of it,
"so that the check is never weaker than the device clock alone". The
review is right that the limit bought nothing: the header arrives over the
same TLS connection as the timestamps it is compared with, and whoever
could forge one could forge the other. With the date set two days back or
forward by hand, every health check failed, the saved catalog did not
help (its offset was recorded as 0), and the user saw "Price unavailable"
and no Activity with no hint.

The server time is used whenever the header parses. The freshness rule is
unchanged: an indexer whose last block is more than five minutes old by
its own clock is refused on any phone.

### 8. Fractional numbers in history data

`PIJSONValue` (the type of a history row's `data`, `execution` and call
data) accepted 64-bit integers only and refused the page otherwise.
History rows carry computed USD values (`amountUSD`, `exchangeVolumeUSD`
and others). They are strings today, and the same indexer writes
`volumeDayUSD` as a number. A row does not change once written, so a page
with such a number could never be loaded again.

A fractional or larger number is now read from the exact text of the
response (`PINumberLexemes`, as for quantities), also as an array element
and under a member name that is itself a number. The validated history
cache writes it as its decimal text, which reads back as the same digits;
every reader of these values treats a number and its text alike.

### 9. Referral rewards

`validateReferrerRewards` accepted any non-negative decimal, and the
Friends screen converted with `BigUInt(stringLiteral:)`, which stops the
app on text that is not a whole number. The first wire review had only
seen a reward of "0". The live indexer was asked again: among the 100
newest of its 505 reward rows, three referrers had a reward that is not
zero, each a whole number of the smallest unit (`183330193640403131`, which
is 0.18 XOR). The page of one of them is the new fixture
`referrer-rewards-nonzero-page.json`.

The client now requires a whole number (`invalidQuantity` otherwise, a
handled error), and `FriendsPresenter.rewardAmount` converts with the
failable initializer and gives 0 for anything else.

### 10. Catalog size

`qualifiedAllAssets` and `qualifiedAllPoolXYKs` read at most 20 pages of
100, and the market data request accepted 2,000 assets. Past that the walk
failed with `paginationLimit`, which also hides the last good catalog: no
price anywhere, for every user, with no recovery short of an app update.
Registering an asset on SORA needs no permission; PI lists 957.

Both walks now get the 100 pages the pager already allowed (10,000 rows),
and the market data bound is the same number. The live test fails when a
catalog passes half of that, so growth is noticed years before it hurts.
A 100-page walk is 201 requests, about a minute; the screens do not wait
for it when a catalog under 24 hours old exists.

### Tests of round 4

34 new tests and 4 changed ones. New fixture:
`referrer-rewards-nonzero-page.json` (unedited, 1.5 KB).

| Class | New | What it proves |
|---|---|---|
| `PIRound4WireTests` | 9 | Extreme exponents are refused through `decodeResponse`; exponents within the bound keep every digit. The captured history page with four of its values rewritten as JSON numbers decodes exactly and comes back from the validated cache. GraphQL errors are told apart by their code. The two lists of failures. The captured non-zero reward page decodes, validates and converts; a reward that is not a whole number is a handled error and converts to 0. |
| `PIIndexerAdvancingReadTests` | 12 | A lost page, or a lost health read in the middle of a walk, costs one page. The retry is bounded; a timeout is tried once and only after progress; with no network nothing is asked twice. A service failure on one page is tried again; a PI that keeps failing, a sign-in page, 403, 404, a redirect and two TLS failures give the last good catalog. A device clock three days off loads prices and keeps its last good catalog; an indexer stale by its own clock is refused. A walk of 25 pages completes. |
| `PICatalogStoreTests` | 1 | With the app's own rule, the catalog held is shown under its time after seven kinds of "no answer". |
| `PIRound4PriceTests` | 8 | The production `PriceInfoService`, `FiatService` and `MarketCapService` over a store that serves a saved catalog and then a live one: the second answer has the live 24-hour change and liquidity. A published price of zero is no price; the production wallet service reads "Price unavailable" for a wallet holding only that asset, the priced part for a mixed one, "$0" for an empty one. The production Send and request-amount view models follow the prices when `pricesDidChange` is posted. |
| `PIRound4ActivityTests` | 4 | The production `ActivityViewModel`: a saved page is not put under current pages, one retry row is shown and goes away when the current page arrives; the saved list says when it is from, is not continued with an older saved page or a current one, and Refresh gives one consistent list. The notice text in English and Japanese. |
| `PIIndexerClockTests` | (2 changed) | The server's time is used at any distance from the device clock. |

Changed elsewhere: `testAnUnreachableIndexerGivesTheLastGoodCatalog`
counts the two extra tries, and
`testPICacheFallbackAllowsOnlyFailuresWherePIGaveNoAnswer` in
`WalletModernizationTests.swift` (renamed) states the new list. The test
that a `Date` far from the device clock is refused was replaced by the
test that such a phone loads prices (counted among the new ones). The
stub indexer of the tests can now lose a request and answer with another
content type. The live test also checks market data for the whole catalog,
a referrer with a non-zero reward, and the catalog size.

**The tests fail without the fixes.** With the behaviour before round 4
put back for one run, keeping only the new interfaces (exponent bounded
with `abs`; fractional generic numbers refused; every GraphQL error a
refusal; the short list of accepted failures; no retry of a lost request;
the 26-hour clock limit; 20 pages; any decimal reward amount; the
10-minute market data cache; zero as a price; the two tested screens
asking once; Activity appending every page and showing no notice), 28 of
the new and changed tests fail and one stops the test process:

- `PIRound4WireTests`: 6 fail, and
  `testAQuantityWithAnExtremeExponentIsRefusedAndTheAppKeepsRunning`
  crashes the runner at `abs(Int.min)`, which is the defect itself;
- `PIIndexerAdvancingReadTests`: 10; `PICatalogStoreTests`: 1;
  `PIIndexerClockTests`: 1;
- `PIRound4PriceTests`: 7; `PIRound4ActivityTests`: 3.

The four that pass either way cover new code only (exponents within the
bound, the captured reward page, the observation's lifetime, the notice
text). The tree was restored from git afterwards.

### Verification of round 4

Xcode 27.0, simulator `SORA-Fix-net` (iPhone 17 Pro, iOS 27.0), 12 October
2026 (JST), on the final commits of this round.

| Check | Result |
|---|---|
| `build-for-testing`, Debug, pinned packages | TEST BUILD SUCCEEDED |
| Whole `SoraPassportTests` target | 614 tests, 0 failures, 4 skipped (the opt-in live tests); 581 before this round |
| Release device compile (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) | BUILD SUCCEEDED; the debug "PI unreachable" switch is not in the binary |
| Debug build installed and launched on the simulator | starts and reaches the PIN screen |
| `Package.resolved`, `project.pbxproj` | unchanged |

**Live indexer, production client, empty cache each round** (through the
catalog session; 19:35 to 19:38 and 19:54 to 19:56 UTC on 11 October, from
the build Mac):

| Run | Assets (957, 10 pages) | Pools (432, 5 pages) | Fiat prices | Market data, whole catalog | Saved copies read back |
|---|---|---|---|---|---|
| 10 rounds | 10 of 10 | 10 of 10 | 10 of 10 | 10 of 10 | 10 of 10 |
| 6 rounds | 6 of 6 | 6 of 6 | 6 of 6 | 6 of 6 | 6 of 6 |

16 of 16 rounds, which makes 41 of 41 over the four rounds of this task
(the audit measured 0 of 20). An asset walk took 5.4 to 6.2 s and a pool
walk 2.9 to 3.0 s. Both runs of the second live test also read health, the
configuration, referral rewards (one account with a reward of zero, one
with 0.183330193640403131 XOR in two rows) and page 2 of an active
account's Activity (20 rows of 304). No request had to be asked for a
second time in these runs, so the new retry was exercised by the stub
indexer only.

### Decisions and limits of round 4

- **TLS failures show the last good value.** This reverses an assertion of
  the earlier test suite. See "5." above for why it is safe.
- **`Age` is not added to `Date`.** A shared cache in front of PI could in
  principle replay a health answer with its original `Date`. PI's
  requests are POSTs sent with `no-store`, which shared caches do not
  store; the 26-hour limit would not have caught a replay of minutes
  either.
- **A stale 24-hour change is impossible now, a mixed one is not marked.**
  Prices and market data of one `PriceInfo` come from two reads of the
  same store a few microseconds apart. If a refresh lands exactly between
  them, one answer mixes two catalogs until the `pricesDidChange` that the
  same refresh posts makes the screen ask again.
- **Activity's saved pages.** Two saved pages are accepted as one list
  when the lower one was saved at or after the upper one, which is the
  order in which scrolling saves them. Rows that arrived between the two
  saves can still appear twice, as they can between two current pages
  loaded minutes apart (numbered pages over a list that grows at the top;
  not changed here). Rows are no longer left out.
- **Send keeps a warning as it is** when prices change, and does not touch
  the field's colours.
- **A catalog beyond 10,000 rows** would fail as 2,000 did. The live test
  warns at 5,000. The lasting answer is a query for the wallet's own
  assets, which PI's schema allows; it was not built in this round.
- **Seen while testing Activity, not changed (the same code is in App
  Store 3.8.6).** `ActivityViewModel` counts a page as loaded only when
  the page adds a section for a day that is not on screen yet. A page whose
  rows all fall on a day already shown (an account with more than 50
  operations in one day) is merged into the list in memory but neither
  drawn nor counted: the spinner at the end stays, and each further scroll
  loads the same page and merges its rows again. This was reproduced with
  the production view model (two pages on one day: the page number stays
  at 1, the screen keeps 2 rows, the list in memory grows to 6). By
  reading, a page whose rows are all filtered out in the Activity of one
  asset is not counted either. Neither is an audit finding or a change of
  3.9.0; both need their own fix and a look at the screen. (Round 5 fixed
  the first of the two and looked at the screen; see "Review round 5",
  section 5. The second is still open.)
- **Not seen in the running app.** As in rounds 2 and 3, the simulator
  wallet is behind a PIN this round does not have, and this round did not
  remove it or create another. The Debug build was installed and launched
  and reaches the PIN screen. The new states were driven through the
  production view models and services in tests. They should be looked at
  on a device before release; see the checklist steps below.

### Human and operations actions of round 4

- **Indexer owners:** bridged ETH (`0x0200070000...`) is published with
  `priceUSD: "0"` although it has liquidity and a daily volume of about
  1,156 USD. The app now shows no price for it. Please check the pricing
  path for assets that have no direct XOR or XSTUSD pool.
- **Indexer owners:** keep `extensions.code` stable. The app now relies on
  `BAD_USER_INPUT` meaning "this query is refused" and
  `INTERNAL_SERVER_ERROR` meaning "try again"; a refusal sent as
  `INTERNAL_SERVER_ERROR` would be retried and then answered from the
  saved copy instead of selecting the fallback query.
- **Indexer owners:** keep referral reward amounts as whole numbers of the
  smallest unit, and keep the USD values of history rows either strings or
  numbers; the app reads both.
- **Scheduled check:** the daily `PIIndexerLiveTests` run now fails when a
  catalog passes 5,000 rows. That is the signal to build the query for the
  wallet's own assets.
- **Android:** check the same four points on Android: a second cache over
  the price catalog, the parsing of referral reward amounts, the class of
  GraphQL `INTERNAL_SERVER_ERROR`, and the page limit of the asset walk.
  None was looked at in this task.
- **Release checklist:** add the steps
  - "set the date two days back by hand: prices and Activity still load";
  - "on a Wi-Fi network with a sign-in page, before signing in: the wallet
    shows the last prices with 'Prices as of', not 'Price unavailable'";
  - "after a night without the app, open it and tap Send at once: the
    value under the amount changes to today's price within about ten
    seconds";
  - "open Activity, switch to airplane mode, scroll to the end: the list
    ends with 'Some data is not up to date / Refresh' and no row is
    repeated; open Activity again in airplane mode: one line says when
    the list is from";
  - "hold an asset the indexer has no price for: its row shows the
    balance and no '$0'";
  - "open Friends with a referrer account that has rewards: the total is
    shown".

## Review round 5 (12 October)

One finding from the adversarial review of the state after round 4
(`371f3387`), rated major. It was checked against the code and is real.

**The saved Activity list could not be refreshed, and its text promised an
update that never came.** When the indexer cannot be read, Activity shows
the list as it was last loaded, with the line "Activity as of 09:02. Newer
transactions will appear when the list can be updated." Nothing loaded the
list again when the indexer came back: no button, no timer, nothing when
the app or the tab returned (the tab is built once per account and loads
once). Only a transaction made in this wallet, an incoming-transfer event,
a change of language or killing the app replaced it. The saved copy itself
is older than this task; round 4 widened the cases that lead to it and
added the sentence. A state after a network failure with no way forward,
and a text that did not match the screen: hard rule 6.

### 1. The saved list: a Refresh button, and it loads again by itself

- **Refresh button.** The line that says when the list is from is now the
  first row of the list with a Refresh button under it (English "Refresh",
  Japanese 「更新」), the same control the screen already uses elsewhere. It
  loads the list again from its start. No new strings.
- **By itself.** While the list on screen is the saved copy, page 1 is
  asked for again after 15 s, then 30 s, 60 s, 120 s, 240 s, and every
  5 minutes from then on (`ActivityViewModel.refreshDelay`). One try is one
  read of page 1 (three requests when the indexer answers). The list on
  screen is replaced only when a current page 1 arrives; the saved copy
  again, or a failure, leaves the screen exactly as it is. Asking stops
  when the list is current.
- **When the app comes back** (`UIApplication.willEnterForegroundNotification`):
  asked at once, and the waits start again from 15 s.
- **When the screen is shown again** (the tab is selected, a pushed screen
  is closed): asked at once, unless page 1 was answered less than 15 s
  ago, so switching tabs quickly costs nothing.
- **"Could not load your activity"** (no saved copy to show) follows the
  same schedule and the same two triggers. It already had its Refresh
  button. If a saved copy can be read on a later try it is shown, with its
  Refresh row, and the list keeps asking.

### 2. One list at a time

The list is now changed from one place at a time (the main thread), and
every load remembers which list and which page it was started for. An
answer that arrives for a list that has been started again since, or for a
page that has arrived already, is dropped. Without this the quiet read of
page 1 could cross a Refresh by the user, and the second answer would be
put under the first as "page 2". The same crossing existed before between
two reloads started together (two transaction events) and between two
requests for the same next page. Both put rows into the list twice, and a
list with the same row in it twice stops the app when it is next drawn
(see "The tests fail without the fix" below).

### 3. What Refresh leaves behind when it fails

Refresh is now within reach exactly when the indexer is in trouble, so its
failure path was looked at. When page 1 cannot be loaded and there is no
saved copy, the screen showed "Could not load your activity" over the rows
of the list before, and the spinner started by Refresh never stopped (the
same in App Store 3.8.6). Now the rows are removed, the spinner stops, and
the text with its Refresh button stands alone.

### 4. The end of the list

Seen on the production screen while testing the new row (rendered in the
test host; screenshots under `work/net-shots/fix5/`):

- **A further page that cannot be read.** With page 1 current and no
  saved copy of page 2, a failed page 2 left the spinner at the end of the
  list turning for ever (the release checklist step of round 4, "switch to
  airplane mode, scroll to the end", only held when page 2 had been saved
  earlier). The list now ends with the "Some data is not up to date /
  Refresh" row in this case too. Showing the row asks once more; then the
  screen is at rest.
- **Nothing is asked past the end.** The view model did not look at
  `endReached`. A list of fewer than 50 operations asked for page 2 every
  time its last row was shown. Under a saved list that request can fail,
  which would now have put a second Refresh row at its end. The last page
  ends the list: no request, no spinner. The client's own limit of 20
  pages ends it the same way.
- **The row at the end of the list** had the rounded top corners of the
  first row of the card and looked like a second card. It now continues
  the card. The Refresh row with the long text got the side padding of the
  other rows (the text ran into the rounded corners).

### 5. A page whose rows are all on a day already shown

Round 4 wrote this down as seen and not changed (also in App Store 3.8.6):
a page was drawn and counted only when it added a section for a new day.
With more than 50 operations in one day, page 2 was kept in memory, never
drawn and never counted; every scroll read it again and kept it once more.
Since the end of the list is now honoured, such a list would have ended
there for good, so it is fixed here: a page that brought rows is drawn and
counted. One condition in `ActivityViewModel.show`, in a commit of its
own.

### Tests of round 5

15 new tests in `PIActivityRefreshTests` and one changed
(`PIRound4ActivityTests.testTheSavedListSaysWhenItIsFromAndStaysInOnePiece`
now expects the Refresh row). All run the production `ActivityViewModel`;
three of them run it under the production `ActivityViewController` in a
window of the test host and read the cells that are on screen. The
notification centre, the waits and the clock are passed in, so no test
waits for real time or posts an app-wide notification.

| Test | What it proves |
|---|---|
| `testTheSavedListBecomesCurrentByItself` | The scenario of the finding: saved list, nothing tapped, no transaction. Page 1 is asked for again and again with growing waits while the list stays; when the history service answers live the list is current, the Refresh row is gone, and nothing more is asked. |
| `testAListThatCouldNotBeLoadedLoadsByItself` | The same from "Could not load your activity", through the saved copy to the current list. |
| `testComingToTheForegroundLoadsTheListAgain` | The foreground notification asks at once and starts the waits over; a current list is left alone. |
| `testComingBackToTheScreenLoadsTheListAgain` | `viewWillAppear` asks, but not within 15 s of the last answer and not while the first load is on its way. |
| `testRefreshByTheUserWhileTheListAsksByItself` | The two loads cross: one list, no row twice; when it is the saved copy again the list keeps asking; when the indexer answers it stops. |
| `testTwoLoadsThatCrossShowOneList` | Two reloads, and two requests for the same next page, show each row once. |
| `testAFurtherPageThatCannotBeReadOffersRefresh` | A failed page 2 gives one retry row; the page goes in when it can be read. |
| `testNothingIsAskedPastTheEndOfTheList`, `testTheLastPageTheClientReadsEndsTheList` | No request past the last page or past the client's limit, and no row that offers what cannot be had. |
| `testAPageOfADayAlreadyOnScreenIsDrawnAndCounted` | Section 5. |
| `testTheSavedListKeepsTheNoticeAboutIncomingTransfers` | The Refresh row comes first; the notice about incoming transfers stays under it. |
| `testTheWaitsGrowAndStopAtFiveMinutes` | 15, 30, 60, 120, 240, 300, 300 s. |
| `testTheSavedListOnScreenHasARefreshButton` | On screen: the first row reads the "as of" text and "Refresh"; no spinner and no request for page 2 under a list that ended; a tap asks again and shows the same list while the indexer is away, and the current list without the row once it answers. |
| `testTheEndOfTheListOnScreenWhenAFurtherPageCannotBeRead` | On screen: the retry row, no spinner left, at most two more requests and then rest; the button loads both pages. |
| `testRefreshThatFailsLeavesNoRowsUnderTheError` | On screen: section 3. |

**The tests fail without the fix.** With the behaviour before this round put back
for one run, keeping only the new interfaces (no asking again of any kind;
the "as of" line without a button; every answer put into the list on
screen; a failed further page ignored and a failed page 1 left over the
rows; the end of the list not looked at; a page counted only when it adds
a day), 14 of the 15 new tests and the changed one fail. The one that
passes checks the schedule function alone. `testTwoLoadsThatCrossShowOneList`
fails on the rows held twice and then stops the test process when the
next page makes the view model build its list for the screen: UIKit does
not accept a list with the same row in it twice (an assertion in
`_UIDiffableDataSourceUpdate`). The app builds its list the same way, so
two reloads that crossed could stop the app, and section 2 removes that.
The tree was restored from git afterwards (`work/net-tools/fix5-mutate.py`,
`work/logs-ios-net/fix5/test-mut.log`).

### Verification of round 5

Xcode 27.0, simulator `SORA-Fix-net` (iPhone 17 Pro, iOS 27.0), 12 October
2026 (JST), on the final commits of this round.

| Check | Result |
|---|---|
| `build-for-testing`, Debug, pinned packages | TEST BUILD SUCCEEDED |
| Whole `SoraPassportTests` target | 629 tests, 0 failures, 4 skipped (the opt-in live tests); 614 before this round |
| Release device compile (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) | BUILD SUCCEEDED; the debug "PI unreachable" switch is not in the binary |
| `Package.resolved`, `project.pbxproj`, string tables | unchanged |
| The stashed in2-tx-reconcile work (`stash@{0}`) | still applies without conflict on the new commits (34 files; checked in a separate worktree, both stash entries untouched) |

The live indexer test was not run again: nothing under
`Common/Network/Subquery` changed in this round.

**On screen.** The four states were looked at as the production view
controller draws them, in a window of the Debug app on the simulator, with
the app's language set to Japanese: the saved list with its Refresh row,
the current list after the tap, the end of the list with the retry row,
and "Could not load your activity" alone. The rows under them are test
rows. The same states in the running wallet, with a real history and the
aurora behind the card, were not seen: the simulator wallet is behind a
PIN this round does not have, as in rounds 2 to 4.

### Decisions and limits of round 5

- **One row instead of two.** The review suggested adding the existing
  "Some data is not up to date / Refresh" row under the notice. That makes
  two lines that say the same thing. The line that says when the list is
  from carries the button itself.
- **"Bounded" means the wait is bounded, not the number of tries.** The
  list asks every 5 minutes for as long as it is behind and the app is in
  the foreground, also while another tab is shown. Stopping after some
  number of tries would bring back the state of the finding.
- **A failed quiet read does not take the saved list away**, also when a
  Refresh by hand at the same moment would end in "Could not load your
  activity" (the saved copy has passed its 24 hours, or the indexer
  answers with something the app cannot use). The line on the list stays
  true, and the button shows the present state when it is tapped.
- **The list jumps when it becomes current.** A user who has scrolled down
  in the saved list is taken back to a list of one page. The same happens
  today when a transaction arrives.
- **A current list is not loaded again when the app or the tab comes
  back**, as before. A transaction made on another device appears after
  the next transaction event, Refresh after a failure, or a restart.
- **Still not changed (also in App Store 3.8.6):** in the Activity of one
  asset, a page whose rows are all filtered out is not counted, so the
  pages after it are not reached and the spinner at the end stays.
  Counting it would need the screen to go on to the next page by itself,
  and reading page *n* costs *n* requests.
- **The asset screen's three recent operations** (`RecentActivityItemService`)
  have no "as of" line and are read again with every balance update; not
  changed.

### Human and operations actions of round 5

- **Release checklist:** replace the Activity step of round 4 with
  - "open Activity, switch to airplane mode, open the app again and go to
    Activity: the first row says when the list is from and has a Refresh
    button; tapping it changes nothing but the spinner comes and goes";
  - "switch airplane mode off and touch nothing: within about half a
    minute the list is current and the row is gone";
  - "the same, but leave the app and come back, or switch to another tab
    and back after 15 seconds: the list is current at once";
  - "with more than 50 operations: open Activity, switch to airplane mode,
    scroll to the end: the list ends with 'Some data is not up to date /
    Refresh' inside the same card and no spinner stays under it".
- **Android:** check what the Activity screen does after it showed a saved
  list; not looked at in this task.

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
