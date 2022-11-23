import Foundation

enum NextButtonState: Equatable {
    case chooseTokens
    case enterAmount
    case insufficientLiquidity
    case swapEnabled
    case poolEnabled
    case removeEnabled
    case poolNotCreated
    case insufficientBalance(token: String)
    case loading
    case enabled
    
    func title(preferredLanguages: [String]?) -> String {
        switch self {
        case .chooseTokens:
            return R.string.localizable.chooseTokens(preferredLanguages: preferredLanguages)
        case .enterAmount:
            return R.string.localizable.commonEnterAmount(preferredLanguages: preferredLanguages)
        case .insufficientLiquidity:
            return R.string.localizable.polkaswapInsufficientLiqudity(preferredLanguages: preferredLanguages)
        case .swapEnabled:
            return R.string.localizable.polkaswapSwapTitle(preferredLanguages: preferredLanguages)
        case .poolEnabled:
            return R.string.localizable.commonSupply(preferredLanguages: preferredLanguages)
        case .removeEnabled:
            return R.string.localizable.commonRemove(preferredLanguages: preferredLanguages)
        case .poolNotCreated:
            return R.string.localizable.polkaswapPoolNotCreated(preferredLanguages: preferredLanguages)
        case .insufficientBalance(let token):
            return R.string.localizable.polkaswapInsufficientBalance(token, preferredLanguages: preferredLanguages)
        case .enabled:
            return R.string.localizable.polkaswapSwapTitle(preferredLanguages: preferredLanguages)
        case .loading:
            return ""
        }
    }
}

enum DetailsState {
    case disabled
    case expanded
    case collapsed
}
