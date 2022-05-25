import Foundation
import UIKit

@IBDesignable class SegmentSelectorView: UIControl {
    @IBOutlet var containerView: UIView!
    @IBOutlet weak var stackView: UIStackView!

    @IBOutlet weak var selectionView: UIView!
    var segments: [String] = [] {
        didSet {
            updateButtons()
            updateSelector()
        }
    }
    var selectedSegment: Int = 0

    @IBInspectable var selectedColor: UIColor = R.color.neumorphism.base()! {
        didSet {
            updateButtons()
            updateSelector()
        }
    }

    @IBInspectable var deselectedColor: UIColor = R.color.neumorphism.base()! {
        didSet {
            updateButtons()
            updateSelector()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initNib()
    }

    func initNib() {
        backgroundColor = .clear

        let bundle = Bundle(for: NeumorphismButton.self)
        bundle.loadNibNamed("SegmentSelectorView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }

    fileprivate func updateButtons() {
        for button in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }

        for (index, text) in segments.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
            button.setTitle(text, for: .normal)
            if index == selectedSegment {
                button.setTitleColor(selectedColor, for: .normal)
            } else {
                button.setTitleColor(deselectedColor, for: .normal)
            }
            stackView.addArrangedSubview(button)
        }
    }

    fileprivate func updateSelector(animated: Bool = false) {
        guard segments.count > 0 else { return }

        selectionView.backgroundColor = selectedColor

        let updateSelectonViewFrame = {
            let width = UIScreen.main.bounds.width / CGFloat(self.segments.count)
            self.selectionView.frame = CGRect(x: width * CGFloat(self.selectedSegment), y: 0, width: width, height: 1)
        }

        if animated {
            UIView.animate(withDuration: 0.2) {
                updateSelectonViewFrame()
            }
        } else {
            updateSelectonViewFrame()
        }
    }

    @objc func didTapButton(_ button: UIButton) {
        guard selectedSegment != button.tag else { return }

        selectedSegment = button.tag
        updateButtons()
        updateSelector(animated: true)

        sendActions(for: .valueChanged)
    }
}
