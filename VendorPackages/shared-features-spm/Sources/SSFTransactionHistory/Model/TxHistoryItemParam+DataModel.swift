import Foundation
import XNetworking

struct TransferData {
    let to: String
    let from: String
    let amount: String
    let assetId: String
    let chainId: String
}

struct ReferralData {
    let amount: String
}

struct SetReferrerData {
    let address: String
    let my: Bool
}

struct SwapData {
    let selectedMarket: String
    let liquidityProviderFee: String
    let baseTokenId: String
    let baseTokenAmount: String
    let baseChainId: String
    let targetTokenId: String
    let targetTokenAmount: String
    let targetChainId: String
}

struct LiquidityData {
    let baseTokenId: String
    let targetTokenId: String
    let baseTokenAmount: String
    let targetTokenAmount: String
}

struct ClaimRewardsData {
    let amount: String
    let rewardAssetId: String
}

struct FarmLiquidityData {
    let baseTokenId: String
    let poolTokenId: String
    let rewardAssetId: String
    let amount: String
}

extension Array where Element == TxHistoryItemParam {
    func toTransferData() -> TransferData {
        TransferData(
            to: first { $0.paramName == "to" }?.paramValue ?? "",
            from: first { $0.paramName == "from" }?.paramValue ?? "",
            amount: first { $0.paramName == "amount" }?.paramValue ?? "",
            assetId: first { $0.paramName == "assetId" }?.paramValue ?? "",
            chainId: first { $0.paramName == "chainId" }?.paramValue ?? ""
        )
    }

    func toReferralData() -> ReferralData {
        ReferralData(amount: first { $0.paramName == "amount" }?.paramValue ?? "")
    }

    func toSetReferrerData(with myAddress: String) -> SetReferrerData {
        let to = first { $0.paramName == "to" }?.paramValue ?? ""
        let from = first { $0.paramName == "from" }?.paramValue ?? ""
        let isMyReferrer = from == myAddress

        return SetReferrerData(address: isMyReferrer ? to : from, my: isMyReferrer)
    }

    func toSwapData() -> SwapData {
        SwapData(
            selectedMarket: first { $0.paramName == "selectedMarket" }?.paramValue ?? "",
            liquidityProviderFee: first { $0.paramName == "liquidityProviderFee" }?
                .paramValue ?? "",
            baseTokenId: first { $0.paramName == "baseAssetId" }?.paramValue ?? "",
            baseTokenAmount: first { $0.paramName == "baseAssetAmount" }?.paramValue ?? "",
            baseChainId: first { $0.paramName == "baseChainId" }?.paramValue ?? "",
            targetTokenId: first { $0.paramName == "targetAssetId" }?.paramValue ?? "",
            targetTokenAmount: first { $0.paramName == "targetAssetAmount" }?.paramValue ?? "",
            targetChainId: first { $0.paramName == "targetChainId" }?.paramValue ?? ""
        )
    }

    func toLiquidityData() -> LiquidityData {
        LiquidityData(
            baseTokenId: first { $0.paramName == "baseAssetId" }?.paramValue ?? "",
            targetTokenId: first { $0.paramName == "targetAssetId" }?
                .paramValue ?? "",
            baseTokenAmount: first { $0.paramName == "baseAssetAmount" }?
                .paramValue ?? "",
            targetTokenAmount: first { $0.paramName == "targetAssetAmount" }?
                .paramValue ?? ""
        )
    }

    func toLiquidityBatchData() -> LiquidityData {
        LiquidityData(
            baseTokenId: first { $0.paramName == "input_asset_a" }?.paramValue ?? "",
            targetTokenId: first { $0.paramName == "input_asset_b" }?
                .paramValue ?? "",
            baseTokenAmount: first { $0.paramName == "input_a_desired" }?
                .paramValue ?? "",
            targetTokenAmount: first { $0.paramName == "input_b_desired" }?
                .paramValue ?? ""
        )
    }

    func toClaimRewardData() -> ClaimRewardsData {
        ClaimRewardsData(
            amount: first { $0.paramName == "amount" }?.paramValue ?? "",
            rewardAssetId: first { $0.paramName == "assetId" }?
                .paramValue ?? ""
        )
    }

    func toFarmLiquidity() -> FarmLiquidityData {
        FarmLiquidityData(
            baseTokenId: first { $0.paramName == "baseAssetId" }?.paramValue ?? "",
            poolTokenId: first { $0.paramName == "assetId" }?.paramValue ?? "",
            rewardAssetId: first { $0.paramName == "rewardAssetId" }?.paramValue ?? "",
            amount: first { $0.paramName == "amount" }?.paramValue ?? ""
        )
    }
}
