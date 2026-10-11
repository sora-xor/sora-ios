# ik2-leftover-files: a kill inside a file write never leaves a permanent failure (audit I3)

Task key `ik2-leftover-files`. Branch `claude/release-fixes-20261011-ios-keys`.
Audit finding I3 (`ios-lockout.md` L-2 and L-4, `ios-forward.md` FWD-2,
`ios-newcode.md` N6; `verdicts.md` L-2 and DYN-IOS, including their new
findings about the PendingTransactions folder and the writer's own error
paths).

## Why

`DurableFileWriter` publishes every small wallet record (network snapshot and
its pointer, account-commit journals, the migration attempt's manifest,
settings copy and journal, the pending-transaction journals). While it works
it keeps hidden helper files beside the target:

| Name | What it holds |
|---|---|
| `.durable-<UUID>.tmp` | the new content before publication, or the old file after the atomic exchange |
| `.durable-rollback-<UUID>.anchor` | a second name of the old file |
| `.durable-rollback-<UUID>.safety-anchor` | a third name of the old file while a failed publication is rolled back |
| `.durable-failed-<UUID>.withdrawn` | a new file taken back from its target after its publication failed |

They were removed only inside the same call. A process that died inside a
write (force-quit, jetsam, crash on another thread, battery, an install over
a running app) left them behind, and four folders rejected any unexpected
name on every later read:

- `Application Support/SORA/WalletNetworks` and `WalletAccountCommits`, and
  the attempt folder under `Documents/CoreData/WalletMigrationSafety`:
  recovery screen on every launch, "Try again" could never pass, the only
  exit was "Set up this iPhone again".
- `Application Support/SORA/PendingTransactions`: every send, swap and
  liquidity action failed from then on, with no recovery screen and no exit
  in the app. "Set up this iPhone again" did not move that folder.

The verifier killed the writer 150 times per mode: an existing-target write
left helper files in 126 kills, a new-target write in 80. The windows occur
in the eight writes of the first launch after the upgrade and on every
account switch, rename, add, removal and transaction.

Three more shapes of the same problem:

- **The writer's own error paths left helper files without any kill**: a
  failure between the anchor link and the exchange, a failed new publication
  (kept as `.withdrawn` on purpose), and a committed write whose anchor
  cleanup failed.
- **WalletNetworks states between an activation's steps**: a first snapshot
  whose pointer was not written yet, and nine snapshot files before pruning,
  both failed every later read.
- **An account removed in App Store 3.8.6 after this version ran** (a
  TestFlight build expired, the user went back to 3.8.6 and removed an
  account there): the snapshot still listed it, and every account was locked.

And `ios-newcode.md` N6: three multi-step writes left an awkward state when
the process died between two steps.

## What changed

### 1. The writer (`SoraPassport/Common/Model/WalletNetworkModel.swift`, `DurableFileWriter`)

- **Helper files are named, recognised and swept.**
  `leftoverKind(ofEntryNamed:)` matches only the four exact patterns the
  writer generates (fixed prefix, canonical upper-case UUID, fixed suffix).
  `sweepLeftovers(in:)` removes regular files with such a name from one
  directory and nothing else. It never throws.
- **Why a sweep is safe.** The writer publishes with one atomic rename
  (`RENAME_EXCL` for a new file, `RENAME_SWAP` for an existing one) after the
  new content is written and synced. At every instant the target name holds
  the whole old file or the whole new file. A helper file is therefore never
  the only copy of published state: it is an extra name of the old file, the
  old file that was just replaced, or new content that was never published
  (the caller was not told it was saved). A published file can never match a
  helper pattern.
- **No sweep while a write is in progress in this process.** `write`
  registers its directory (by device and inode) for its whole duration. A
  sweep takes the same lock, skips a directory with a registered write, and
  holds the lock while it removes files, so a write cannot begin in a
  directory that is being swept. (The app has no extension and no second
  process.)
- **Every exit of `write` cleans up after itself.** The last step of each
  call, successful or not, removes the hidden names that call created and
  still finds, when they hold a file the call knows: the file it created
  itself under a hidden name, or the old file while the target still names
  the old or the new file. This closes the three error paths. After a
  concurrent change of the target by someone else, the names are left for
  the sweep.
