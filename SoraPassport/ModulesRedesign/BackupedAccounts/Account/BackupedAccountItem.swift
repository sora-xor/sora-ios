import SoraUIKit

final class BackupedAccountItem: NSObject {
    
    struct Config {
        let cornerMask: CornerMask
        let cornerRaduis: Radius
        let topOffset: CGFloat
        let bottomOffset: CGFloat
    }

    let accountName: String?
    let accountAddress: String
    let config: Config
    
    init(accountName: String? = nil,
         accountAddress: String,
         config: Config
    ) {
        self.accountName = accountName
        self.accountAddress = accountAddress
        self.config = config
    }
}

extension BackupedAccountItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        AccountCell.self
    }

    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }

    var clipsToBounds: Bool {
        true
    }
}
