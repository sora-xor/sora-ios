# ik1-startup: startup can never hang on the splash (audit I1)

Task key `ik1-startup`. Branch `claude/release-fixes-20261011-ios-keys`.
Audit finding I1 (`ios-lockout.md` L-1; `verdicts.md` L-1 and DYN-IOS).

## Why

Startup ran in one chain: remote configuration (PI), then the genesis hash,
then the on-chain asset list, and only then the wallet storage checks and
routing (`SplashInteractor.startChain`). Everything a user needs to get into
the wallet, or to the recovery screen, was behind three network answers.

- The asset list was read over a socket of its own
  (`WebSocketService.shared`). Its URL was read once per process: the saved
  `lastSuccessfulUrl`, or `Set.first` of the bundled nodes on a fresh
  install. Nothing changed that URL and nothing failed it over.
- `AssetsInfoProvider` stopped paging silently when the first key page failed
  or took more than 10 seconds. It then asked for the values of an empty key
  list, got nothing, and called itself again without a wait and without
  reading the keys again. With a dead node each round waited 100 seconds, so
  the app stayed on the splash for good. With a node that had come back, each
  round returned at once: the verifier counted 2,764 `state_queryStorageAt`
  requests with no keys in 0.53 seconds, followed by a stack overflow.
- The PI configuration request waits for connectivity for up to 30 seconds
  per request, so even an offline launch showed the splash for that long.
- Debug builds also asked the node for block 0 and waited 10 seconds for it.

App Store 3.8.6 starts the storage checks without waiting for the asset list
(commit `fe184e06`, never ported to this branch).

Who was affected: every launch for users whose saved node is dead; any single
launch on a slow or captive network (the process never recovered); most users
at once during an outage of the node they had saved.

## What changed

### Startup order

`SplashInteractor.setup()` now does three things and returns:

1. pins the genesis hash locally (see below);
2. tells `StartupNetworkCoordinator` that startup has begun;
3. starts the wallet storage checks (`startChain`).

Nothing waits for a network answer. The storage checks, the three automatic
retries, the low-storage panel, the wait for the device to be unlocked and
the routing in `RootInteractor` are unchanged, and all of them are local.
PIN entry, onboarding, Welcome back, the 1.x upgrade screen and the recovery
screen are reached the same way with no node, with a dead node, on a captive
network and in airplane mode.

Every in-app restart of startup creates a new `SplashInteractor` through
`SplashPresenterFactory` (recovery "Try again" and "Set up this iPhone
again", Welcome back after a restore, "Check wallet again" on the opening
screen, account removal, node change), so they all follow the same order.

### Network work in the background: `StartupNetworkCoordinator`

New type in `SoraPassport/ModulesRedesign/SplashScreen/AssetsInfoProvider.swift`.
One instance lives for the whole process, so work that could not finish while
the splash was visible goes on afterwards.

- **Remote configuration.** `ConfigService.setupConfig` is called and not
  waited for. Until PI answers, `ConfigService.config` is the bundled
  configuration (bundled nodes, bundled type registry) and the feature flags
  are the ones saved from the last answer, as before when PI could not be
  reached. When the answer arrives after the chain registry has booted and
  it changes the node list, the registry is synced once more. One request at
  a time: a restart of startup does not send a second one while the first is
  still open.
- **Asset list.** The wallet starts with the asset list saved in the chain
  store (`ChainSyncService.preparedChain` keeps the stored assets while
  `AssetManager.networkAssets` is empty; the airplane-mode path already
  relied on this). The live list is loaded in the background, published to
  `AssetManager.networkAssets`, and the registry is synced so that the chain
  row and every screen that follows it get the list. It is loaded once per
  process.
- The coordinator does not create the chain registry. While startup has not
  booted it (recovery screen, low storage, 1.x upgrade) no list is needed and
  nothing is sent. `SplashInteractor.bootstrapWalletNetworks` calls
  `chainRegistryWillBoot()` just before the hot or cold boot.