- **The published file after a failed write** is the old file (rolled back),
  or, when the rollback itself fails, the complete new file. That second case
  is what a kill at that instant leaves too, and callers already treat a
  thrown write as "may have been published".
- **`contentsIgnoringLeftovers(of:...)`** is what every strict folder check
  now lists with: it sweeps when it meets a helper name and leaves out helper
  files that cannot be swept right now (a write of another journal is in
  progress, or a removal failed). A helper name that was listed and is gone
  when it is examined (the other write finished in between) is left out too.
  Every other entry is returned unchanged, so an unexpected name still fails
  the check; so does a link or a directory with a helper name.
- **Checkpoints for tests.** `DurableFileWriter.Checkpoint` names the steps of
  a write. `checkpointObserver` exists only in `DEBUG` builds; the App Store
  build compiles `reach` to nothing.

### 2. Startup sweep (`SoraPassport/Common/Migration/WalletRecoveryOptions.swift`, `WalletInterruptedWriteCleanup`)

The storage checks of a launch first sweep `WalletNetworks`,
`WalletAccountCommits`, `PendingTransactions` and, for every attempt folder in
`WalletMigrationSafety`, its root, `legacy-store` and `staging`. The sweep
runs before any check, on the storage queue, after the device is unlocked. It
reads no file content and touches no key.

The whole sequence (sweep, journal and startup recovery, database migration,
transaction records) is one function, `WalletStorageStartup.runChecks`
(`SplashInteractor.swift`). `SplashInteractor.performStorageMigration` calls
it with the defaults and only routes on its result, and the tests call the
same function over an isolated installation, so a line dropped from the
sequence fails tests.

### 3. Strict folder checks

| Folder | Check | Now |
|---|---|---|
| `WalletNetworks` | `WalletNetworkStore.validatedNamespaceUnlocked` | helper files swept or ignored; any other name still fails |
| `WalletNetworks` | `loadUnlocked` | one snapshot above the retained eight is read and the oldest surplus one is pruned (best effort on a read, required before the next activation); a single snapshot without `active.json` gets its pointer written once it decodes, validates and passes topology admission; several pointer-less snapshots, a snapshot that does not decode, or ten snapshots still fail |
| `WalletAccountCommits` | `WalletAccountCommitJournalStore.loadUnlocked` | helper files swept or ignored |
| attempt folder | `WalletMigrationSafetyNamespaceAdmission.isExactActivatedAttemptRoot`, `UserStorageMigrator.verifyBackupRecords`, `incompletePreflightSnapshot`, the empty-`staging` check, the gate probe's `legacy-store` listing | helper files swept or ignored (an extra name of `journal.json` no longer fails the single-link check, because it is gone before the check) |
| `PendingTransactions` | `PendingTransactionJournalNamespace.validate` | helper files swept or ignored; a write of one journal in progress no longer fails a read of another |

The recovery export keeps listing `legacy-store` as it is (it only reads).

### 4. An account removed outside this version (`WalletNetworkModelMigrator.migrateLocked`)

This version records a removal in the snapshot before it deletes the row, so
a snapshot wallet without a row was removed by a version that does not know
the snapshot. `verifyExistingSnapshot` now returns those wallets instead of
throwing, and `WalletNetworkStore.recordRemovalOutsideThisVersion` drops them
from the snapshot (the remaining wallets, their sources and their children
stay byte for byte; the selection moves to a remaining wallet if needed; the
previous snapshot file stays among the retained ones). The read-only startup
verification (`verifiedSnapshot`) compares against the snapshot as it will
be and writes nothing.

- A wallet present in both with a different address or public key still
  fails (`legacyIdentityMismatch`).
- No Keychain item is read, written or removed for the removed account. What
  3.8.6 left (`-secretKey`, `-seed`, `-deriv`; it deletes only `-entropy`)
  stays, so the account can be imported again.
- **Lower bound.** Removals are recorded only while the database still has
  at least one account. A database file with no account row at all beside a
  snapshot that lists wallets (the rows may have been lost: 3.8.6 removing
  the last account and dying after the row delete, a damaged store) is not
  taken for a removal. It stops with `legacyIdentityMismatch` as it did
  before this task, and the snapshot is not emptied, so the launch routing
  still knows a wallet existed.
