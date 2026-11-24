import UIKit

open class SoramitsuTableViewCell: UITableViewCell, Atom {

	public let sora: SoramitsuTableViewCellConfiguration<SoramitsuTableViewCell>

	public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		sora = SoramitsuTableViewCellConfiguration(style: SoramitsuUI.shared.style)
		super.init(style: style, reuseIdentifier: reuseIdentifier)
        sora.owner = self
	}

	public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Rows keep to the readable width: in a table wider than that (an unfolded inner screen) a row
    /// stands in from both sides instead of stretching across. A row that paints edge to edge, like
    /// the portfolio's sky, returns true and keeps its own content readable. No iPhone window before
    /// foldables is wider than the readable width, so nothing moves there.
    open var spansFullWidth: Bool { false }

    /// The frame a row takes when the table offers it `proposed`.
    public func readableFrame(for proposed: CGRect) -> CGRect {
        guard !spansFullWidth else { return proposed }
        let inset = LayoutCanvas.readableInset(forWidth: proposed.width)
        guard inset > 0 else { return proposed }
        return proposed.insetBy(dx: inset, dy: 0)
    }

    open override var frame: CGRect {
        get { super.frame }
        set { super.frame = readableFrame(for: newValue) }
    }

    /// A self-sizing row is measured at the width it will be drawn at, not the table's.
    open override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                               withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                               verticalFittingPriority: UILayoutPriority) -> CGSize {
        let inset = spansFullWidth ? 0 : LayoutCanvas.readableInset(forWidth: targetSize.width)
        guard inset > 0 else {
            return super.systemLayoutSizeFitting(targetSize,
                                                 withHorizontalFittingPriority: horizontalFittingPriority,
                                                 verticalFittingPriority: verticalFittingPriority)
        }
        let narrowed = CGSize(width: targetSize.width - inset * 2, height: targetSize.height)
        var size = super.systemLayoutSizeFitting(narrowed,
                                                 withHorizontalFittingPriority: horizontalFittingPriority,
                                                 verticalFittingPriority: verticalFittingPriority)
        size.width = targetSize.width
        return size
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard let tableView = superview as? SoramitsuTableView,
              let indexPath = tableView.indexPath(for: self),
              let section = tableView.sora.sections[safe: indexPath.section],
              let item = section.rows[safe: indexPath.row],
              let actions = item.menuActions,
              actions.map({ action -> Selector in action.selector }).contains(action) else {
            return super.canPerformAction(action, withSender: sender)
        }

        return true
	}

	open override func forwardingTarget(for aSelector: Selector!) -> Any? {
		guard let tableView = superview as? SoramitsuTableView,
			let indexPath = tableView.indexPath(for: self) else {
				assertionFailure("Something went wrong, check logic")
				return nil
		}
		return tableView.sora.sections[indexPath.section].rows[indexPath.row]
	}
}
