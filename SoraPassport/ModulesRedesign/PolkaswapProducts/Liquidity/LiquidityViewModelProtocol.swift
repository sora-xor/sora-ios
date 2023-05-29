import SoraUIKit
import UIKit

protocol LiquidityViewModelProtocol: InputAccessoryViewDelegate {
    var title: String? { get }
    var imageName: String? { get }
    var firstFieldEmptyStateFullFiatText: String? { get }
    var secondFieldEmptyStateFullFiatText: String? { get }
    var isSwap: Bool { get }
    var actionButtonImage: UIImage? { get }
    var inputedFirstAmount: Decimal { get set }
    var inputedSecondAmount: Decimal { get set }
    var middleButtonActionHandler: (() -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var focusedField: FocusedField { get set }
    func viewDidLoad()
    func infoButtonTapped()
    func apyInfoButtonTapped()
    func choiсeBaseAssetButtonTapped()
    func choiсeTargetAssetButtonTapped()
    func changeSlippageTolerance()
    func changeMarket()
    func minMaxReceivedInfoButtonTapped()
    func networkFeeInfoButtonTapped()
    func lpFeeInfoButtonTapped()
    func reviewButtonTapped()
    func recalculate(field: FocusedField)
}

extension LiquidityViewModelProtocol {
    func infoButtonTapped() {}
    func apyInfoButtonTapped() {}
    func changeMarket() {}
    func minMaxReceivedInfoButtonTapped() {}
    func networkFeeInfoButtonTapped() {}
    func lpFeeInfoButtonTapped() {}
    var firstFieldEmptyStateFullFiatText: String? { "" }
    var secondFieldEmptyStateFullFiatText: String? { "" }
}
