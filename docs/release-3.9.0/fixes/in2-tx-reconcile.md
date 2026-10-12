# in2-tx-reconcile: sent transactions always resolve; sends survive chain upgrades honestly

Audit findings `ios-signing.md` S-2, S-3, S-6, S-9 and `live-env.md` LIVE-8,
LIVE-12 ("Sent transactions may never be marked resolved" and "A future
mainnet upgrade can still stop sends" in section 4 of the 10 October report).

No key, account-store, derivation or migration code is touched. Nothing in
this change signs, re-signs or resubmits a transaction: reconciliation stays
status-only.

## Facts established first (S-2 had no reproduction)

Checked against both default nodes on 12 October 2026 (finalized block
28,004,280), with plain HTTPS JSON-RPC and then with the app's own code:

| Request for a block 2,000 behind the head | `ws.mof.sora.org` | `mof2.sora.org` |
|---|---|---|
| `chain_getBlockHash(0)` | mainnet genesis `0x7e4e32d0…d38ad5` | the same |
| `chain_getBlockHash(n)`, `chain_getBlock` | answered | answered, same hash |
| `chain_getRuntimeVersion(hash)` | error 4003 `Api called for an unknown Block: State already discarded for 0x…` | answered (spec 133) |
| `state_queryStorageAt([System.Events], hash)` | error 4003 `UnknownBlock: State already discarded for 0x…` | answered |

So the first default node keeps every block but only recent state, and the
second is an archive of the same chain. The old reconciler needed both state
calls at the inclusion block from the connected node only, treated every node
error as the same `remoteError`, and left the entry as it was. Reading the code
confirmed the rest of S-2 as written:

- a pass ran only at process start, on return to the foreground and on account
  change, never after a send;
- each pass took the 16 oldest entries first, so 16 stuck entries hid every
  newer one for good;
- an entry without a terminal resolution blocked removal of its account and
  counted against the 500-entry cap for ever; at 500 every new send, swap and
  liquidity action was refused before transport;
- an entry whose signed era block was not the canonical one, and an entry
  with no recovery context, could never be resolved at all.

The live test `testSentTransactionResolvesOnTheStatePruningDefaultNode`
(below) reproduces the node's answer with the app's transport and shows the
fix working against mainnet.

## What changed

### 1. Pending-transaction reconciliation (S-2, LIVE-8)

`SoraPassport/Common/Services/ExtrinsicService.swift`,
`SoraPassport/Common/Model/PolkamarktRuntime.swift`,
`SoraPassport/Common/HistoryService/*`,
`SoraPassport/ModulesRedesign/ActivityDetails/*`,
`SoraPassport/ModulesRedesign/AssetDetails/ActivityViewModelFactory.swift`

- **Shortly after submission.** Every path that hands signed bytes to the
  network (or may have) calls `Sora2PendingSubmissionRecoveryRuntime
  .noteSubmission()`. Passes then run by themselves after 12, 20, 30, 45 and
  60 seconds and then after 5, 5 and 7 minutes (`Sora2PendingFollowUpSchedule`),
  and stop as soon as nothing is left that another pass could change. A
  transaction is normally final within half a minute, so Activity shows its
  result about 30 to 60 seconds after sending without leaving the app. The
  later delays cover the end of the mortal era (64 blocks). Another pass is
  scheduled while a pass leaves an entry inside its era, unexamined, in a
  finalized block without a result that could be read, or behind a read
  that failed (for entries signed within the last seven days), and while a
  pass fails as a whole (offline) with such an entry in the journal. The
  eight delays bound the asking. Start, foreground and account change still
  run a pass and start the schedule again from its first delay.
- **No file read on the main actor.** The pass itself brings back whether a
  follow-up is needed (`Sora2PendingSubmissionReconciler.scheduledPass`,
  `Sora2PendingPassOutcome`); the runtime, which lives on the main actor,
  no longer reads the journal.
- **State that the connected node discarded.** Blocks are still scanned on
  the connected node (every node keeps them). The execution result is read
  from the first source that has it:
  1. the connected node;
  2. each bundled mainnet node addressed directly over HTTPS
     (`SoraNodeConnectionPolicy.bundledMainnetNodes`; today `mof2.sora.org` is
     the archive). A node is asked for state only after it returned the
     reviewed genesis hash and, at the inclusion height, the very block hash
     the connected node reported as canonical and final;
  3. the indexer's record of that exact transaction
     (`qualifiedHistoryByTransactionHashes`, live source only, exactly one
     row), used only when it names the same block number and block hash.
  The bounded transport now tells "State already discarded" apart from other
  node errors (`Sora2BoundedHTTPJSONRPCError.blockStateUnavailable`); the
  node's text is never stored or shown.
- **Found, result not readable yet.** When no source has the result, the
  inclusion itself is recorded in the journal entry (`finalizedInclusion`:
  block number, block hash, extrinsic index). The field is optional and
  additive; an older build ignores it, and a value that does not fit its
  entry is dropped on read instead of making the journal unreadable. Such an
  entry is final on chain: it no longer blocks anything, and later passes
  read only its result (no block scan). A generic entry is asked about for
  seven days counted from the moment its inclusion was written down
  (`finalizedInclusion.recordedAt`, optional and additive), so one failed
  read never ends the asking, however long after signing the entry was first
  examined. An entry a feature waits for (a legacy migration) is asked about
  until it has its result (`resultIsStillLookedFor`).
- **No starvation.** A pass prefers entries the process has tried least, the
  newest first (`Sora2PendingReconciliationRotation`), so the transaction just
  sent is examined first and an entry that keeps failing moves behind the
  others. A pass that made progress and left entries unexamined continues at
  once. Entries whose wallet binding fails cost no request.
- **Another finalized history.** A transaction is signed against the
  finalized head of the node it is built on. When the connected node has
  another block at that height it follows another finalized history (a fork
  with the mainnet genesis, which the add-node check accepts), and neither
  what it holds nor what it lacks is evidence about the transaction. The
  entry is left unresolved (counted as deferred, with no follow-up); the two
  clocks below unblock removal and capacity, and it resolves when the app is
  connected to the chain it was signed on again. The reviewed genesis of the
  connected node is checked once per pass.
- **Ageing, account removal, capacity.** Two clocks need no network:
  - `submissionWindow`, one hour from signing: the transaction "may still be
    entering the network" (a mortal era is about six and a half minutes).
    Account removal waits only for this (`WalletPendingDeletionPolicy`);
    before, any unresolved entry blocked removal for ever. A journal file that
    cannot be read blocks removal only if it was written within the hour.
  - `resultRetryWindow`, seven days: how long an entry without a result is
    still shown as pending in Activity (from signing), and how long the
    result of a generic finalized entry is still looked for (from the
    recording of its inclusion).
  When the journal holds 500 entries a new transaction replaces, in this
  order, the oldest resolved entry, the oldest entry already found in a
  finalized block, the oldest stale generic entry
  (`Sora2PendingSubmissionStore.evictionIndex`). Entries whose transaction may
  still be entering the network, and entries a feature journal owns, are
  never evicted. Stale entries therefore cannot make the journal refuse a
  send.
- **Activity.** Activity and an asset's recent activity are built by
  `HistoryService` from the indexer's rows and the rows of the current run
  (`LocalTransactionStorage`, in memory). `HistoryService` now also reads
  the journal where it puts page 1 together, off the main thread
  (`SentTransactionJournalOverlay`):
  - a row of the current run takes its final status from the journal
    (succeeded, failed, or not included);
  - a sent transaction that neither the indexer nor the current run lists
    gets a row of its own, "Sent transaction", with one line saying what
    became of it: "Waiting for the network to confirm it", "Confirmed by
    the network", "It failed on the network" or "The network did not include
    it. Nothing was sent." The journal keeps no amounts, so the row shows
    none. Tapping it opens details with status, time, hash and sender;
  - when the indexer lists the transaction, its row replaces the journal's.
  A journal row is shown only inside the stretch of time page 1 covers (or
  when the list has no further pages), so nothing appears twice further
  down; not in a list for one asset (the journal does not know the asset);
  not for an entry a feature owns or one that never reached transport. An
  entry without a result stops being listed as pending seven days after
  signing.
  When a pass gives an entry its final status
  (`Sora2PendingSubmissionsResolved`), the open Activity list and the
  asset's recent activity reload, and open transaction details that still
  say "Pending" take the journal's result.

### 2. Signed extensions (S-3, LIVE-12)

`SoraPassport/Common/Services/ExtrinsicCheck.swift`, `ExtrinsicBuilder.swift`,
`VendorPackages/shared-features-spm/…/ExtrinsicCheck.swift`,
`ExtrinsicBuilder.swift`, `ExtrinsicExtraNode.swift`

- `Sora2SignedExtensionSupport.validate` runs inside
  `Sora2LiveRuntimeValidator.validate`, that is before every fee estimate,
  prepare and submit, on metadata already proven to be the node's. For each
  extension the live metadata lists it compares what the runtime says the
  extension carries (the `type` and `additionalSigned` types are followed to
  see whether they encode to any bytes) with what the two encoders write.
  A mismatch in either direction throws
  `ExtrinsicServiceError.unsupportedSignedExtension`; nothing is signed or
  submitted. An extension without data, known or not
  (`CheckNonZeroSender`), changes nothing.
- The message: "The SORA network was upgraded and this version of the app
  can't send transactions on it yet. Nothing was signed and your funds are
  safe. Please update the app."
- `CheckMetadataHash` is written in disabled mode: mode byte `0` in the signed
  extra and an absent hash (`0`) in the additional signed data. Both encoders
  write it only when the metadata lists the extension, so runtime 133 bytes
  are unchanged (asserted against the audit's reference vector).
- The lookup used by the check (`ExtrinsicCheck.matching`) keeps no shared
  state. The encoder's own lookup caches into a static dictionary, which is
  not safe to call from the several queues that estimate fees.

### 3. Balances: unavailable, never zero (S-3 second part, LIVE-12)

`WalletNetworkFacade+Storage.swift`, `WalletNetworkFacade+Protocol.swift`,
`WalletNetworkOperationFactory.swift`, `AssetProvider.swift`,
`BalanceProviderFactory.swift`, wallet list, full asset list, token picker,
asset details, send amount

- `System.Account` is read as the runtime's own metadata decodes it and then
  mapped to the app's model (`WalletBalanceReading`). No stored value is a
  real zero. A value the model does not recognise (a renamed field, as
  happened to `AccountData` in May 2026) is `unavailable`.
- Token balances keep the raw storage value until it is decoded: nothing
  stored is zero, three `u128` values are the balance, any other length is
  `unavailable`, and a failed read is `unavailable` for that pass.
- A failed read of the account itself (offline, node or runtime not ready)
  fails the whole read, so the balances shown so far stay. Before, every one
  of these cases showed 0.
- The wallet's balance provider keeps unavailable assets apart from balances
  (`AssetProvider.unavailableBalanceAssetIds`), so no consumer can take one
  for a number. The wallet list keeps the row and shows "Balance unavailable";
  the total says "This total does not include balances that could not be
  read". Every other caller gets no entry for such an asset, which they
  already treat as "not loaded".
- "Not answered" and "not understood" are told apart
  (`WalletBalanceReading.notRead`, `BalanceData.balanceWasNotRead`). An
  asset whose request got no answer in one read (a timeout among about 30
  requests) keeps the value of the read before; only an answer that arrived
  and was not understood makes the asset unavailable
  (`AssetProvider.merge`). After a read that left a balance out, or failed
  as a whole, the provider asks again by itself after 5, 15, 45, 120 and
  300 seconds, and stops at the first complete read; the next balance event
  starts the asking again.
- Send amount (`InputAssetAmountViewModel`): the unavailable state is kept
  in the view model. Every write of the balance text goes through one
  function on the main thread, so prices arriving do not put "0 ($0)" in
  place of the notice. No "not enough balance" is derived from the
  placeholder, and the amount cannot be reviewed while the asset's balance,
  or the XOR that pays the fee, is unknown. Balance updates arrive on the
  provider's queue and are applied on the main thread.
- Asset details (`TransferableCell`, `TransferableItemService`): no value
  and no frozen part are shown next to "Balance unavailable", and the row
  follows the provider both ways while the screen is open (the Send button
  comes back with the balance).
- The full asset list and the token picker (`ManageAssetListViewModel`,
  `SelectAssetViewModel`) keep a row for such an asset, saying "Balance
  unavailable"; it is never put behind "show zero balances". Saving the
  edited asset list never drops an asset that had no row.

### 4. Custom nodes (S-6)

`SoraPassport/ModulesRedesign/CustomNode/*`

- Signing needs one HTTPS JSON-RPC route at the node's own host, port and
  path. When a SORA mainnet node is added or edited, the app now posts
  `chain_getBlockHash(0)` to that route (`Sora2NodeSigningRoute.probe`) after
  the existing WebSocket check. No answer, a `ws://` address or a non-JSON
  answer: the node is not saved, the address field says "This node does not
  answer over HTTPS, so it can't send transactions" and an alert explains
  that balances use the WebSocket and sends use HTTPS. Another genesis: the
  existing "invalid node" text.
- App Store builds first compare the node's block zero over the WebSocket
  (unchanged order). When that check failed, the form used to wait without
  end; it now shows the "invalid node" text. A node that gave no answer used
  to pass the check while the app had not learned a genesis yet; no answer is
  now never a match, and without a learned genesis the chain's own id is the
  reference (`CustomNodeInteractor.isExpectedGenesis`).
- A node selected by an earlier version may still lack the route. Every
  signing flow builds its extrinsic in one place, which reports to
  `Sora2SigningNotice`: the user gets one alert (at most every two minutes)
  saying the selected node cannot send and to choose another node, also in
  flows that show only "try again" themselves. The same notice carries the
  "update the app" message of item 2. Nothing is latched.
- The transport's own error texts are now in the string tables. The
  transport carries the HTTP status. A custom node is told its route is
  missing only for an answer that shows it: 404, 405, 426, 501, or a page
  that is not JSON. A node that answers 429, 502 or 503 once is busy; that
  is described as "no usable answer" and raises no notice. A JSON-RPC error
  object (the node read the request and refused it, for example an invalid
  transaction) has its own text, "The SORA network did not accept this
  request. Please try again.", which does not send the user to another
  node.
- `AddConnectionError.toErrorContent` returned an empty message for every
  case; it now returns the message it computes.

### 5. Runtime proofs per node (S-9)

`ExtrinsicService.swift` (`Sora2LiveRuntimeIdentityCache`),
`RuntimeSyncService.swift`

- A stored proof is keyed by node (its HTTPS signing endpoint, lowercased),
  spec version and transaction version, under a new defaults key
  (`…liveRuntimeMetadataProofs.v2`). Proofs written by earlier builds are not
  read, so each node proves its metadata once after the update (one
  `state_getMetadata`, about 1.3 MB).
- A node selected later proves its own metadata before the stored metadata is
  used to sign there. If the stored metadata came from another node and
  differs, the existing refresh replaces it from the current node.
- A download is recorded only if the connection still points at the node it
  was addressed to (`connectionChanged` otherwise; nothing is signed and the
  next attempt checks the new node). The runtime sync service records its
  proof the same way.

## User-visible effect

- A sent transaction shows its final status in Activity within about a
  minute, also when the app is reopened hours later on the first default
  node. A transaction that was never included says so (about eight minutes
  after sending, when its validity has ended on the finalized chain), and it
  is still listed after the app is restarted.
- An account with an old unresolved entry can be removed again; sends are
  not refused because of old entries.
- After a chain upgrade the app cannot follow, sending says "update the app"
  instead of failing at the node, and a balance the app cannot read says
  "Balance unavailable" instead of 0, in the wallet list, the full asset
  list, the token picker, asset details and the send amount screen, where
  nothing can be sent from it until it is read.
- Adding a WebSocket-only custom node is refused with an explanation.

## Key-safety review

- No Keychain, account-store or migration code is changed.
- Reconciliation has no signer and no submission call; the new sources only
  read. An archive node or the indexer can make a result available, never
  invent an inclusion: the block is always the one found by the app's own
  scan of finalized blocks, and both must name that same block.
- Refusing to sign (item 2) and refusing a node (item 4) leave everything
  else usable and name the way forward. Nothing asks the user to delete or
  reinstall.
- Account removal was relaxed only for entries whose transaction can no
  longer enter the chain. The removal flow itself (phrase first, explicit
  confirmation) is unchanged.
- All new state is transient or additive: an in-memory rotation counter, an
  optional journal field, a new proofs key. 3.8.6 reads none of these files.

## Tests

`SoraPassportTests/Common/Modernization/Sora2LiveRuntimeTests.swift` (52
tests in the class) and one test in `PIIndexerLiveContractTests.swift`
(`PIRound4PriceTests`, which holds the send-amount screen's test doubles).
The tests were also run with the fixes switched off in the production code,
and failed (see "Verification").

| Test | What it proves |
|---|---|
| `testBoundedTransportRecognisesDiscardedState` | the two answers of `ws.mof.sora.org` become `blockStateUnavailable`; other errors do not |
| `testPendingRecoveryReadsTheResultFromAnArchiveWhenTheNodePrunedState` | stub node that prunes state plus a stub archive: the entry resolves to success; the archive proved genesis and block first; blocks were scanned on the connected node only |
| `testPendingRecoveryReadsAFailedResultFromAnArchive` | a failed extrinsic is reported as failed |
| `testPendingRecoveryRecordsInclusionWhenNoSourceHasTheResult` | an archive on another chain, one with another block and one that is down are not asked for state; an indexer row for another block is not used; the inclusion is recorded, removal is allowed, and the next pass resolves from the indexer without scanning blocks |
| `testFinalizedEntryWithoutAResultAgesOut` | after seven days nothing is asked and Activity no longer says pending; the entry is not deleted by a pass |
| `testUnresolvableEntriesDoNotStarveOtherEntries` | 34 stuck entries around 3 ordinary ones: the ordinary ones resolve in the second pass |
| `testEntrySignedOnAnotherFinalizedHistoryIsLeftUnresolved` | an entry whose signing block is not this node's block at that height is left unresolved with no follow-up; removal and capacity are unblocked by time; it resolves on the right chain |
| `testAPassThatLeavesAResultUnreadAsksForAFollowUp`, `testFollowUpPassesContinueWhileAResultIsUnreadAndAreBounded` | an unread result, a failed read and a pass that failed as a whole ask for a follow-up; an unbound entry and a week-old one do not; the runtime stops after the eight delays |
| `testAResultFirstAskedForLateIsStillAskedForAgain` | an entry first examined eight days after signing (legacy migration and generic) is asked about again and resolves; the week counts from the recording, for generic entries only; the new field is additive |
| `testTheRecoveryPassReadsTheJournalOffTheMainThread` | the runtime with the production pass never touches the journal file on the main thread |
| `testActivityShowsWhatBecameOfASentTransaction` | the production reconciler, `HistoryService`, `ActivityViewModel` and row factory: a pending row of this run turns to failed on the event; after a restart the journal's row says the network did not include it; ordering, replacement by the indexer's row, no row for other accounts, feature-owned or untransported entries, none in a one-asset list, pending ends after a week |
| `testOpenTransactionDetailsTakeTheFinalStatusFromTheJournal` | open details follow the journal, read off the main thread |
| `testEntryInsideItsEraAsksForAFollowUp` | only finalized blocks are read; the schedule and its end |
| `testSubmissionStartsReconciliationPassesOfItsOwn` | the runtime: nothing before both gates; a submission starts passes at 12 s and 20 s and stops when resolved; offline it runs the whole schedule and stops; foreground starts it again |
| `testFullJournalOfStaleEntriesStillAcceptsANewTransaction` | 500 stale entries accept a new transaction; recent and feature-owned entries are never evicted |
| `testAccountRemovalIsNotBlockedForEverByAnUnresolvedEntry` | removal waits one hour at most; clock set back; unreadable journal; both languages |
| `testInclusionWitnessIsAdditiveAndNeverBreaksTheJournal` | old journals read unchanged; a bad witness is dropped; a result must be for the recorded block |
| `testRuntime133SignedExtensionsAreAllWrittenAndTheTransferMatchesTheReferenceVector` | full bytes of the audit's vector (extrinsic and signing payload) |
| `testUnknownSignedExtensionWithDataRefusesToSign` | extra-only, additional-signed-only and "known extension lost its data" all refuse; message in both languages |
| `testUnknownSignedExtensionWithoutDataChangesNothing` | bytes identical with `CheckNonZeroSender` added |
| `testCheckMetadataHashIsWrittenInDisabledMode` | exact bytes with the extension |
| `testUnrecognisedBalanceLayoutIsUnavailableNeverZero` | renamed fields, other token lengths and failed reads are unavailable; nothing stored is zero |
| `testWalletListShowsBalanceUnavailableInsteadOfZero` | the wallet list through `AssetsItemService`: row text, no value, the note on the total |
| `testBalanceProviderKeepsTheLastValueAndAsksAgain` | `AssetProvider`: an unanswered request keeps the last value, an answer not understood is unavailable, further reads after the delays, bounded, ended by a complete read |
| `testAssetListsKeepAnAssetWhoseBalanceCouldNotBeRead` | the rows of the full list and the token picker; the saved list keeps every asset |
| `testAssetDetailsShowNoValueForAnUnreadBalanceAndRecover` | the details cell: no "$" next to the notice, the balance and the Send button return, and the notice returns |
| `PIRound4PriceTests.testSendAmountKeepsBalanceUnavailableWhenPricesArrive` | the send amount view model: the notice survives prices, no not-enough warning, no review, main-thread writes, recovery both ways |
| `testCustomNodeIsCheckedForTheSigningRoute` | the probe (available, other network, HTTP 404, `ws://`), the notice and its rate limit, messages; which HTTP statuses mean a missing route (404, 405, 426, 501, a page) and which do not (429, 5xx), through the transport; the text of a refused request |
| `testAddingACustomNodeWithoutTheSigningRouteIsRefused` | the add flow through `CustomNodeInteractor`: not saved and told why; saved when the route answers; other chains not probed; the genesis comparison of App Store builds |
| `testLiveRuntimeProofIsNotReusedForAnotherNode`, `testExtrinsicServiceProvesTheLiveRuntimePerNode`, `testLiveRuntimeCacheIsKeyedByNodeAndRuntimeVersion` | S-9 |

Changed existing tests: `WalletModernizationTests` (the deletion policy and
the journal overlay take the time as a parameter).

Live tests (`Sora2MainnetLiveSigningTests`, run with
`TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1`; skipped otherwise):

- `testSentTransactionResolvesOnTheStatePruningDefaultNode` (new): takes a
  real signed transaction about 2,000 blocks behind the head, writes a journal
  entry for it and has the reconciler resolve it while connected to
  `ws.mof.sora.org`, with the archive only, the indexer only, and neither.
- `testThrowawayAccountSignsTransferForTheLiveMainnetRuntime` (existing) now
  also passes through the signed-extension check.

## Verification (12 October 2026, Xcode 27.0, iOS 27.0 simulator)

- `SoraPassportTests` on the tree of review round 6: 662 tests, 657 passed,
  5 skipped (the live-network tests, which need the environment variable),
  0 failed. The two classes this round touches (`Sora2LiveRuntimeTests`,
  `PIRound4PriceTests`, 61 tests) were run again after the last change.
- Round 6 fixes switched off in the production code in one build, tests
  untouched (history without the journal, the earlier follow-up rule, the
  week counted from signing, no comparison of the signing block, every
  refusal of a custom node as "no route", the journal read on the main
  thread, the earlier send-amount, asset-details, provider and list code):
  all eleven new tests and the two extended ones
  (`testCustomNodeIsCheckedForTheSigningRoute`,
  `testEntryInsideItsEraAsksForAFollowUp`) failed, each on the assertions of
  the fix that was off. The files were restored with `git checkout`
  (`git status` clean) and the tests pass again.
- First round, unchanged: the three gated live tests passed against mainnet
  (`SoraLiveReconcile block=28002340 behind=2008 prunedOnConnectedNode=true
  archive=finalizedSuccess indexer=finalizedSuccess neither=none`), and the
  first round's fixes switched off made 15 tests of the class fail.
- Release device compile (`generic/platform=iOS`, no signing) succeeded on
  the round 6 tree.
- The Debug build starts on a freshly created simulator to the first
  onboarding screen.

Not done here: no funded transaction was sent, and no screen behind
onboarding or the PIN was driven by hand (taps on the simulator need a
permission this session does not have). The Activity list, transaction
details, send amount, asset details and the asset lists are covered through
their production view models, cells and services in the tests above; see
"Human and ops actions" for the device checks that remain.

## Limits and decisions

- The scan of one era reads up to 64 blocks, one request after the other; a
  pass for one old entry on a slow connection takes up to about 40 seconds.
  It runs in the background and blocks nothing.
- The one-hour and seven-day windows use the device clock. A clock set back
  does not extend them; a clock set forward shortens them, which only makes
  an entry stop blocking earlier. If the chain itself stops for more than an
  hour inside a transaction's era, removal of that account is allowed while
  the transaction could in theory still be included; the entry is still
  reconciled afterwards.
- Absence is read from the connected node. A node that follows another
  finalized history than the one the transaction was signed on leaves the
  entry unresolved (the signing block is compared). A node whose history
  agrees up to the signing block and differs after it could still make an
  entry resolve as "not included"; that needs a fork of finalized blocks
  within the minutes after signing. When the indexer lists the transaction,
  its row replaces the journal's in Activity.
- A journal row is listed on the first page of Activity only, and only for
  the stretch of time that page covers. A sent transaction older than the
  50 newest indexer rows is represented by the indexer's own row, if it is
  on the chain, and not at all if it never was included.
- A journal row shows no amount or recipient: the journal stores the hash
  and the fate of a transaction, never what it did.
- "Balance unavailable" appears when the chain's value was decoded by the
  runtime's own metadata and the app's model did not recognise it. A read
  that fails earlier (no answer, or the runtime's types cannot decode the
  value at all) fails the whole balance read: the list keeps the values it
  showed last and reads again with the next balance event. It no longer
  turns them into zeros.
- A custom node selected in 3.8.6 without the HTTPS route is not replaced
  automatically; the user is told to choose another node. Falling back to a
  bundled node for signing without asking would send the transaction through
  a node the user did not choose.
- The leftover-file problem of the journal folder (audit I3: a kill inside a
  journal write makes every later send fail) is not part of this task.

## Human and ops actions

1. Device QA: send on a device connected to `ws.mof.sora.org`; check that
   Activity shows the result within a minute without leaving the app. Send
   again, close the app at once, reopen after 30 minutes on the same node and
   check the result appears. Inspect
   `Application Support/SORA/PendingTransactions/sora2-signed-v1.json`: both
   entries carry a `terminalResolution`.
   Also look once at a journal row: sign a transfer, switch to airplane mode
   the moment "Confirm" is tapped (or use an account whose nonce another
   device has just used), wait ten minutes online, and check that Activity
   lists "Sent transaction" with "The network did not include it. Nothing
   was sent.", also after closing and reopening the app, and that its
   details open. The row has no amount by design.
2. Keep `mof2.sora.org` an archive node that answers HTTPS JSON-RPC. If it
   is ever replaced, the replacement must be in
   `SoraNodeConnectionPolicy.bundledMainnetNodes`. The indexer is the second
   fallback only.
3. Run `Sora2MainnetLiveSigningTests` with
   `TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1` on the release commit, on a
   schedule (daily), and against the testnet before each mainnet upgrade.
   A new signed extension with data, or a renamed balance field, now fails
   these tests on the day it appears, and the app says "update the app" or
   "Balance unavailable" instead of failing silently. Agree advance notice of
   runtime upgrades with the chain team (LIVE-12).
4. Support: "Balance unavailable" and "this version of the app can't send
   transactions on it yet" both mean the chain was upgraded ahead of the app.
   Funds are not affected; the answer is an app update.

## Review round 6 (12 October 2026)

Ten findings of the adversarial review of the first round. All were checked
against the code and found real; all are fixed.

| # | Finding | What was done |
|---|---|---|
| 1 (major) | The reconciled status never reached a screen: Activity is built by `HistoryService`, which did not read the journal; the changed `pendingJournalOverlay` was reachable only through `WalletService.fetchTransactionHistory`, which nothing calls | `HistoryService` reads the journal for page 1 and applies it through `SentTransactionJournalOverlay` (which uses `pendingJournalOverlay` for the reading of the journal, so that code is now on the path the screens use): final status on rows of the current run, a "Sent transaction" row for what neither the indexer nor the run lists, open details follow. Section 1, "Activity" |
| 2 | A pass that left an entry `awaitingResult` or `deferred` asked for no follow-up | `needsFollowUp` counts both (a failed read only for entries signed within seven days), and a pass that failed as a whole asks again while the journal holds such an entry; bounded by the eight delays |
| 3 | The seven-day age-out counted from signing and applied to feature-owned entries, so one failed read after eight days latched the entry for good | Counted from the recording of the inclusion (`recordedAt`), generic entries only; feature-owned entries are asked about until resolved |
| 4 | The comparison of the signing block had been removed; an entry was resolved "not included" on a node with another finalized history | Restored; such an entry is left unresolved, with no follow-up. The doc's "this was already so" was wrong and is corrected under "Limits" |
| 5, 9 | Any HTTP refusal from a custom node raised the "no HTTPS route" alert; a JSON-RPC error read as "the node gave no usable answer" | The status is carried; only 404, 405, 426, 501 and a non-JSON page mean a missing route. A JSON-RPC error has its own text |
| 6 (major) | Send amount: "Balance unavailable" was replaced by "0 ($0)" when prices loaded, "not enough balance" was derived from the placeholder, and the label was written off the main thread | State kept in the view model, one main-thread writer, no warning and no review while a needed balance is unknown |
| 7 | Asset details showed "$0" under "Balance unavailable" and did not recover | No value or frozen part next to the notice; the row follows the provider both ways |
| 8 | A token unavailable after one timed-out request stayed so until the next XOR change; the last good value was dropped; the full list and the token picker left the asset out | Last value kept for an unanswered request, bounded re-reads, rows in both lists. Found on the way: saving the edited asset list replaced the wallet's asset list with the rows shown, so an asset without a row left the wallet until the next start; the saved list now always keeps every asset |
| 10 | The runtime read the journal file on the main actor after each pass | The pass returns what the schedule needs; the runtime reads no file |

Also changed in this round:

- `LocalTransactionStorage` and `HistoryService`'s row cache are guarded by
  locks (events arrive on the event center's queue while pages are built on
  others), and `getTransaction(by:)` returns the latest version of a row.
- History rows sort by their time as a number of seconds. The asset's
  recent activity parsed the time as an integer, which a row of the current
  run (it carries a fraction) failed, so such a row sorted last.
- One existing test (`testAWalletHoldingOnlyAnUnpricedAssetDoesNotReadZero`)
  waited for the wallet total and then read the rows, which the service
  writes after the total; it failed once in this round's runs and now waits
  for both.

Commits of this round keep production code and tests apart: the three
production commits are followed by one test commit, from which the test
target compiles again.

