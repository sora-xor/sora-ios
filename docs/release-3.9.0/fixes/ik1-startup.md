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
- The coordinator does not create the chain registry (creating it reads the
  app's window, and this work runs on background queues). It uses the
  registry once it knows that somebody has started it. While nobody has
  (recovery screen, low storage, the 1.x upgrade screen) there is no wallet
  on screen that needs a list, and nothing is sent.
- **The registry is started in two places, and the coordinator is told at
  both.** Startup boots it (`SplashInteractor.bootChainRegistry`). The
  wallet starts it again when it opens (`ServiceCoordinator.setup`, run by
  `MainTabBarInteractor`), and for a 1.x wallet that is the first start:
  its startup ends at the upgrade screen and boots nothing, and after
  "Upgrade wallet" and the PIN the wallet opens without another run of
  startup. Both places create the registry on the main thread, then call
  `chainRegistryWillBoot()`, then start it. The order matters: the loader
  uses the registry from its own queue as soon as it hears of the start.
  As a second line, a node that connects is reported by the registry itself
  (`nodeDidConnect()`), and that report alone also counts as "started".
  (Review round 3: until then only startup told the coordinator, so the
  wallet of a 1.x user never asked for its asset list after the upgrade.)

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
- **A node that keeps connecting and failing is not asked every 5 seconds.**
  The registry wakes the loader every time a node connects. On a node whose
  last attempts failed, a wake-up may bring the next attempt no closer to the
  last one than 5, 10, 20, 40 and then 60 seconds (after 1, 2, 3, 4 and more
  failed attempts on that node; `RetryPolicy.wakeUpInterval`). That is never
  less than the planned wait, so a node that accepts the socket and drops it
  again gets the same 2, 4, 8, 16, 32, 60 second waits as a node that stays
  connected and fails. The count is kept per node: after a failover the new
  node has not failed and is asked after the plain 5 seconds. An explicit
  user action ("Try again", a restart of startup) clears the counts.
  (Review round 3: before, a wake-up replaced the planned attempt by one 5
  seconds after the last, however many attempts had failed.)
- `cancel()` and `deinit` cancel the timers and the request in flight.
- **The time limits and waits run on the loader's own serial queue.** They
  first ran on the shared utility queue. When a wallet opens on a slow node
  it puts many blocking requests on the shared queues, and no shared thread
  was free: on the simulator a 20 second limit fired after 47 seconds and
  every later attempt slipped by as much. A serial queue gets a thread of its
  own; in the same check the limits are now 20.0 seconds.

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
- When every node has failed once, a status at the top of the screen says
  "Network unavailable. Retrying connection…". Only a change of the device's
  reachability took it down, so after a node outage or on a captive network
  it stayed over a wallet that was connected again. The registry now takes it
  down when a node connects (`NodeConnectionFailover.connected()` reports
  that it was shown).
- The registry calls the coordinator after it has released its own lock: the
  work that is woken asks the registry for its connection.

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
list. The request is now remembered.

A sync has two parts: it saves the chain from what is known (nodes, asset
list, last good whitelist), then fetches the whitelist over HTTP and saves
again. The HTTP request can take as long as its timeout on a slow or
filtered network, so a new asset list does not wait for it:

- a request made during the first part is served as soon as that part has
  saved, before the whitelist request;
- a request made during the whitelist request is saved at once, with the
  last good whitelist;
- every pass over the chain store runs after the one before it (each reads
  the stored chain and saves what it made of it), so the pass with the new
  whitelist is never overwritten by an older answer.

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
- Every tab is then built again (`recreateWalletViewController`, the rebuild
  used for an account switch and a language change), so all tabs come from
  the same list. `WalletAssetListRebuild` (in `MainTabBarWireframe.swift`)
  decides when:
  - from the list the tabs were built from and the list as it is now, not
    from the event alone. The event is posted once and the tab bar only
    listens once it has appeared, so the tab bar also looks when it starts
    listening and after every reload of the wallet tab;
  - only while every tab shows its first screen and nothing is presented
    over them. Replacing the tabs closes whatever is pushed or presented (a
    recovery phrase being read, the node list, app settings). Until the user
    is back the rebuild waits and looks again once a second;
  - a rebuild that cannot be done is tried three times, not for ever;
  - the wait ends when waiting cannot help: the tabs were replaced by the
    recovery screen of a failed account switch, or they belong to another
    wallet than the selected one. The recovery screen is never built over.
    (Review round 3: such a wait went on looking once a second for the rest
    of the session.)
- **No balances are loaded, and none are saved, for a wallet without an asset
  list** (`AssetProvider`). Every balance provider of an account shares one
  cache entry. The provider of the tabs built without a list loaded "no
  balances" and saved that over the cached balances; the tabs built again
  with the list then read the empty answer and showed an asset card with no
  row until the next launch (seen on the simulator, check R6 below). Without
  a list the asset rows now keep their loading state.
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
  its loading rows and gets its assets when a node answers, without a
  relaunch and without closing a screen the user is on.
- A wallet upgraded from 1.x opens with its loading rows and shows its
  assets a few seconds later, without a relaunch (review round 3).
- The "Network unavailable. Retrying connection…" status goes away when a
  node is connected again.
- After an account switch or a language change the middle tab shows
  "Polkaswap" once, not twice.
- A returning node gets one small request per client, not a flood, and a
  node that keeps dropping its connections is asked at growing intervals of
  up to a minute.
- No new strings.

## Tests

`SoraPassportTests/Common/Modernization/StartupNetworkTests.swift`, 52 tests
(37 from the first two passes, 15 from review round 3, listed under "Review
round 3" below).
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
- `testRetryNowNeverBringsAttemptsCloserThanTheMinimumAndNeverPostpones`
  (its second half now uses "Try again"; the wake-ups of a node have their
  own tests, see review round 3).
- `testReleasingTheLoaderTakesItsRequestOffTheNodeAndStopsItsTimers`,
  `testCancelStopsTheLoader`.
- `testRetryWaitsDoubleUpToTheCeilingAndJitterOnlyShortensThem`.
- `testTheLoadersTimersFireOnItsOwnQueueAndCanBeCancelled` and
  `testTimeoutAndRetryKeepTheirLengthWhileTheSharedQueuesAreBlocked`: the
  app's own timer while 256 blocks hold the shared utility queue; a 0.3 s
  limit and a 0.2 s wait end in time. Fails with the timer on the shared
  queue (the list never arrives within 10 s).

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
- `testTheChainRegistryIsCreatedOnTheMainThreadBeforeTheBackgroundWorkHearsOfTheBoot`:
  the production `SplashInteractor.bootChainRegistry` for a hot and a cold
  boot.

Other:

- The production `ChainSyncService` with a whitelist request and a chain
  store that the test holds open:
  `testAnAssetListThatArrivesDuringTheWhitelistRequestReachesTheChainAtOnce`
  (on an in-memory Core Data chain store),
  `testAnAssetListThatArrivesDuringTheFirstPassIsSavedBeforeTheWhitelistAnswers`
  and
  `testAPassDuringTheWhitelistRequestNeverOverwritesThePassWithTheNewWhitelist`.
  The last one fails without the ordering of the passes (the chain ends with
  the older answer).
- `testANodeThatConnectsTakesTheOutageStatusDownOnce`.
- `testFailingOverToAnotherNodeClosesTheOldConnectionAndIsNotDisturbedByIt`:
  the real `WebSocketEngine` against two loopback servers in the test
  process. Fails without the fix (the connection to the old node stays open).
- `testOnlyAWalletBuiltWithoutAnyAssetIsBuiltAgainWhenTheListArrives`.
- `testTheAssetManagerAnnouncesTheFirstListOfAWalletSetUpWithoutAssetsAndOnlyThat`:
  the production `AssetManager` on an in-memory chain store; one event for
  the first list, none for a later change.
- `testTheTabBarLooksForTheAssetListWhenItStartsListeningAndOnTheEvent` (the
  production `MainTabBarInteractor` on an event center of its own) and
  `testEveryReloadOfTheWalletIsFollowedByTheAssetListCheck` (the production
  `MainTabBarPresenter`).
- `WalletAssetListRebuild`:
  `testTabsBuiltWithoutAssetsAreBuiltAgainOnceWhenTheListIsThere`,
  `testTabsBuiltFromAListAreNeverReplacedByAnAssetListCheck`,
  `testTheRebuildWaitsUntilNoScreenWouldBeTakenAway`,
  `testAnAccountSwitchWhileTheRebuildWaitsEndsTheWait`,
  `testARebuildThatDoesNotWorkIsTriedAFewTimesAndThenLeftAlone`,
  `testTheWaitEndsWithItsOwner`, `testTheRebuildTimerRunsOnTheMainRunLoop`, and
  `testTabsAreReplacedOnlyWhileEveryTabShowsItsFirstScreenAndNothingIsPresented`
  (real `UITabBarController` and navigation controllers in a window: a
  pushed screen on any tab and a presented screen hold the rebuild back).
- `testAWalletBuiltWithoutAnAssetListNeitherLoadsNorOverwritesTheSavedBalances`:
  the production `AssetProvider` with RobinHood's `SingleValueProvider` on
  one shared cache entry. Fails without the fix (the provider without a list
  asks for balances and the saved balances are replaced by an empty list).

The "fails without the fix" results were checked by reverting each fix,
rebuilding and running the test, then restoring it. The other tests use
interfaces that did not exist before; the old behaviour itself is the
verifier's reproduction on the simulator, repeated below with the fix.

`SoraPassportIntegrationTests/AssetsInfoProviderTests.swift` (live node, not
part of the unit run) was moved to the new interface.

## Verification (Xcode 27.0)

- Debug `build-for-testing` for the simulator succeeds (the app and the
  three test bundles, `SoraPassportIntegrationTests` included).
- `SoraPassportTests`, Debug, iOS 27.0 simulator, whole target: 546 tests,
  0 failures, 2 skipped (`Sora2MainnetLiveSigningTests` skips itself unless
  it is enabled for the live network). 494 before this task plus the 52 of
  this task.
- `StartupNetworkTests` alone: 52 of 52. (The 37 tests of the first two
  passes were also run with every CPU core kept busy by other processes.)
- The unsigned Release build for `generic/platform=iOS` succeeds.
- `SoraPassportDev` builds for the simulator.
- `Package.resolved` is unchanged.

One test was unreliable and was corrected in the second pass:
`testTheAssetManagerAnnouncesTheFirstListOfAWalletSetUpWithoutAssetsAndOnlyThat`
failed once in a full run that shared the machine with a Release build. The
test saved the list before the asset manager's listener was registered
(RobinHood registers an observer after a fetch of its own, and a save in
between is not announced to it). The test now saves until the manager shows
the list. The same gap exists in the app for the few milliseconds after the
asset manager is created; it is not changed here.

## Seen on the simulator (iOS 27.0, Debug build, iPhone 17 Pro)

Two rounds. The first table is the first pass. The second table repeats the
checks with the final code and adds the states the second pass changed.

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

### Second pass, final code

Same method. Files: `scratchpad/work/shots-ios-keys/ik1/fix4/` (screenshots,
app consoles, stand-in node logs `R2-`, `R6-` and `R7-standin-node.log`).
Tools: `scratchpad/work/ik1-tools/fix4/`.

| Check | Result |
|---|---|
| R1. Existing wallet with a recovery marker set by hand, saved node `wss://127.0.0.1:9`, selected node connects and never answers | Recovery screen at the second screenshot (4.5 s after the process started). The node got no connection at all. "Try again" ran startup again and was back on the recovery screen at once, again without a request. (The marker was a bare flag without a recorded cause; such a marker is not cleared by a retry, by design. The other actions of the screen stay.) |
| R2. Existing wallet, saved node refuses, selected node is silent for 70 s, answers "no keys" for 70 s, then serves | PIN screen at the first screenshot (2 s). In 180 s the node got 7 key-page requests, 15 to 56 s apart, no value query without keys, and 1 value query with 3 keys. Each time limit was 20.0 s (47 s in the first pass, before the loader had its own queue). |
| R3. Fresh install on a second simulator, saved node refuses | Welcome at the second screenshot (4 s). Storage checks and routing done 0.21 s after startup began. Node chosen: `wss://ws.mof.sora.org`. 957 assets loaded after 3.7 s. |
| R4. App deleted and installed again, Keychain kept, saved node refuses | Welcome back at the second screenshot (4 s). "Set up this iPhone again" (two confirmations, then "Continue without restoring") leads to Welcome; a new wallet is created and opens with its assets. The saved node was replaced by `wss://ws.mof.sora.org`. |
| R6. Wallet without a saved asset list, node silent for 45 s, then serves three assets; 30 s later the node is stopped | PIN, then the wallet with loading rows. The list arrived 48 s after launch and the tabs were built again 0.03 s later, without a tap. After the failover to `wss://ws.mof.sora.org` the asset card showed **no row** (`R6-wallet-after-node-dies-failover.png`), also after a pull to refresh. Cause and fix: the balance cache, see "A wallet opened before any asset list exists". |
| R7. R6 again with that fix; the user is in More > App settings when the list arrives | The screen stays (`R7-pushed-screen-after-list.png`): no rebuild for the 17 s it was open, then the tabs were built again within 1 s of closing it. After the failover the wallet shows XOR, VAL and PSWAP (`R7-wallet-after-failover.png`). |
| R6b. Relaunch with the selected node stopped | PIN at the first screenshot; failover; 957 assets loaded 4.6 s after launch; the wallet opens with its assets. |

The simulator now holds a new throwaway wallet. The first pass's wallet was
copied aside before the app was deleted for R4 (app data and Keychain
database in `scratchpad/work/ik1-tools/fix4/simA-backup/`); its Keychain
items were not removed. R3 ran on a second simulator created for it
(`SORA-Fix-keys-B`), which only reached Welcome and was deleted afterwards.

Not run: a physical iPhone and airplane mode (the simulator has none). With
no network at all the storage checks start the same way; the unit test with a
configuration service and a node that never answer covers the order.

## Review round 3

Four findings of the adversarial review of the second pass. All four were
checked against the code and are real; all four are fixed.

### 1. A wallet opened after a 1.x upgrade never asked for its asset list (major)

Found by review; confirmed in the code. The loader got a connection only
after `chainRegistryWillBoot()`, and only `SplashInteractor.bootChainRegistry`
called it. A 1.x wallet (Keychain items `seedEntropy`, optionally
`privateKey`, and `pincode`; no account store, so no chain store either)
ends startup at the upgrade screen without booting the registry
(`performStorageMigration`, `deferredForLegacyUpgrade`). "Upgrade wallet"
ends in `decideModuleSynchroniously()`, the PIN follows, and the wallet
opens with no further run of startup. `ServiceCoordinator.setup()` (from
`MainTabBarInteractor.init`) started the registry and told nobody. The
loader's timers, the node's "connected" report and "Try again" all ended
in "no connection", for the rest of the process. The wallet showed loading
rows and no asset until the app was closed. A late remote node list was
dropped the same way. This was a regression of this task: before it, the
list was loaded before the storage checks, so this user got it. The same
applies to an app that was deleted and installed again where only the 1.x
Keychain items are left.

Fix (commit "Load the asset list for a wallet whose registry startup did
not boot"):

- `ServiceCoordinator.setup()` creates the registry (main thread), calls
  `chainRegistryWillBoot()`, then subscribes and syncs. Same order as
  startup. `ServiceCoordinator` takes the coordinator and the registry as
  parameters with the app's own as defaults.
- `StartupNetworkCoordinator.nodeDidConnect()` also marks the registry as
  started. The registry calls it itself, so the registry exists whoever
  started it. This covers any other place that may start the registry.
- `ChainRegistry` makes that call through a closure given at creation
  (default: the app's coordinator) and after releasing its own lock.

Not chosen: running startup again after the upgrade. It would work, but it
changes the routing of the 1.x upgrade (a key-handling flow) for a network
reason, and it adds a second splash between "Upgrade wallet" and the PIN.

### 2. A node that keeps reconnecting was asked every 5 seconds (minor)

Real. See "A node that keeps connecting and failing" above (commit "Back
off the asset loader's wake-ups on a node that keeps failing"). Both of the
reviewer's suggestions are combined: the distance of wake-up attempts grows
with the failed attempts, and it is counted per node, so a real failover is
not held back by the node that failed. At most 16 nodes are remembered.

### 3. The tab rebuild's 1 Hz look could go on for ever (minor)

Real: after an account switch that ends on the recovery screen, or with
tabs of another wallet than the selected one, `canReplaceTabs` was false
for good and the timer kept firing. See "the wait ends when waiting cannot
help" above (commit "End the wait of the wallet's tab rebuild when waiting
cannot help"). The check has a third answer (`Replacement.unavailable`),
`handleAccountBoundRebuildFailure` stops a wait at once, and a rebuild that
itself ends on the recovery screen is not tried again. The guard that used
to stand before the check is now only inside it: one place decides.

### 4. Two fixes were tested below their production wiring (minor)

Real. Added:

- `testTheRegistryTakesTheOutageStatusDownWhenANodeConnectsAndTellsTheWaitingWork`:
  the production `ChainRegistry` on a chain store in memory with a
  connection pool, a status presenter and a "node connected" hook of the
  test's own. Every node fails and the status is shown; a node connects and
  it is taken down once; a second outage shows and takes it down again; a
  connection without an outage takes nothing down; the saved node is
  updated.
- Four tests of the production `MainTabBarWireframe` on a real tab bar
  controller in a window (the selected wallet, the asset list, the timer
  and the builder of the tabs are given by the test through
  `MainTabBarWireframe.AssetListEnvironment`):
  `testTheWalletsTabsAreBuiltAgainForALateListOnceTheUserIsBackAtATabsFirstScreen`,
  `testAnAccountSwitchThatEndsOnTheRecoveryScreenEndsTheWaitAndIsNeverBuiltOver`,
  `testTabsOfAnotherWalletThanTheSelectedOneAreNotReplacedByTheAssetListCheck`,
  `testARebuildForALateListThatEndsOnTheRecoveryScreenIsTriedOnce`.

### The other new tests

- Finding 1: `testANodeThatConnectsIsEnoughWhenStartupDidNotBootTheRegistry`
  (the coordinator gets `startupDidBegin()` and `nodeDidConnect()`, never
  `chainRegistryWillBoot()`, and loads and publishes the list; a remote
  node list that arrives afterwards reaches the registry),
  `testTheWaitingLoaderFindsARegistryThatTheWalletStartedLater`, and
  `testAWalletOpenedAfterAStartupThatBootedNoRegistryStillGetsItsAssetList`:
  the production `SplashInteractor`, `MainTabBarInteractor`,
  `ServiceCoordinator`, coordinator and loader. The storage checks are
  replaced by one that ends without booting, as the deferral for the 1.x
  upgrade does. The real checks read the app's own account store and
  Keychain and cannot be put into that state inside the test host;
  `RootInteractor` takes no part in starting the registry. The full path is
  the simulator check below.
- Finding 2: `testANodeThatKeepsConnectingAndFailingIsAskedWithGrowingWaits`
  (five wake-ups after every failed attempt: the waits stay 2, 4, 8, 16,
  32, 60, 60, 60 s),
  `testAWakeUpNeverBringsAttemptsOnOneNodeCloserThanItsGrowingDistance`,
  `testAWakeUpAfterAFailoverToAnotherNodeDoesNotWaitForTheFailedNode`,
  `testTheDistanceOfWakeUpsOnOneNodeDoublesUpToTheCeiling`.
- Finding 3, on `WalletAssetListRebuild` itself:
  `testTheWaitEndsWhenTheTabsCanNoLongerBeReplacedAtAll`,
  `testStoppingTheWaitCancelsItsTimerAndTheNextCheckDecidesAnew`,
  `testARebuildThatEndsOnTheRecoveryScreenIsNotTriedAgain`.

Each fix was taken out again to see its tests fail (logs in
`scratchpad/work/logs-ios-keys/fix5/`):

- Without the four fixes (`test-mutantA.log`): 12 of the 15 new tests fail,
  the ones named for findings 1 to 4 above. The three that pass do not
  depend on a fix (`testTheWaitingLoaderFinds…`, `testStoppingTheWait…`,
  `testTheWalletsTabsAreBuiltAgainForALateList…`).
- With the wiring broken the way the review described
  (`test-mutantB.log`): the recovery guard removed from the wireframe's
  check (the tabs are built over the recovery screen: 2 tests fail), the
  `?? false` of the registry inverted (the status is "taken down" without
  having been shown: the registry test fails), and the coordinator told
  after the registry was started instead of before (the order test fails).

### Verification of this round (Xcode 27.0)

- Debug `build-for-testing` for the simulator succeeds.
- `SoraPassportTests`, whole target: 546 tests, 0 failures, 2 skipped.
  `StartupNetworkTests` alone: 52 of 52, run again after the last build.
- The unsigned Release build for `generic/platform=iOS` succeeds.
- `SoraPassportDev` was not built again: no file was added and no target
  membership changed. `project.pbxproj` and `Package.resolved` are
  untouched. No new strings.

### Seen on the simulator: a 1.x wallet after the upgrade

Files: `scratchpad/work/shots-ios-keys/ik1/fix5/`.

The simulator was erased (its two throwaway wallets were copied aside
first: Keychain database and app data in
`scratchpad/work/ik1-tools/fix5/simA-backup-before-1x/`). A test that is
not part of the repository wrote the three Keychain items of SORA 1.5.1
(`privateKey`, `seedEntropy` of a new 15-word phrase, `pincode`) with the
code copied from that release, as `WalletKeySafetyTests` does. The app was
then deleted and installed again, so only those items were left.

| Step | Result |
|---|---|
| Launch | "Upgrade your wallet" at the first screenshot, 5 s after the launch command (`L1-1x-launch-5s.png`) |
| "Upgrade wallet" | PIN screen 3 s later (`L1-1x-after-upgrade-tap.png`); the console reports the scoped key copies added for 1 account |
| PIN | The wallet opens with loading rows (`L1-1x-after-pin-0.png`). The registry is started by the wallet (console: node `wss://ws.mof.sora.org` at 05:45:29.8). **957 assets loaded at 05:45:33.0**, 3.2 s later, and the tabs are built again 0.13 s after that. The wallet shows XOR, VAL, PSWAP and the others without a tap or a relaunch (`L1-1x-after-pin-16s.png`) |

Before the fix this wallet stayed on the loading rows (review finding 1; the
unit tests above fail without the fix). The simulator now holds this
upgraded throwaway wallet (PIN pattern as before: left column top to
bottom, twice).

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
  Until the first list arrives a new wallet shows its loading rows.
- A wallet whose node never answers the runtime version shows loading rows
  although balances are cached (the registry's hot boot from saved metadata
  is disabled in `ChainRegistry.performHotBoot`, as before).
- A node that disappears without closing the connection is noticed at the
  next ping, up to about 20 seconds later (seen in checks R6 and R7); the
  failover then takes 1 to 2 seconds.
- The wallet opening screen ("Opening wallet") is unchanged apart from "Try
  again". It waits for the chain's connection and runtime, not for assets.
- `WebSocketService` and `WebSocketEngineFactory` have no user left. They are
  not removed here, to keep the shared project file out of this change.
- Debug builds no longer learn another network's genesis from their node.
- In builds other than Release, the testers' surfaces that PI switches on
  (Nexus portfolio, Polkamarkt) are read from the saved flags when a screen
  is built; on the very first launch the answer can arrive after that.
  Release builds hide these surfaces whatever PI says.

## Seen in passing, for other tasks

- Creating an account in a Japanese session (check R5) shows two English
  texts: the alert "Not backed up!" with "I will risk it" (its text also
  says "loose" for "lose"), and the button "Continue with Google". They are
  not in the string tables.
- In a Japanese session the wallet's first screen shows "Send", "Receive"
  and "SORA2 · Change network" in English
  (`shots-ios-keys/ik1/fix5/L1-1x-after-pin-16s.png`).
- A recovery marker that is only the flag `walletMigrationRecoveryRequired`,
  with no recorded cause, is not cleared by "Try again" (check R1). No
  released version writes such a marker; the recovery screen's other actions
  work.
