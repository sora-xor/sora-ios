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
  progress, or a removal failed). Every other entry is returned unchanged, so
  an unexpected name still fails the check.
- **Checkpoints for tests.** `DurableFileWriter.Checkpoint` names the steps of
  a write. `checkpointObserver` exists only in `DEBUG` builds; the App Store
  build compiles `reach` to nothing.

### 2. Startup sweep (`SoraPassport/Common/Migration/WalletRecoveryOptions.swift`, `WalletInterruptedWriteCleanup`)

`SplashInteractor.performStorageMigration` first sweeps `WalletNetworks`,
`WalletAccountCommits`, `PendingTransactions` and, for every attempt folder in
`WalletMigrationSafety`, its root, `legacy-store` and `staging`. It runs
before any check, on the storage queue, after the device is unlocked. It
reads no file content and touches no key.

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

### 5. Unreadable transaction records reach the recovery screen

`PendingTransactionRecords.requireReadable()` runs in the startup storage
checks after the database migration: the folder must validate (after the
sweep) and the SORA2 journal must decode. When it does not, startup ends on
the recovery screen instead of every send being refused later.

- The diagnostic phase is `pending_transactions`; the marker code is
  `unexpected_failure`, which is retried at every launch, so a transient read
  error clears itself.
- The recovery screen shows **Set aside unfinished transaction records**
  (from a fact read from the device, like the restore actions). After a
  confirmation it moves the folder to
  `Documents/WalletSetAside/<time>-<id>/PendingTransactions`, leaves an empty
  folder in its place and runs "Try again". Nothing is deleted. Accounts,
  keys, the wallet database and the network model are not touched.
- The body text for this state names that action instead of "restore with
  your recovery phrase".
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
   account** (`PreparedAccount.persist`): path, phrase, seed, then the secret
   last. Killed after any write, the account is proven by its phrase or seed
   and the startup backfill adds the missing seed and secret. Before, a kill
   after the secret left an account that signed and never received its
   phrase.
3. **"Set up this iPhone again"** (`WalletLocalStateSetAside.setAside`): the
   `INCOMPLETE` marker is written and synced before the first move and
   removed after the last step (after the settings are removed and the
   recovery marker is cleared). A kill at any point leaves a folder the next
   attempt continues in, so the earlier data never ends up in two folders.

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
- One removed account no longer locks the others. An empty database beside a
  snapshot (every row gone) is still not treated as a removal:
  `UserStorageMigrator` stops there before the network model is reached.

## User-visible effect

- A force-quit, crash or battery death during the upgrade, an account
  switch, rename, add or removal no longer leads to the recovery screen on
  the next launch. The wallet opens.
- A force-quit during a send no longer makes later sends fail.
- Users of earlier 3.9.0 TestFlight builds who are on the recovery screen
  because of such a file: the next launch (or "Try again") opens the wallet.
- A tester who went back to App Store 3.8.6, removed an account there and
  returned: the wallet opens with the remaining accounts.
- New on the recovery screen, only when the transaction records cannot be
  read: "Set aside unfinished transaction records".

New strings (English and Japanese, at the end of both `Localizable.strings`
under the `ik2-leftover-files` comment): the button, its confirmation title
and text, "Set aside", "Could not set the records aside", the diagnostic
message and the "contact support" sentence for this state.

## Tests

`SoraPassportTests/Common/Modernization/WalletKeySafetyTests.swift`, class
`WalletInterruptedWriteTests` (20 tests). A kill is modelled by copying the
whole installation (files with their hard links and extended attributes,
Keychain items, settings) at a writer checkpoint, and starting a fresh
startup over the copy. An I/O error is modelled by throwing from the
checkpoint.

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

Proof that the tests fail without the fix: with the listing tolerance, the
writer's final cleanup, the pointer rebuild, the ninth-snapshot tolerance,
the removed-account handling, the two key orders and the early `INCOMPLETE`
marker reverted in the working tree, 16 of the 20 tests failed (123
assertions). The four that still passed test only new API (names, the sweep
itself, the new screen action and the new startup check).

Whole unit target after the change: 566 tests, 0 failures, 2 skipped (546
before, plus these 20). Release device build compiles; the test checkpoint
hook is not in the Release binary.

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

Existing tests that pinned the old behaviour, updated in
`WalletModernizationTests.swift` and `WalletRecoveryCapabilityGateTests.swift`:

- `testDurableFileWriterPreservesProtectionAndPermissions`: a failed
  publication now leaves no hidden file (was: exactly one).
- `testPendingTransactionStoresSweepAnInterruptedPublicationAndRejectOtherEntries`
  (was `...RejectInterruptedDurablePublicationEvidence`).
- `testWalletNetworkStorePrunesOneSurplusSnapshotAndRejectsMore` (was
  `...RejectsUnprunedCanonicalSnapshotSet`).
- `testMigrationRecordsAnAccountRemovedOutsideThisVersion` (was
  `testMigrationCannotDropPreviouslyInventoriedAccount`).
- `testRetainedGlobalEntropyConflictsDegradeOneAccountOrFailClosed`: the
  "snapshot" case (the snapshot lists only an account the database does not
  have) now opens instead of failing.
- `testVerifiedActivatedMigrationAttemptAllowsMutableAccessProbe`: real helper
  names are swept; a name that only resembles one still fails.

## Not changed, and why

- **Every row gone.** When App Store 3.8.6 removes the last account it drops
  the whole database folder and wipes the settings. The snapshot then is the
  only thing left of the wallet, and startup stops with `missing_wallet_store`
  as before. That is the state of audit L-3 (a wallet folder without its
  database) and belongs to that fix, not to this one.
- **A 1.x account that exists only as unsuffixed `seedEntropy` and is not in
  the snapshot** opens read-only when a snapshot exists, as before. Not
  reachable from 3.8.6 data.
- **The Nexus and Polkamarkt journals** are checked by their own stores when
  those features are used. The startup check covers the folder and the SORA2
  journal, which is what every send needs.

## Human and ops actions

- Device QA, once: force-quit the app during the first launch after an
  upgrade from 3.8.6 and during a send (several attempts each), relaunch, and
  confirm the wallet opens and a send works. The unit tests cover every step
  of every write, but with a copied directory, not with a real kill on
  APFS on a device.
- Support: `Documents/WalletSetAside/<time>-<id>/PendingTransactions` is where
  set-aside transaction records go. The folder is not uploaded anywhere.
- No migration, configuration or server change.
