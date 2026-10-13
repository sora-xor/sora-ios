import UIKit

public final class SoramitsuTableViewSpaceView: SoramitsuView {

	private var spaceCellBackgroundView: SoramitsuView

    public override func layoutSubviews() {
		super.layoutSubviews()
		accessibilityElementsHidden = true
		backgroundColor = .clear
	}

	override init(frame: CGRect) {
		spaceCellBackgroundView = SoramitsuView(style: SoramitsuUI.shared.style)
		super.init(frame: frame)
		addSubview(spaceCellBackgroundView)
		spaceCellBackgroundView.pinToSuperView()
	}
}

extension SoramitsuTableViewSpaceView: SoramitsuTableViewCellProtocol {
    public func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
		guard let item = item as? SoramitsuTableViewSpacerItem else { return }
		spaceCellBackgroundView.sora.backgroundColor = item.backgroundColor
        spaceCellBackgroundView.sora.cornerRadius = item.radius
        spaceCellBackgroundView.sora.cornerMask = item.mask
	}
}
