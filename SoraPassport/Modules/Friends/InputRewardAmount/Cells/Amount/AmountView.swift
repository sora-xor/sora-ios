import UIKit
import Anchorage

final class AmountView: UIView {

    let plusButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.setImage(R.image.roundPlus(), for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    let minusButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.setImage(R.image.roundMinus(), for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    let textField: UITextField = {
        UITextField().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.neumorphism.textDark()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.placeholder = "0"
            $0.tintColor = R.color.neumorphism.textDark()
            $0.keyboardType = .numberPad
        }
    }()

    let underMinusLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph4)
            $0.textColor = R.color.neumorphism.borderBase()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textAlignment = .left
        }
    }()

    let underPlusLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph4)
            $0.textColor = R.color.neumorphism.borderBase()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textAlignment = .right
        }
    }()

    private lazy var gradient: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.type = .radial
        gradient.colors = [
            R.color.neumorphism.shadowLightGray()!.cgColor,
            R.color.neumorphism.shadowSuperLightGray()!.cgColor
        ]
        gradient.cornerRadius = 24
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.locations = [ 0.5, 1 ]
        return gradient
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let endX = 1 + bounds.size.height / bounds.size.width
        gradient.endPoint = CGPoint(x: endX, y: 1)
        gradient.frame = bounds
    }
}

private extension AmountView {
    func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = R.color.neumorphism.buttonLightGrey()
        layer.cornerRadius = 24

        layer.addSublayer(gradient)
        addSubview(plusButton)
        addSubview(minusButton)
        addSubview(textField)
        addSubview(underPlusLabel)
        addSubview(underMinusLabel)

        plusButton.do {
            $0.trailingAnchor == trailingAnchor - 16
            $0.heightAnchor == 24
            $0.widthAnchor == 24
            $0.topAnchor == topAnchor + 16
        }

        minusButton.do {
            $0.leadingAnchor == leadingAnchor + 16
            $0.heightAnchor == 24
            $0.widthAnchor == 24
            $0.topAnchor == topAnchor + 16
        }

        textField.do {
            $0.centerXAnchor == centerXAnchor
            $0.centerYAnchor == plusButton.centerYAnchor
            $0.heightAnchor == 24
        }

        underMinusLabel.do {
            $0.leadingAnchor == leadingAnchor + 24
            $0.bottomAnchor == bottomAnchor - 16
            $0.trailingAnchor == underPlusLabel.leadingAnchor - 10
        }

        underPlusLabel.do {
            $0.trailingAnchor == trailingAnchor - 24
            $0.bottomAnchor == bottomAnchor - 16
        }
    }
}
