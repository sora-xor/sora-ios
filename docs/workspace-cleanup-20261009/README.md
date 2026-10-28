# Workspace consolidation — 9 October 2026

The `sora-wallet` workspace now keeps three canonical repositories: `sora-ios`,
`sora-android`, and `polkaswap-indexer`. This directory records the files and
Git history consolidated into `sora-ios`.

## Preserved work

- `git-recovery.json` maps removed checkouts to their original heads and recovery refs.
- `relocated-files.json` maps loose files and evidence to their new locations.
  Individual relocated files include SHA-256 hashes.
- `reports/` contains historical reports moved from the workspace root.
- Local source snapshots are under `refs/heads/recovery/20261009/`. They preserve
  unfinished work for later review; they are not release-qualified changes.
- After cleanup, the owner requested committing and pushing accumulated source
  work on the existing `modernize` branch. Pre-commit source snapshots
  and the original staged Android state remain in the recovery refs.
- Recovery branches are included in the push plan, so source from removed
  folders can be recovered from GitHub. Local evidence is excluded from pushes.
- Product branches were not merged as part of consolidation.

## Recovering a source snapshot

List the saved branches from this repository:

```sh
git for-each-ref --format='%(refname:short) %(objectname:short)' refs/heads/recovery/20261009/
```

Use the manifest to choose the relevant ref, then inspect it with `git show`
or create a worktree at a new path with `git worktree add PATH REF`. Preserve
current local edits before switching branches in the canonical checkout.

## Local artifacts

`.local/workspace-cleanup-20261009/` holds retained release evidence and other
local artifacts. It is excluded through `.git/info/exclude`; these files are
not checked into Git or uploaded. Back up this directory separately if needed.

Redundant checkouts and rebuildable outputs were removed after preserving
source. Xcode DerivedData, downloaded SourcePackages, compiler caches, build
intermediates, and their build-local logs were discarded. Retained standalone
release archives and exported test-result bundles remain in the local archive.

Historical documents and scripts retain their original contents, dates, and
path references for provenance. Those paths may refer to removed checkouts;
use the manifests to locate the preserved source and artifacts. Historical
scripts require review and updated paths before reuse. Validation before the requested commit/push is recorded in `validation.json`.
This does not requalify old release evidence.

## Imported iOS release repositories

All refs from the twelve historical `candidate.git` repositories were imported
under `refs/archive/workspace-20261009/<original-directory>/`. Each import has
a source-ref-to-object mapping in `git-recovery.json`; dirty worktrees also have
normal recovery branches. The canonical repository has no dependency on the
removed object stores.

`historical-tools/` preserves standalone scripts and patches. Raw diagnostic
files, patches with credential-like literals, signed `.xcarchive` bundles,
exported `.xcresult` bundles, and other retained TestFlight evidence are under
`.local/workspace-cleanup-20261009/testflight-20260906/`.

The Torii integration patch is preserved in `iroha-patches/`; the Iroha
repository outside this workspace was not modified.
