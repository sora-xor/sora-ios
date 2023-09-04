import SoraUIKit

final class EnterPasswordItem: NSObject {

    let accountName: String?
    let accountAddress: String
    let errorText: String
    let continueButtonHandler: ((String) -> Void)?

    init(accountName: String? = nil, accountAddress: String, errorText: String, continueButtonHandler: ((String) -> Void)?) {
        self.accountName = accountName
        self.accountAddress = accountAddress
        self.errorText = errorText
        self.continueButtonHandler = continueButtonHandler
    }
}

extension EnterPasswordItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        EnterPasswordCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
}
