import Foundation
import UIKit
import CommonWallet
import SoraUIKit

enum Cards: Int, CaseIterable {
    case soraCard = 0, referralProgram, liquidAssets, pooledAssets
    
    var id: Int {
        return self.rawValue
    }
    
    var title: String {
        switch self {
        case .soraCard:
            return R.string.localizable.moreMenuSoraCardTitle(preferredLanguages: .currentLocale)
        case .referralProgram:
            return R.string.localizable.referralToolbarTitle(preferredLanguages: .currentLocale)
        case .liquidAssets:
            return R.string.localizable.liquidAssets(preferredLanguages: .currentLocale)
        case .pooledAssets:
            return R.string.localizable.pooledAssets(preferredLanguages: .currentLocale)
        }
    }
    
    var defaultState: State {
        switch self {
        case .soraCard, .referralProgram, .pooledAssets:
            return .selected
        case .liquidAssets:
            return .unselected
        }
    }
}

enum State {
    case selected
    case unselected
    case disabled
}

final class EnabledViewModel {
    let id: Int
    let title: String
    var state: State
    
    init(id: Int,
         title: String,
         state: State) {
        self.id = id
        self.title = title
        self.state = state
    }
    
}
