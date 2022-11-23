import Foundation
import BigInt

protocol SwapQuoteConverterProtocol {
    func createAmounts(fromAsset: AssetInfo, toAsset: AssetInfo, params: PolkaswapMainInteractorQuoteParams, quote: SwapValues) -> SwapQuoteAmounts?
}

struct SwapQuoteAmounts {
    let fromAmount: Decimal
    let toAmount: Decimal
    let lpAmount: Decimal
}

class SwapQuoteAmountsFactory: SwapQuoteConverterProtocol {
    func createAmounts(fromAsset: AssetInfo, toAsset: AssetInfo, params: PolkaswapMainInteractorQuoteParams, quote: SwapValues) -> SwapQuoteAmounts? {
        guard
            let fromAmountBig = BigUInt(params.amount),
            let toAmountBig = BigUInt(quote.amount),
            let feeBig = BigUInt(quote.fee),
            let fromAmount = Decimal.fromSubstrateAmount(fromAmountBig, precision: Int16(fromAsset.precision)),
            let toAmount = Decimal.fromSubstrateAmount(toAmountBig, precision: Int16(toAsset.precision)),
            let lpAmount = Decimal.fromSubstrateAmount(feeBig, precision: 18) else {
                return nil
        }

        return SwapQuoteAmounts(fromAmount: fromAmount,
                              toAmount: toAmount,
                              lpAmount: lpAmount)
    }
}
