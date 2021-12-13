import UIKit
import SoraUI

final class StepView: UIView {
    @IBOutlet private(set) var stepIndexView: RoundedButton!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var spacingConstraints: NSLayoutConstraint!

    override var intrinsicContentSize: CGSize {
        let indexHeight = stepIndexView.constraints
            .first(where: { $0.firstAttribute == .height})?.constant ?? 0.0

        let height = max(indexHeight, titleLabel.intrinsicContentSize.height)

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    func bind(viewModel: StepViewModel) {
        stepIndexView.imageWithTitleView?.title = "\(viewModel.index)"
        stepIndexView.invalidateLayout()

        titleLabel.text = viewModel.title

        invalidateIntrinsicContentSize()

        setNeedsLayout()
    }
}