### The loader: `AssetsInfoProvider`

Rewritten as a small state machine on its own serial queue.

- One attempt reads **all key pages from the first page**, then the values.
  An attempt that fails for any reason (a page fails or times out, the node
  has no keys, the values are empty or cannot be decoded) is dropped as a
  whole. A failed first page can no longer leave an empty key list behind.
- **No request without keys.** A node that returns no keys ends the attempt
  before the value query.
- **Bounded exponential backoff.** The next attempt is started by a timer
  after 2, 4, 8, 16, 32 and then 60 seconds (the ceiling), each shortened by a
  random share of up to 20 % so that clients do not retry in step when a node
  returns. There is no limit on the number of attempts: at one attempt a
  minute a wallet that was started during an outage still gets its list when
  the node returns.
- **No recursion.** A retry is a timer. Answers are always handled in a new
  block on the queue, also when a connection answers inside `callMethod`.
- **Nothing is sent while the connection is not connected.** A request to a
  socket that is still connecting would only be queued and would reset the
  socket's reconnection counter, which the registry's failover relies on.
- **A request that timed out is taken off the connection**
  (`cancelForIdentifier`), and requests are sent with
  `resendOnReconnect: false`, so a node that comes back finds no queue of old
  requests. Time limits: 20 seconds for a key page, 60 seconds for the values.
- Paging is bounded (32 pages of 1,000 keys; 1,000 is the largest page a
  Substrate node serves and what 3.8.6 uses; mainnet has 957 assets today,
  one page). A node that serves the same page again ends the attempt at
  once.
- `retryNow` starts an attempt early (the node has just connected, startup
  was restarted, the user tapped "Try again"). Attempts started this way are
  at least 5 seconds apart, and a wake-up never postpones a planned attempt.
- `cancel()` and `deinit` cancel the timers and the request in flight.

### The connection: the chain registry's, which fails over

The launch socket is gone (`WebSocketService.shared` removed; the class has no
user left and is kept only to keep the project file edit small). The list is
loaded over the chain registry's connection:

- its node order is fixed: the selected node, the bundled nodes in the order
  they are declared (`wss://ws.mof.sora.org`, `wss://mof2.sora.org`), the
  configured nodes, the custom nodes
  (`SoraNodeConnectionPolicy.candidates`). No `Set.first`;
- `ChainRegistry` fails over to the next node after two failed connection
  attempts and saves `lastSuccessfulUrl` on every connection, as before.
  `lastSuccessfulUrl` is still written (App Store 3.8.6 reads it) and is no
  longer read by this app;
- `ChainRegistry.connectionUpdated` tells the coordinator that a node has
  connected, so the list is requested at once instead of at the next timer.

**Failover fix (found on the simulator).** `WebSocketEngine.reconnect(url:)`
(vendored `SSFUtils`) reused the Starscream engine of the old node for the
new one. That engine keeps one TCP connection, the handshake key and the
"upgraded" flag, and does not cancel a connection that is still being opened.
After a failover the old connection stayed open and its events were taken for
the new node. With a dead selected node the switch to a working node ran into
five handshake errors ("accept header doesn't match", "notAnUpgrade(200)")
and took 12 seconds. `reconnect(url:)` now cancels the old socket and gives
the new node an engine and a transport of its own: in the same check the
next node connected at its first attempt, 2.2 seconds after the first
connection attempt to the dead node.

### Genesis hash

`GenesisProvider` answers locally in every build configuration: the saved
`externalGenesis`, or SORA mainnet's. Release builds always did this (genesis
pinning); it is unchanged for them. Other builds asked the launch node for
block 0 and waited up to 10 seconds. The bundled nodes are mainnet nodes in
every configuration, so the answer was the same value. `externalGenesis` is
now written on every launch, also on a launch without network (it used to
stay unset then, and a Release build compares custom nodes against it).

### Chain sync