- **An import cut short, then removed in 3.8.6**
  (`OrdinaryWalletAccountCommitRecovery.resolve`, `WalletKeySafety.swift`):
  an unfinished account-commit journal at `coreDataCommitted` or
  `networkModelActivated` whose row is gone used to throw
  `committedAccountMissing` on every launch. With other accounts still in
  the database it is the same case (the row was saved, 3.8.6 ran next and
  the user removed the account there): the journal is closed as `abandoned`
  through `WalletAccountCommitJournalStore.abandonAfterRemovalOutsideThisVersion`
  (the only caller of that transition; the ordinary `advance` is as strict
  as before) and the snapshot records the removal. No Keychain access. A
  database with no account at all still throws. The same path covers a row
  whose database transaction did not survive a power loss although the
  journal (which is synced to disk) had already advanced: the other
  accounts open, the keys of the lost row stay in the Keychain, and
  importing the phrase again adopts them.

### 4a. The display name follows the database (`WalletNetworkStore.verifyMonotonicActivation`)

A rename saves the account row first and the snapshot second
(`SelectedWalletSettings.performUpdate`, which is also the naming step of
create and import), and App Store 3.8.6 saves only the row. Startup builds
the proposed snapshot from the rows, and the activation check rejected any
existing wallet that was not equal to the stored one, name included. So a
snapshot that still held the earlier name failed every launch with
`snapshotVerificationFailed`, and "Try again" failed the same way:

- the process died, or the write failed (disk full, I/O), between the two
  saves of a rename;
- the account was renamed in App Store 3.8.6 after this version ran.

The display name is not part of a wallet's identity. The check now compares
id, address and secret source (with the one existing exception, a read-only
placeholder that gets its proven source) and the SORA2 and Nexus accounts as
before, and lets the name differ. The next activation writes a snapshot with
the database's name. A recovery marker latched by the failed rename
(`unexpected_failure`, retried at launch) is cleared by that launch.

### 5. Unreadable transaction records reach the recovery screen

`PendingTransactionRecords.requireReadable()` runs in the startup storage
checks after the database migration: the folder must validate (after the
sweep) and each of the three journals must pass the read its own store
begins every action with: `Sora2PendingSubmissionStore.all()`, and for the
Nexus and Polkamarkt journals the same code as their actors' `all()`
(`NexusPendingTransactionStore.requireReadableJournal`,
`PolkamarktPendingStore.requireReadableJournal`; the read was moved into a
static function that the actor method and the startup check both call, so
the two cannot drift). When one does not, startup ends on the recovery
screen instead of every send, Nexus transfer or Polkamarkt action being
refused later with no way out.

- The diagnostic phase is `pending_transactions`; the marker code is
  `unexpected_failure`, which is retried at every launch, so a transient read
  error clears itself.
- The recovery screen shows **Set aside unfinished transaction records**
  (from a fact read from the device, like the restore actions). After a
  confirmation it moves the folder to
  `Documents/WalletSetAside/<time>-<id>/PendingTransactions`, leaves an empty
  folder in its place and runs "Try again". Nothing is deleted. Accounts,
  keys, the wallet database and the network model are not touched.
- The body text names the actions the screen shows. The sentences about the
  records are chosen from the same fact as their button (the folder cannot
  be read now, and the screen can run the startup checks), not from the
  check that failed last: when that check failed for the records and they
  can be read by the time the screen appears, the text says so and offers
  "Try again" only; when another check failed and the records cannot be read
  either, one sentence explains the extra button.
- While the folder moves, the screen is busy like for the other actions:
  "Try again", "Set up this iPhone again", the export and a second set-aside
  cannot start. The startup checks run once, after the move.
- "Set up this iPhone again" also moves the folder when it cannot be read
  (and leaves a readable one in place, so a restored wallet still knows its
  unfinished transactions).

### 6. The three multi-step writes of N6

1. **Restore of a 3, 6 or 9-word phrase** (`UserStorageMigrator.restoreWriteOrder`):
   the seed is written before the short entropy. Killed after the first
   write, the account has an item that proves it, and the startup backfill
   adds the signing key. Before, it had only an entropy item that cannot be
   expanded: read-only, and a second restore was refused.
