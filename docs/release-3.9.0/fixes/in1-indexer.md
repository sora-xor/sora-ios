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
- A count that changes or a row that repeats between two pages is still an
  invalid response when the checkpoint did not move. When it did move, it
  means a row was added while reading, and the read starts again.
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
  catalog. Callers that arrive during a read wait for it. A live catalog is
  reused for 10 minutes (assets) or 1 minute (pools), as before. After a
  failed read the next attempt waits 15 s, 30 s, 60 s, 120 s, then 300 s;
  until then callers get the last good catalog, or the error, without any
  request. `PriceInfoService` no longer keeps its first answer for the rest
  of the session.

### 3. A failed price load never looks like a zero balance

- The wallet totals ("Liquid assets" and "Pooled assets") show
  **"Price unavailable"** in small secondary text when no price is known, and
  the loading placeholder while loading. "$0" appears only when prices are
  known and the value really is zero.
- While the notice is shown the wallet asks again by itself (20 s, then twice
  as long each time, up to 5 minutes), so it is replaced without any action
  by the user. The price service applies its own backoff, so asking is cheap.
- A pool's TVL (Explore and pool details) keeps its loading placeholder when
  the base asset has no price, instead of "$0". The Explore pool list is not
  kept for the session when it was valued without prices.
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
  and recover by themselves. Prices from the last successful load (at most 24
  hours old) are shown when PI is down.
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
| `PIIndexerAdvancingReadTests` (16) | The production client against a stub indexer that indexes a block between every two requests: the asset catalog and fiat prices load, and Activity reaches page 2. A backwards step and a count change are retried. A persistently inconsistent, stale or unreachable indexer gives the last good catalog, also to a new client. Wrong data is not hidden. Request counts are bounded. A device clock hours off still loads prices; a `Date` header days off is not trusted. |
| `PIIndexerClockTests` (2) | The `Date` header rule. |
| `PICatalogStoreTests` (6) | Twelve concurrent callers cause one read; reuse while fresh; backoff 15/30/60 s; last good value; recovery. |
| `WalletFiatTotalTests` (5) | A wallet with tokens and no prices reads "Price unavailable", never "$0"; with prices it reads the sum; English and Japanese text. |
| `PIMarketCapFromCatalogTests` (2) | Market data comes from the shared catalog; another endpoint is refused before any read. |
| `PIRemoteFlagMaskingTests` (4) | The live flags are masked and stored as off in an App Store build. |
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
never stand in for a failed live read. Results are in "Verification" below.

## Verification

Xcode 27.0, simulator `SORA-Fix-net` (iPhone 17 Pro, iOS 27.0), 11 October
2026.

| Check | Result |
|---|---|
| `build-for-testing`, Debug, pinned packages | TEST BUILD SUCCEEDED |
| New test classes (48 tests) plus `PIMobileConfigFallbackTests` and `ProductSurfacePolicyTests` | all pass |
| Whole `SoraPassportTests` target | 534 tests, 0 failures, 4 skipped (the opt-in live tests) |
| Release device compile (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) | BUILD SUCCEEDED |
| `Package.resolved` | unchanged |

**Live indexer, production client, empty cache each round** (01:25 to 01:34
UTC, from the build Mac, about 250 ms per request):

| Run | Assets (957, 10 pages) | Pools (432, 5 pages) | Fiat prices | Market data |
|---|---|---|---|---|
| 2 rounds | 2 of 2 | 2 of 2 | 2 of 2 | 2 of 2 |
| 10 rounds | 10 of 10 | 10 of 10 | 10 of 10 | 10 of 10 |

12 of 12 rounds in total; the audit measured 0 of 20 on the candidate. One
asset walk took 5.3 to 7.3 s and one pool walk 2.8 to 3.1 s. The second live
test also read health, the configuration (flags `true`, `true`, `true`, masked
for an App Store build), referral rewards and page 2 of an active account's
Activity (20 rows of 304, signer-only coverage).

**In the app** (Debug build on the simulator, new wallet): the wallet list
shows a 24-hour change for each asset (XOR -10.37%, VAL +75.26%), Explore
shows prices and market caps (XOR $5.4), and the Explore pool list shows TVL
values and no APY. The wallet is empty, so its totals read "$0" with prices
known. The "Price unavailable" state was exercised in unit tests only; PI was
reachable throughout.

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
- **Scheduled check:** run `PIIndexerLiveTests` daily, like the two
  live-runtime tests, so a wire change on PI is noticed the same day.

## Not changed

- `PIMarketCapCatalogValidator.requireExactRequestedCoverage` still requires
  every requested asset to be in PI's catalog. On 11 October PI's 957 assets
  were exactly the 957 `Assets.AssetInfos` entries on chain, and all 185
  bundled whitelist assets were among them.
- Prices shown from the last good catalog carry no "updated … ago" marker.
- The Polkamarkt queries (markets, snapshots, positions, trades, signals) were
  not part of the wire review; App Store builds do not show Polkamarkt. They
  get the forward-only rule and the per-request retry, and keep their
  per-page cache.
