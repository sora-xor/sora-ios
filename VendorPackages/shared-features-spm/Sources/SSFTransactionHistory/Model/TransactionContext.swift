import Foundation
import SSFModels
import XNetworking

struct TransactionContext {
    let type: TransactionType
    let baseAmount: Decimal?
    let baseAssetId: String?
    let baseChainId: String?
    let targetAmount: Decimal?
    let targetAssetId: String?
    let targetChainId: String?
    let rewardAmount: Decimal?
    let rewardAssetId: String?
    let rewardChainId: String?
    let sender: String?
    let recipient: String?

    init(
        type: TransactionType,
        baseAmount: Decimal? = nil,
        baseAssetId: String? = nil,
        baseChainId: String? = nil,
        targetAmount: Decimal? = nil,
        targetAssetId: String? = nil,
        targetChainId: String? = nil,
        rewardAmount: Decimal? = nil,
        rewardAssetId: String? = nil,
        rewardChainId: String? = nil,
        sender: String? = nil,
        recipient: String? = nil
    ) {
        self.type = type
        self.baseAmount = baseAmount
        self.baseAssetId = baseAssetId
        self.baseChainId = baseChainId
        self.targetAmount = targetAmount
        self.targetAssetId = targetAssetId
        self.targetChainId = targetChainId
        self.rewardAmount = rewardAmount
        self.rewardAssetId = rewardAssetId
        self.rewardChainId = rewardChainId
        self.sender = sender
        self.recipient = recipient
    }

    init?(
        callPath: TransactionHistorySupportedCodingPath,
        userAccountAddress: String,
        item: TxHistoryItem
    ) {
        switch callPath {
        case .transfer, .transferKeepAlive, .adarTransfer:
            guard let transferData = item.data?.toTransferData() else {
                return nil
            }
            let type: TransactionType = transferData.to == userAccountAddress ? .received : .sent
            let amount = SubstrateAmountDecimal(string: transferData.amount)?.decimalValue
            self = TransactionContext(
                type: type,
                baseAmount: amount,
                baseAssetId: transferData.assetId,
                baseChainId: transferData.chainId,
                sender: transferData.from,
                recipient: transferData.to
            )
            return
        case .swap:
            guard let swapData = item.data?.toSwapData() else {
                return nil
            }
            let baseAmount = SubstrateAmountDecimal(string: swapData.baseTokenAmount)?.decimalValue
            let targetAmount = SubstrateAmountDecimal(string: swapData.targetTokenAmount)?
                .decimalValue
            self = TransactionContext(
                type: .swapped,
                baseAmount: baseAmount,
                baseAssetId: swapData.baseTokenId,
                targetAmount: targetAmount,
                targetAssetId: swapData.targetTokenId
            )
            return
        case .depositLiquidity, .withdrawLiquidity:
            guard let liquidityData = item.data?.toLiquidityData() else {
                return nil
            }
            let type: TransactionType = item.method == "depositLiquidity" ? .poolIn : .poolOut
            let baseAmount = SubstrateAmountDecimal(string: liquidityData.baseTokenAmount)?
                .decimalValue
            let targetAmount = SubstrateAmountDecimal(string: liquidityData.targetTokenAmount)?
                .decimalValue
            self = TransactionContext(
                type: type,
                baseAmount: baseAmount,
                baseAssetId: liquidityData.baseTokenId,
                targetAmount: targetAmount,
                targetAssetId: liquidityData.targetTokenId
            )
            return
        case .farmDeposit, .farmWithdraw:
            guard let data = item.data?.toFarmLiquidity() else {
                return nil
            }

            let baseAmount = SubstrateAmountDecimal(string: data.amount)?.decimalValue
            let type: TransactionType = item.method == "deposit" ? .farmIn : .farmOut
            self = TransactionContext(
                type: type,
                baseAmount: baseAmount,
                baseAssetId: data.baseTokenId,
                targetAssetId: data.poolTokenId,
                rewardAssetId: data.rewardAssetId,
                sender: userAccountAddress
            )
            return
        case .bondReferralBalance, .unbondReferralBalance:
            guard let referralBondData = item.data?.toReferralData() else {
                return nil
            }

            let type: TransactionType = item.method == "reserve" ? .bond : .unbond
            let baseAmount = SubstrateAmountDecimal(string: referralBondData.amount)?.decimalValue
            self = TransactionContext(
                type: type,
                baseAmount: baseAmount,
                sender: userAccountAddress
            )
            return
        case .setReferral:
            guard let setReferrerData = item.data?.toSetReferrerData(with: userAccountAddress) else {
                return nil
            }
            let type: TransactionType = setReferrerData.my ? .referralSet : .referralJoin
            self = TransactionContext(
                type: type,
                sender: setReferrerData.address
            )
            return
        case .getRewards:
            guard let claimData = item.data?.toClaimRewardData() else {
                return nil
            }

            let baseAmount = SubstrateAmountDecimal(string: claimData.amount)?.decimalValue
            self = TransactionContext(
                type: .rewarded,
                baseAmount: baseAmount,
                rewardAssetId: claimData.rewardAssetId,
                recipient: userAccountAddress
            )
            return
        case .batchUtility, .batchAllUtility:
            if let depositLiquidityData = item.nestedData?
                .first(where: { $0.method == "depositLiquidity" })
            {
                let liquidityBatchData = depositLiquidityData.data.toLiquidityBatchData()

                let baseAmount = SubstrateAmountDecimal(string: liquidityBatchData.baseTokenAmount)
                let targetAmount = SubstrateAmountDecimal(
                    string: liquidityBatchData
                        .targetTokenAmount
                )
                self = TransactionContext(
                    type: .poolIn,
                    baseAmount: baseAmount?.decimalValue,
                    baseAssetId: liquidityBatchData.baseTokenId,
                    targetAmount: targetAmount?.decimalValue,
                    targetAssetId: liquidityBatchData.targetTokenId
                )
                return
            }

            if let withdrawLiquidityData = item.nestedData?
                .first(where: { $0.method == "withdrawLiquidity" })
            {
                let liquidityBatchData = withdrawLiquidityData.data.toLiquidityBatchData()

                let baseAmount = SubstrateAmountDecimal(string: liquidityBatchData.baseTokenAmount)
                let targetAmount = SubstrateAmountDecimal(
                    string: liquidityBatchData
                        .targetTokenAmount
                )
                self = TransactionContext(
                    type: .poolOut,
                    baseAmount: baseAmount?.decimalValue,
                    baseAssetId: liquidityBatchData.baseTokenId,
                    targetAmount: targetAmount?.decimalValue,
                    targetAssetId: liquidityBatchData.targetTokenId
                )
                return
            }

        case .migration:
            return nil
        }

        return nil
    }
}