2. **Keys of an import, including the in-place restore of a read-only
   account** (`PreparedAccount.persist`): the path, then the phrase and the
   seed in the order of `restoreWriteOrder` (one shared rule), then the
   secret last. The first item written always proves the account by itself:
   the phrase when it has 12 to 24 words, the seed when the phrase has 3, 6
   or 9 words (a Google Drive backup made by App Store 3.8.6, imported
   through Add account). Killed after any write, the startup backfill adds
   the missing seed and secret. Before, a kill after the secret left an
   account that signed and never received its phrase; and with the phrase
   always first, a short phrase left an account with only an entropy that
   cannot be expanded: read-only for good, because a second import is
   refused once an item exists.
3. **"Set up this iPhone again"** (`WalletLocalStateSetAside.setAside`): the
   `INCOMPLETE` marker is written and synced before the first move. It is
   removed once the files are moved and the wallet settings removed, before
   the recovery marker is cleared, never after; if it cannot be removed the
   recovery marker stays and a retry continues there. A kill before that
   point leaves a folder the next attempt continues in, so the earlier data
   never ends up in two folders. A kill after it leaves a complete folder
   without the marker, so a later "Set up this iPhone again" for another
   wallet can never land in it. Should a marked folder already hold an item
   of the same name (the app recreated it in between, or a build before this
   fix left the mark on a finished folder), the later item goes into one
   `later-<time>-<id>` subfolder under its own name, and a database's
   `-wal`, `-shm` and `-journal` files follow the database file they belong
   to. Nothing gets a made-up name any more.

## Key safety

- No Keychain item is deleted, overwritten or moved by anything in this
  change. The only Keychain writes touched are the order of add-only writes
  in two places.
- No wallet address, public key or derivation changes.
- A sweep removes regular files with one of four exact hidden names. It
  cannot remove a snapshot, a pointer, a journal, a manifest or a database
  file.
- Checks that are not about helper files are as strict as before: another
  unexpected name, a symbolic link, a snapshot or journal that does not
  decode, a pointer whose digest does not match, ten snapshots.
- One removed account no longer locks the others. A database with no
  account row beside a snapshot that lists wallets is not treated as a
  removal: `migrateLocked` itself refuses it (see 4, "Lower bound").
  `UserStorageMigrator` does not always stop there first: it returns early
  when a verified safety backup exists.
- A rename changes the name in the snapshot and nothing else. Address,
  public key, secret source and Nexus children are checked as before.

## User-visible effect

- A force-quit, crash or battery death during the upgrade, an account
  switch, rename, add or removal no longer leads to the recovery screen on
  the next launch. The wallet opens.
- A force-quit during a send no longer makes later sends fail.
- Users of earlier 3.9.0 TestFlight builds who are on the recovery screen
  because of such a file: the next launch (or "Try again") opens the wallet.
- A tester who went back to App Store 3.8.6, removed or renamed an account
  there and returned: the wallet opens, with the remaining accounts and the
  new name.
- A rename that failed half-way (full disk, I/O error) no longer needs
  "Set up this iPhone again": the next launch completes it.
- New on the recovery screen, only when the transaction records cannot be
  read (now including the Nexus and Polkamarkt journals): "Set aside
  unfinished transaction records". The text of the screen says what that
  button does whenever it is shown, and never mentions it otherwise.

New strings (English and Japanese, at the end of both `Localizable.strings`
under the `ik2-leftover-files` comment): the button, its confirmation title
and text, "Set aside", "Could not set the records aside", the diagnostic
message and the "contact support" sentence for this state; and, from review
round 2, the sentence for unreadable records beside another failure, the
sentence for records that can be read again, and "Try again. If this screen
appears again, contact SORA support...".

## Tests

`SoraPassportTests/Common/Modernization/WalletKeySafetyTests.swift`, class
`WalletInterruptedWriteTests` (32 tests: 20 from the first round, 12 from
review round 2). A kill is modelled by copying the whole installation (files
with their hard links and extended attributes, Keychain items, settings) at
a writer checkpoint, and starting a fresh startup over the copy. An I/O
error is modelled by throwing from the checkpoint. The startup the tests run
is the production one: `WalletStorageStartup.runChecks`, then
`SplashInteractor.initializeWalletNetworksIfNeeded` and
`addScopedCopiesIfNeeded`.