`ChainSyncService` dropped a sync request that arrived while a sync was
running. The running sync could already have read the old asset list or node
list, and it can wait a long time for the remote whitelist. The request is now
remembered and one more sync runs when the current one ends.

### A wallet opened before any asset list exists

The wallet's tabs take the asset list when they are built. With a saved list
(every wallet that has been opened before) nothing changes. Without one, the
wallet is built with no asset: a fresh install on which no node has answered
yet, or a chain store that had to be recreated. Before this change that only
happened on an offline launch, and the wallet then stayed empty for the rest
of the process, because the list was never loaded again. Now the list
arrives later, so the screens have to follow it:

- `AssetManager` posts `WalletAssetListArrived` when the chain's assets
  arrive while the wallet is open and shows none
  (`AssetManager.needsWalletRebuild`).
- `MainTabBarInteractor` then has every tab built again
  (`recreateWalletViewController`, the rebuild used for an account switch and
  a language change), so all tabs come from the same list.
- A list that only gains or loses some assets does not rebuild anything, as
  before: a screen in use is not replaced.
- The rebuild path gave the middle tab a title, and the system drew it a
  second time under the custom "Polkaswap" label (seen on the simulator after
  this rebuild; an account switch and a language change run the same code).
  The title is removed, as in the first build.
- "Try again" on the wallet opening screen also asks the loader to try now.

### Shared state

Startup no longer finishes before these are written, so they are locked:
`AssetManager.networkAssets` and `ConfigService.config`.

## Key safety

No key material, account row, PIN, derivation or address code is touched.
The change is the order of startup and the network code around it.

- Invariant 6 (no dead ends): the splash can no longer wait for the network.
  The states behind it (PIN, onboarding, Welcome back, recovery, low storage,
  1.x upgrade) keep their own forward actions.
- Invariant 7 (transient failures never latch): a failed or slow first
  request no longer decides anything for the rest of the process.
- Invariant 9 (downgrade): `lastSuccessfulUrl` and `externalGenesis` keep
  their keys and encodings. The chain store schema is unchanged.
- Invariant 10: genesis pinning is unchanged for Release builds and now also
  applies to the other configurations. The address prefix and signing are
  not touched. The asset whitelist still decides which on-chain assets are
  listed (the registry sync applies it to the background list as before).

## User-visible effect

- The app leaves the splash after the local storage checks, whatever the
  network does: about 2 to 3 seconds on the simulator, of which 2 are the
  splash animation.
- An existing wallet opens with the assets it had. Balances and the live
  asset list follow when a node answers. If no node answers, the wallet shows
  its usual loading rows.
- A new wallet created on a fresh install while no node answers opens with
  an empty asset card and gets its assets when a node answers, without a
  relaunch.
- After an account switch or a language change the middle tab shows
  "Polkaswap" once, not twice.
- A returning node gets one small request per client, not a flood.
- No new strings.

## Tests

`SoraPassportTests/Common/Modernization/StartupNetworkTests.swift`, 20 tests.
The loader tests use a stub connection that answers inside `callMethod` (the
case that used to recurse) and timers fired by the test, so waits and request
counts are exact.

Loader (`AssetsInfoProvider`):

- `testFailedFirstPageIsReloadedWhenTheNodeRecovers`: first page fails, no
  value query; after the 2 s wait all pages are read from the first one and
  the list is delivered once.
- `testFirstPageTimeoutIsTakenOffTheNodeAndRetriedFromTheFirstPage`: the
  timed out request is cancelled on the connection; its late answer is
  ignored.
- `testAFailureOnALaterPageRestartsFromTheFirstPage`.
- `testNodeThatNeverAnswersGetsOneRequestPerAttemptAndTheWaitHasACeiling`:
  ten attempts, ten requests, waits 2, 4, 8, 16, 32, 60, 60, 60, 60 s, no
  value query, nothing happens without a timer.
