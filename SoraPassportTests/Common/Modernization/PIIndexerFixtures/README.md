# PI indexer fixtures

Responses of `https://pi.soramitsu.io/graphql`, captured on 11 October 2026 at
01:00 UTC with the app's request headers. The bytes are exactly what the server
sent; nothing was edited. They contain public chain data only.

| File | Operation and variables |
|---|---|
| `health.json` | `MobileHealth`. The response carried `Date: Sun, 11 Oct 2026 01:00:01 GMT`. |
| `mobile-config.json` | `MobileConfig`. Note `nexusAvailable`, `polkamarktVisible` and `tairaDefaultVisible` are `true`. |
| `assets-first-page.json` | `MobileAssets`, the 3.9.0 query (`id priceUSD liquidity priceChangeDay`), `first: 4`. |
| `assets-page.json` | The same query, `first: 8`, at the cursor before XOR: XOR, VAL, PSWAP, XSTUSD and others, with real prices. |
| `assets-page-with-volumes.json` | The same page with the query the 10 October candidate sent. `volumeDayUSD` and `volumeWeekUSD` are JSON numbers; this is the response that failed to decode. |
| `pools-first-page.json` | `MobilePoolXYKs`, `first: 4`. |
| `history-signer-page.json` | `MobileHistory`, signer-only filter, `first: 4`, for an active account. |
| `history-by-hash.json` | `MobileHistory`, the pending-transaction lookup shape (`id in` plus all roles), `first: 2`. |
| `history-all-roles-rejected.json` | `MobileHistory` with the all-roles filter: `BAD_USER_INPUT`. |
| `referrer-rewards-page.json` | `MobileReferrerRewards` ordered by `[ID_DESC]`. |
| `referrer-rewards-timestamp-order-rejected.json` | `MobileReferrerRewards` ordered by timestamp: `BAD_USER_INPUT`. |
| `referrer-rewards-nonzero-page.json` | `MobileReferrerRewards` ordered by `[ID_DESC]` for a referrer with a reward that is not zero. Captured later the same day, at 19:08 UTC. The amount is a whole number of the token's smallest unit (`183330193640403131` is 0.18 XOR). |

To refresh them, send the queries in `PIIndexerClient.swift` with the headers
`executeQualified` sets and save the response bodies unchanged.