| Test | Shows |
|---|---|
| `testOnlyTheWritersOwnNamesAreHelperFiles` | the four patterns match; 17 near-misses do not |
| `testSweepRemovesHelperFilesAndNothingElse` | published file, `.hidden`, a symbolic link and a directory with a helper name are untouched |
| `testAWriteInProgressIsNeverSweptAndNeverFailsAListing` | at each of the 7 steps of a write, a sweep from another thread is deferred and a strict listing sees only the published file |
| `testAKillAtAnyStepOfAWriteLeavesThePublishedFileWholeAndOnlySweepableFiles` | new and existing target, every step |
| `testAnErrorAtAnyStepOfAWriteLeavesNoHelperFileAndAWholePublishedFile` | an error at each of the 10 checkpoints, new and existing target |
| `testAnErrorWhileAFailedWriteIsRolledBackLeavesNoHelperFile` | a second error inside the rollback or the withdrawal |
| `testPlantedHelperFilesInEveryWalletFolderAreGoneAfterStartup` | 58 planted files (each kind, written and empty, and as extra names of a published file) in the six folders, with and without the startup sweep |
| `testAKillAtAnyStepOfTheFirstLaunchAfterTheUpgradeIsCompletedByTheNextLaunch` | 38 kill states of the first launch (two 3.8.6-format accounts); each revived twice |
| `testAKillAtAnyStepOfAnAccountSwitchOrRemovalIsCompletedByTheNextLaunch` | 22 kill states with eight snapshots already present (the ninth-snapshot window) |
| `testAKillAtAnyStepOfAnAccountJournalWriteLeavesAReadableJournal` | 32 kill states of a journal's five writes |
| `testAFirstSnapshotWithoutItsPointerIsCompletedAndOtherPointerlessStatesStillFail` | pointer rebuilt byte for byte; two pointer-less snapshots and an undecodable one still fail |
| `testAnAccountRemovedInAppStore386IsRecordedAsRemovedAndTheOthersOpen` | the 3.8.6 removal (`logoutAndClean`, copied) of a selected or unselected account, with and without the marker earlier 3.9.0 builds latched |
| `testAKillAtAnyStepOfATransactionRecordWriteNeverBlocksTheNextSend` | 7 kill states, then `stage()` succeeds |
| `testAWriteOfAnotherJournalInProgressDoesNotRefuseASend` | `stage()` at each step of another journal's write |
| `testUnreadableTransactionRecordsShowRecoveryAndCanBeSetAside` | unknown entry and undecodable journal: recovery, the option, set aside, ready, send works, keys and accounts unchanged |
| `testTheRecoveryScreenOffersToSetTheRecordsAsideOnlyWhenTheyCannotBeRead` | the button, the body text, the strings in both tables |
| `testAKillDuringTheRestoreOfAShortPhraseLeavesAnAccountTheNextLaunchCompletes` | 3, 6 and 9 words, killed after 1 and 2 Keychain writes |
| `testAKillDuringAnInPlaceKeyRestoreIsCompletedByTheNextLaunchWithThePhrase` | killed after 1 and 2 writes; phrase, seed and key equal the 3.8.6 bytes afterwards |
| `testOnTheRealKeychainAnInterruptedAccountWriteIsCompletedAddOnly` | the same on the simulator's real Keychain |
| `testSetUpAgainKilledAtAnyPointContinuesInTheSameFolder` | killed after the moves and between two moves |

Review round 2:

| Test | Shows |
|---|---|
| `testAKillAtAnyStepOfARenameIsCompletedByTheNextLaunchWithTheNewName` | a rename through `SelectedWalletSettings.performUpdateName` over the installation's own database file; 11 kill states (every step of the snapshot and pointer writes, all after the row was saved); each next launch ends ready with the new name in the database and the snapshot |
| `testARenameWhoseSnapshotWriteFailsIsCompletedByTheNextLaunch` | the snapshot write, then the pointer write, fails after the row was saved: a retryable marker, no helper file, and the next launch clears the marker and records the name |
| `testAnAccountRenamedInAppStore386OpensWithTheNewName` | the row-only save of 3.8.6 (`354f176c` `AccountOptionsInteractor.updateUsername`, copied), with and without the marker earlier 3.9.0 builds latched; nothing but the name changes |
| `testAKillDuringAnInPlaceRestoreOfAShortPhraseIsCompletedByTheNextLaunch` | 3, 6 and 9 words through `performInsertAndSelect`, killed after 1 and 2 Keychain writes; the seed goes first and the next launch ends with a signing account |
| `testAnImportCutShortAndThenRemovedInAppStore386DoesNotLockTheOtherAccounts` | journal at `coreDataCommitted` and at `networkModelActivated`, then the 3.8.6 removal: ready, journal `abandoned`, snapshot without the account, a new import works; a database with no account still throws |
| `testADatabaseWithNoAccountBesideASnapshotIsNotTakenForRemovedAccounts` | every row gone while the file and its safety backup stay: stops, snapshot not emptied |
| `testAHelperFileThatVanishesBetweenTheListingAndItsCheckIsLeftOut` | a listing that names a helper file already gone: left out, the send goes through; a directory with a helper name still fails |
| `testAnUnreadableNexusOrPolkamarktJournalShowsRecoveryAndCanBeSetAside` | a journal that does not decode (both) and a row its store refuses: that store throws, startup shows recovery with the action, set aside, ready |
| `testTheRecoveryTextAboutTheRecordsFollowsTheSameFactAsTheirButton` | button and text in every combination of failed check and readable or unreadable records; the new strings in both tables |
| `testWhileTheRecordsAreSetAsideNoOtherRecoveryActionCanStart` | the move held at its first step: every action disabled, "Try again" and a second set-aside do nothing; the checks run once, after the move |
| `testAFinishedSetAsideFolderIsNeverTakenForAnUnfinishedOne` | the recovery marker changes during the moves: the folder is not left marked; a later wallet gets its own folder; in a marked folder that already holds a database, the later database, `-wal` and `-shm` stay together in one subfolder |
| `testTheStorageChecksOfALaunchSweepHelperFilesBeforeAnythingElse` | `runChecks` sweeps all six folders even when it stops at a marker before any folder is read |

Also in `WalletModernizationTests`:
`testActivationBringsADisplayNameUpToDateAndNothingElse` (new: a name
change activates; a change of source or public key is still rejected) and
`testMigrationRecordsAnAccountRemovedOutsideThisVersion` (updated, see
below).

Proof that the tests fail without the fix: with the listing tolerance, the
writer's final cleanup, the pointer rebuild, the ninth-snapshot tolerance,
the removed-account handling, the two key orders and the early `INCOMPLETE`
marker reverted in the working tree, 16 of the 20 tests failed (123
assertions). The four that still passed test only new API (names, the sweep
itself, the new screen action and the new startup check).

Proof for review round 2: with the behaviour of its fixes taken out of the
working tree (the tests and the new functions kept), 13 of the 14 new or
updated tests failed, with 133 assertion failures. The fourteenth
(`testTheStorageChecksOfALaunchSweepHelperFilesBeforeAnythingElse`) compares
the sequence with and without its sweep itself. The 20 tests of the first
round passed either way.

Whole unit target after review round 2: 579 tests, 0 failures, 2 skipped
(566 after the first round, plus these 13). Release device build compiles;
the test checkpoint hook is not in the Release binary.

Run in the app (Debug build, simulator `SORA-Fix-keys`, an existing wallet,
Japanese):

- Seven helper files planted in `WalletNetworks`, `WalletAccountCommits`,
  `PendingTransactions`, the attempt folder and its `legacy-store` (two of
  them as extra names of `active.json` and `journal.json`). After the next
  launch all seven were gone, no recovery marker was set, and the screen was
  the same PIN entry as before, pixel for pixel.
- An unknown file planted in `PendingTransactions`: the next launch showed
  the recovery screen with the new text and the new button. The button, then
  its confirmation, moved the folder to `Documents/WalletSetAside/...`, ran
  the startup checks again and ended on PIN entry. The wallet database, the
  snapshot and the journal were unchanged.

Run in the app after review round 2 (Debug build, same simulator and
wallet): with the app closed, the account row was given a new name directly
in the database, as the row-only save of App Store 3.8.6 leaves it. The next
launch went through the real `SplashInteractor` (now calling
`WalletStorageStartup.runChecks`) to the same PIN entry, no recovery marker
was set, the active snapshot held the new name, and the earlier snapshot
file was kept beside it. The simulator's files were then put back as they
were.

Existing tests that pinned the old behaviour, updated in
`WalletModernizationTests.swift` and `WalletRecoveryCapabilityGateTests.swift`:

- `testDurableFileWriterPreservesProtectionAndPermissions`: a failed
  publication now leaves no hidden file (was: exactly one).
