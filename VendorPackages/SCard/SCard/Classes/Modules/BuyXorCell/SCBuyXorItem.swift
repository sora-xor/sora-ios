import SoraUIKit

public final class SCBuyXorItem: NSObject {

    var onClose: (() -> Void)?
    var onTap: (() -> Void)?

    public init(
        onClose: (() -> Void)?,
        onTap: (() -> Void)?
    ) {
        self.onClose = onClose
        self.onTap = onTap
        super.init()
    }
}

extension SCBuyXorItem: SoramitsuTableViewItemProtocol {
    public var cellType: AnyClass { SCBuyXorCell.self }
    public var clipsToBounds: Bool { false }
}
