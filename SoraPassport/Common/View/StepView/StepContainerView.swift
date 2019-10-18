import UIKit

@IBDesignable
final class StepContainerView: UIView {
    private var views: [StepView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    var verticalSpacing: CGFloat = 12.0 {
        didSet {
            if views.count > 1 {
                for view in views[1..<views.count] {
                    let constaint = view.constraints.first(where: { $0.firstAttribute == .top})
                    constaint?.constant = verticalSpacing
                }

                invalidateIntrinsicContentSize()
                setNeedsLayout()
            }
        }
    }

    var horizontalSpacing: CGFloat = 13.0 {
        didSet {
            views.forEach { $0.spacingConstraints.constant = horizontalSpacing }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var stepIndexFillColor: UIColor = UIColor.gray {
        didSet {
            views.forEach { $0.stepIndexView.roundedBackgroundView?.fillColor = stepIndexFillColor }
        }
    }

    var stepIndexTitleColor: UIColor = UIColor.white {
        didSet {
            views.forEach { $0.stepIndexView.imageWithTitleView?.titleColor = stepIndexTitleColor }
        }
    }

    var stepIndexFont: UIFont = UIFont.systemFont(ofSize: 10.0) {
        didSet {
            views.forEach { $0.stepIndexView.imageWithTitleView?.titleFont = stepIndexFont }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var stepTitleColor: UIColor = UIColor.black {
        didSet {
            views.forEach { $0.titleLabel.textColor = stepTitleColor }
        }
    }

    var stepTitleFont: UIFont = UIFont.systemFont(ofSize: 13.0) {
        didSet {
            views.forEach { $0.titleLabel.font = stepTitleFont }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var stepIndexTitleInsets: UIEdgeInsets = UIEdgeInsets.zero {
        didSet {
            views.forEach { $0.stepIndexView.contentInsets = stepIndexTitleInsets}
        }
    }

    override var intrinsicContentSize: CGSize {
        var totalHeight = views.reduce(CGFloat(0.0)) { (result, view) in
            return result + view.intrinsicContentSize.height
        }

        totalHeight += CGFloat(views.count - 1) * verticalSpacing

        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()

        views.forEach { $0.invalidateIntrinsicContentSize() }
    }

    private func configure() {
        backgroundColor = UIColor.clear
    }

    func bind(viewModels: [StepViewModel]) {
        if views.count > viewModels.count {
            removeViews(count: views.count - viewModels.count)
        } else if views.count < viewModels.count {
            addViews(count: viewModels.count - views.count)
        }

        for (index, viewModel) in viewModels.enumerated() {
            views[index].bind(viewModel: viewModel)
        }

        invalidateIntrinsicContentSize()

        setNeedsLayout()
    }

    private func removeViews(count: Int) {
        (0..<count).forEach { _ in
            let view = views.removeLast()
            view.removeFromSuperview()
        }
    }

    private func addViews(count: Int) {
        for _ in 0..<count {
            guard let view = createNewView() else {
                return
            }

            view.translatesAutoresizingMaskIntoConstraints = false

            addSubview(view)

            view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            view.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

            if let lastView = views.last {
                view.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: verticalSpacing).isActive = true
            } else {
                view.topAnchor.constraint(equalTo: topAnchor).isActive = true
            }

            applyStyle(to: view)

            views.append(view)
        }
    }

    private func applyStyle(to view: StepView) {
        view.spacingConstraints.constant = horizontalSpacing
        view.stepIndexView.contentInsets = stepIndexTitleInsets
        view.stepIndexView.roundedBackgroundView?.fillColor = stepIndexFillColor
        view.stepIndexView.imageWithTitleView?.titleColor = stepIndexTitleColor
        view.stepIndexView.imageWithTitleView?.titleFont = stepIndexFont
        view.titleLabel.textColor = stepTitleColor
        view.titleLabel.font = stepTitleFont
    }

    private func createNewView() -> StepView? {
        return UINib(nibName: "StepView", bundle: Bundle(for: type(of: self)))
            .instantiate(withOwner: nil, options: nil).first as? StepView
    }
}
