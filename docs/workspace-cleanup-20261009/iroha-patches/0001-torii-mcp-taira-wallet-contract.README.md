# Torii MCP Taira wallet contract patch

Upstream base: Hyperledger Iroha commit `fbe677b98ed309808074ec5a0a8a16de2a0c2286`.

Patch: `0001-torii-mcp-taira-wallet-contract.patch`

## Apply

```zsh
git checkout fbe677b98ed309808074ec5a0a8a16de2a0c2286
git apply --check /Users/takemiyamakoto/dev/sora-wallet/iroha-patches/0001-torii-mcp-taira-wallet-contract.patch
git apply /Users/takemiyamakoto/dev/sora-wallet/iroha-patches/0001-torii-mcp-taira-wallet-contract.patch
```

The patch changes only:

- `crates/iroha_torii/src/lib.rs`
- `crates/iroha_torii/src/mcp.rs`
- `crates/iroha_torii/src/routing.rs`
- `status.md`

It does not include `Cargo.lock` or other generated files.

## Contract implemented

- `iroha.transactions.submit_and_wait` decodes and verifies the signed Norito submission receipt, requires the response hash header and any caller hash to match `payload.tx_hash`, polls only that verified hash, and waits for authoritative global state finality at a positive block height.
- Its returned submission body is a verified JSON projection, with coherent JSON content-type fields and a raw lowercase 64-hex `payload.tx_hash`. The canonical Norito receipt is signature-verified before projection; the projected JSON bytes are not a re-signable receipt encoding.
- `application/x-norito` response bodies are always represented as base64, including byte strings that happen to be valid UTF-8.
- Explorer instructions accept `asset_definition_id`, match incoming/outgoing transfer and batch legs by definition, and reject simultaneous `asset_id` and `asset_definition_id` filters.
- Curated schemas advertise the actual account-assets `asset`/`scope` and transaction-status `scope` arguments.

## Verification

Formatting and patch checks passed:

```zsh
cargo fmt --all -- --check
git diff --check
```

The base checkout has no lockfile and fresh dependency resolution currently fails because `halo2_gadgets 0.3.1` is yanked. Tests were therefore verified with a historical external lockfile only; it is not part of this patch. Exact invocation template used for each filter:

```zsh
RUSTC="$(rustup which --toolchain 1.93.1-aarch64-apple-darwin rustc)" \
RUSTDOC="$(rustup which --toolchain 1.93.1-aarch64-apple-darwin rustdoc)" \
cargo +nightly-2025-05-08 -Z unstable-options test \
  --lockfile-path /tmp/sora-taira-review.THLBZK/cargo-lock/Cargo.lock \
  --locked -p iroha_torii FILTER --lib -- --nocapture
```

Focused results:

- `normalize_verified_transaction_submission`: 4 passed.
- `decode_response_body_always_base64_encodes_norito_even_when_utf8`: 1 passed.
- `canonical_submit_wait_status_poll_forces_global_scope`: 1 passed.
- `authoritative_global_applied_status_requires_state_and_positive_block`: 1 passed.
- `pipeline_status_handler_global_scope_ignores_terminal_cache_and_reads_state`: 1 passed.
- `instruction_list_schema_and_dispatch_advertise_asset_definition_filter`: 1 passed.
- `account_assets_and_transaction_status_schemas_advertise_routed_query_keys`: 1 passed.
- `explorer_instruction_definition_filter`: 2 passed.
- `extract_transaction_hash_from_submit_result_decodes_submission_receipt`: 1 passed.

All focused tests passed with zero failures.