- `testEmptyAnswersNeverLeadToAValueQueryWithoutKeysAndBackOff`: no keys, no
  values, no storage entry, undecodable values; then a good answer.
- `testANodeThatOnlyReturnsFullPagesEndsTheAttempt`,
  `testANodeThatRepeatsAPageEndsTheAttemptAtOnce`.
- `testNothingIsSentUntilTheConnectionIsConnected`.
- `testRetryNowNeverBringsAttemptsCloserThanTheMinimumAndNeverPostpones`.
- `testReleasingTheLoaderTakesItsRequestOffTheNodeAndStopsItsTimers`,
  `testCancelStopsTheLoader`.
- `testRetryWaitsDoubleUpToTheCeilingAndJitterOnlyShortensThem`.

Coordinator and startup:

- `testAssetListIsLoadedOverTheRegistryConnectionAfterTheBootAndGivenToTheRegistry`.
- `testAConnectedNodeAndARestartOfStartupWakeTheWaitingLoader`.
- `testALateRemoteConfigurationUpdatesTheRegistryOnlyAfterTheBootAndOnlyWhenTheNodesChanged`.
- `testWalletStorageChecksStartWhileTheConfigurationAndTheAssetListArePending`:
  the production `SplashInteractor.setup()` and `startChain()` with the real
  coordinator and loader, a configuration service that never answers and a
  node that never answers. The storage checks start; a second interactor
  (a restart) starts them again without a second configuration request or a
  second node request.

Other:

- `testAnAssetListThatArrivesDuringAChainSyncReachesTheChain`: the production
  `ChainSyncService` on an in-memory chain store. Fails without the fix (the
  second request is dropped; the chain has no assets).
- `testFailingOverToAnotherNodeClosesTheOldConnectionAndIsNotDisturbedByIt`:
  the real `WebSocketEngine` against two loopback servers in the test
  process. Fails without the fix (the connection to the old node stays open).
- `testOnlyAWalletBuiltWithoutAnyAssetIsBuiltAgainWhenTheListArrives` and
  `testTheArrivalOfTheFirstAssetListRebuildsEveryTab` (the production
  `MainTabBarInteractor` on an event center of its own).

The two "fails without the fix" results were checked by reverting each fix,
rebuilding and running the test (3 failures), then restoring it. The other
tests use interfaces that did not exist before; the old behaviour itself is
the verifier's reproduction on the simulator, repeated below with the fix.

`SoraPassportIntegrationTests/AssetsInfoProviderTests.swift` (live node, not
part of the unit run) was moved to the new interface.

## Verification (Xcode 27.0)

- Debug `build-for-testing` for the simulator succeeds (the app and the
  three test bundles, `SoraPassportIntegrationTests` included).
- `SoraPassportTests`, Debug, iOS 27.0 simulator, whole target: 514 tests,
  0 failures, 2 skipped (`Sora2MainnetLiveSigningTests` skips itself unless
  it is enabled for the live network). 494 before this task plus the 20 new
  ones.
- The unsigned Release build for `generic/platform=iOS` succeeds.
- `SoraPassportDev` builds for the simulator.
- `Package.resolved` is unchanged.

## Seen on the simulator (iOS 27.0, Debug build, iPhone 17 Pro)

The saved node was set by editing `lastSuccessfulUrl` in the app container's
preferences with the simulator shut down, as in DYN-IOS. The node the app
talks to was set by selecting a custom node in the chain store (SQLite) while
the app was not running. The stand-in node is a local script
(`scratchpad/work/ik1-tools/standin_node.py`); nothing left the Mac except
the app's normal traffic to the public nodes.

In every run the storage checks and the routing were finished 0.2 to 0.4
seconds after startup began (app console); the 2 second splash animation
follows. "First screenshot" below is the first one taken after the launch;
the time in brackets is counted from the start of the process.

