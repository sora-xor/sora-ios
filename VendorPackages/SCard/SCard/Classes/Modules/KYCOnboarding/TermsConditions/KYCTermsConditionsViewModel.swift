import Foundation
import UIKit
import SoraUIKit

protocol KYCTermsConditionsViewModelProtocol {
    var onAccept: (() -> Void)? { get set }
    var onGeneralTerms: (() -> Void)? { get set }
    var onPrivacy: (() -> Void)? { get set }
}

final class KYCTermsConditionsViewModel {

    var onBlacklistedCountries : (() -> Void)?
    var onGeneralTerms: (() -> Void)?
    var onPrivacy: (() -> Void)?
    var onAccept: (() -> Void)?
}

extension KYCTermsConditionsViewModel: KYCTermsConditionsViewModelProtocol {

}
