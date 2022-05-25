import UIKit

struct PolkaswapAmountAccessoryViewModel {
    let doneButtonText: String
    let selectionButtons: [String]
}

protocol PolkaswapAmountAccessoryViewDelegate: AnyObject {
    func donePressed()
    func predefinedPressed(atIndex: Int)
}

class PolkaswapAmountAccessoryView: UIView {
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var stack: UIStackView!

    weak var delegate: PolkaswapAmountAccessoryViewDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        configure()
    }

    private func configure() {
        backgroundColor = R.color.neumorphism.base()
        separator.backgroundColor = R.color.neumorphism.separator()
        doneButton?.setTitleColor(R.color.brandPolkaswapPink(), for: .normal)
        doneButton?.addTarget(self, action: #selector(donePressed), for: .touchUpInside)
    }

    func setViewModel(_ viewModel: PolkaswapAmountAccessoryViewModel) {
        doneButton?.setTitle(viewModel.doneButtonText, for: .normal)

        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        for (index, buttonTitle) in viewModel.selectionButtons.enumerated() {
            let button = UIButton()
            button.tag = index
            button.setTitleColor(R.color.brandPolkaswapPink(), for: .normal)
            button.setTitle(buttonTitle, for: .normal)
            button.addTarget(self, action: #selector(predefinedButtonPressed(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    @objc func donePressed() {
        delegate?.donePressed()
    }

    @objc func predefinedButtonPressed(_ button: UIButton) {
        delegate?.predefinedPressed(atIndex: button.tag)
    }
}