| Check | Before (DYN-IOS) | Now |
|---|---|---|
| S0. Fresh install, live network | onboarding within 15 s | Welcome at the first screenshot (5 s); 957 assets loaded after 3.9 s |
| S1. Fresh install, saved node `wss://127.0.0.1:9` (refused) | splash at 15 s, 60 s, 180 s and 9 min 42 s | Welcome at the first screenshot (3 s); list loaded after 4.0 s; the saved node was replaced by `wss://ws.mof.sora.org` |
| S2. The node connects but does not answer for 70 s, then answers "no keys" for 70 s, then serves | 2,764 value queries without keys in 0.53 s when the node came back, then a crash | Welcome at the first screenshot (6 s); in 3.5 minutes the node got 7 key-page requests (15 to 54 s apart), no value query without keys, and 1 value query with 3 keys; the list loaded at the first attempt after the node served |
| S3. Selected node refuses, saved node refuses | the app never left the splash | Welcome at the first screenshot (7 s); the failover to `wss://ws.mof.sora.org` connected 2.2 s after the first connection attempt (12 s and five handshake errors before the failover fix); list loaded after 5.3 s; saved node replaced |
| S4. Existing wallet, selected node refuses, saved node refuses | splash for good | PIN screen at the first screenshot (2 s); after the PIN the wallet opens with its assets; list loaded after 5.1 s |
| S5. Existing wallet, the node connects but never answers | splash for good | PIN screen at the first screenshot (4 s); after the PIN the wallet opens and shows its loading rows; 4 key-page requests in 135 s, each taken off the node when it timed out |
| S7. Existing wallet, no saved asset list, the node connects but never answers; 30 s later the node is killed | splash for good | PIN, then the wallet with an empty asset card; when the node dies the registry fails over to `wss://ws.mof.sora.org` in 2.1 s, the list (957 assets) is loaded 2.2 s later and the wallet shows its assets 0.15 s after that, without a tap |

Files: `scratchpad/work/shots-ios-keys/ik1/` (screenshots `S0` to `S7`, the
app console of every run, the stand-in node's request logs
`S2-standin-node.log` and `S5-standin-node.log`,
`S3-before-transport-fix.console.log`, and `before-rebuild-fix/` with the
empty wallet that S7 showed before the rebuild was added). The wallet in these checks is a
throwaway simulator wallet.

Not run: a physical iPhone and airplane mode (the simulator has none). With
no network at all the storage checks start the same way; the unit test with a
configuration service and a node that never answer covers the order.

## Human or ops actions

- None for release.
- Device QA: one launch in airplane mode with an existing wallet (PIN screen,
  then the wallet with saved assets), and one fresh install in airplane mode
  (Welcome; after creating a wallet, an empty asset card until the network is
  back, then the assets appear without a relaunch).
- Node operations: nothing to change. `ws.mof2.sora.org`, `ws.mof3.sora.org`
  and `mof3.sora.org` still fail TLS; users who have one of them saved are no
  longer stuck, because the saved URL is not read any more.

## Not changed here

- The wallet's other requests to a connected node that does not answer (the
  balance providers) are as before: on the simulator they sent 276
  `state_getStorage` requests in 135 seconds.
- A socket that reconnects to the same node keeps its Starscream engine, as
  before. Only the switch to another node gets a new one.
- A fresh install has no bundled asset list (3.8.6 has `DefaultAssets`).
  Until the first list arrives a new wallet shows an empty asset card.
- The wallet opening screen ("Opening wallet") is unchanged apart from "Try
  again". It waits for the chain's connection and runtime, not for assets.
- `WebSocketService` and `WebSocketEngineFactory` have no user left. They are
  not removed here, to keep the shared project file out of this change.
- Debug builds no longer learn another network's genesis from their node.
- In builds other than Release, the testers' surfaces that PI switches on
  (Nexus portfolio, Polkamarkt) are read from the saved flags when a screen
  is built; on the very first launch the answer can arrive after that.
  Release builds hide these surfaces whatever PI says.