- `testPendingTransactionStoresSweepAnInterruptedPublicationAndRejectOtherEntries`
  (was `...RejectInterruptedDurablePublicationEvidence`).
- `testWalletNetworkStorePrunesOneSurplusSnapshotAndRejectsMore` (was
  `...RejectsUnprunedCanonicalSnapshotSet`).
- `testMigrationRecordsAnAccountRemovedOutsideThisVersion` (was
  `testMigrationCannotDropPreviouslyInventoriedAccount`). Review round 2:
  with no account in the database it throws again, as the original test
  required; with another account in the database the removal is recorded.
- `testRetainedGlobalEntropyConflictsDegradeOneAccountOrFailClosed`: the
  "snapshot" case (the snapshot lists only an account the database does not
  have) now opens instead of failing.
- `testVerifiedActivatedMigrationAttemptAllowsMutableAccessProbe`: real helper
  names are swept; a name that only resembles one still fails.

## Not changed, and why

- **Every row gone.** When App Store 3.8.6 removes the last account it drops
  the whole database folder and wipes the settings. The snapshot then is the
  only thing left of the wallet, and startup stops with `missing_wallet_store`
  as before. If 3.8.6 dies between the row delete and the drop, the database
  file stays with no row, and startup stops with `legacy_identity_mismatch`
  (the snapshot is kept). Both are the state of audit L-3 (a wallet without
  its database rows) and belong to that fix, not to this one. The recovery
  screen is shown with "Set up this iPhone again"; no key is touched.
- **A 1.x account that exists only as unsuffixed `seedEntropy` and is not in
  the snapshot** opens read-only when a snapshot exists, as before. Not
  reachable from 3.8.6 data.
- **A rename that fails after the row was saved still sets the recovery
  marker for the rest of that session**, as every write that fails after a
  database commit does. It is the retryable kind, and the next launch (or
  "Try again") clears it and records the name. Not latching it at all would
  change `SelectedWalletSettings.performUpdate` for every caller and was
  left alone.
- **A marked set-aside folder that lacks an item the later wallet has** (only
  a folder left marked by a 3.9.0 TestFlight build between the two review
  rounds can be in that state): that one item of the later wallet lands
  beside the earlier wallet's items instead of in the `later-...` subfolder.
  Nothing is lost; the database files always stay together.

## Review round 2: findings and what was done

| Finding | Done |
|---|---|
| Blocker: a rename still left a permanent recovery screen (kill or failed write between the two saves, or a rename in 3.8.6) | fixed, see 4a |
| Major: `PreparedAccount.persist` wrote a 3, 6 or 9-word entropy first | fixed, see 6.2 |
| A journal at `coreDataCommitted` or later whose row was removed in 3.8.6 locked every account | fixed, see 4 |
| Removal recording had no lower bound (an empty database emptied the snapshot); wrong sentence in these notes | fixed, see 4 and "Key safety". The bound is "the database still has at least one account", not "a snapshot wallet still has its row": a database whose only accounts were added in 3.8.6 after the snapshot's accounts were removed there is a healthy wallet and must open |
| `contentsIgnoringLeftovers` kept a helper entry that had vanished | fixed, see 1 |
| The startup check ignored the Nexus and Polkamarkt journals | fixed, see 5 |
| Recovery text chosen from the recorded check, button from a live look | fixed, see 5 |
| Only the records button was disabled while the folder moved | fixed, see 5 |
| `INCOMPLETE` removed last; a finished folder could be reused and mixed | fixed, see 6.3 |
| No test ran the production startup sequence | fixed, see 2 |

## Human and ops actions

- Device QA, once: force-quit the app during the first launch after an
  upgrade from 3.8.6, during a send and right after confirming a new account
  name (several attempts each), relaunch, and confirm the wallet opens, the
  name is the new one and a send works. The unit tests cover every step of
  every write, but with a copied directory, not with a real kill on APFS on
  a device.
- Downgrade QA, once (TestFlight build over App Store 3.8.6 data and back):
  rename one account and remove another in 3.8.6, return to 3.9.0, and
  confirm the wallet opens with the new name and without the removed
  account.
- Support: `Documents/WalletSetAside/<time>-<id>/PendingTransactions` is where
  set-aside transaction records go. The folder is not uploaded anywhere.
- No migration, configuration or server change.
