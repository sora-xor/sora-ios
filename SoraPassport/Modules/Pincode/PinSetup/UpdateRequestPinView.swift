import Foundation
import SoraUI
import Anchorage
import UIKit

protocol UpdateRequestPinViewDelegate: AnyObject {
    func updatePinButtonTapped()
}

extension UpdateRequestPinViewDelegate {
    func updatePinButtonTapped() {}
}

final class UpdateRequestPinView: UIView {
    
    var delegate: UpdateRequestPinViewDelegate?
    var languages: [String]?
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.pin.pinRequireUpdate()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let isSmallSizePhone = UIScreen.main.isSmallSizeScreen

        let label = UILabel()
        label.text = R.string.localizable.pinUpdateInfoTitle(preferredLanguages: languages)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.styled(for: isSmallSizePhone ? .display2 : .display1, isBold: true)
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = R.string.localizable.pinUpdateInfoDescription(preferredLanguages: languages)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.styled(for: .paragraph1)
        return label
    }()
    
    private lazy var withLabel: UILabel = {
        let label = UILabel()
        label.text = R.string.localizable.pinUpdateInfoSubtitle(preferredLanguages: languages)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.styled(for: .paragraph1, isBold: true)
        return label
    }()
    
    private lazy var button: NeumorphismButton = {
        NeumorphismButton().then {
            if let color = R.color.neumorphism.tint() {
                $0.color = color
            }
            $0.heightAnchor == 56
            $0.tintColor = R.color.brandWhite()
            $0.font = UIFont.styled(for: .button)
            $0.setTitle(R.string.localizable.pinUpdateButtonText(preferredLanguages: languages), for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(nil,
                         action: #selector(buttonTapped),
                         for: .touchUpInside)
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    @objc
    func buttonTapped() {
        delegate?.updatePinButtonTapped()
    }

    private func configure() {
        backgroundColor = R.color.neumorphism.base()

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(withLabel)
        addSubview(button)

        let isSmallSizePhone = UIScreen.main.isSmallSizeScreen
        let imageViewTopOffset: CGFloat = isSmallSizePhone ? 50 : 103
        let titleLabelTopOffset: CGFloat = isSmallSizePhone ? 40 : 71
        let descriptionLabelTopOffset: CGFloat = isSmallSizePhone ? 20 : 41
        let withLabelTopOffset: CGFloat = isSmallSizePhone ? 10 : 21
        let buttonBottomOffset: CGFloat = isSmallSizePhone ? 20 : 40

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 215),
            imageView.heightAnchor.constraint(equalToConstant: 175),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: imageViewTopOffset),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: titleLabelTopOffset),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 38),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: descriptionLabelTopOffset),
            descriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),

            withLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: withLabelTopOffset),
            withLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            withLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 38),

            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -buttonBottomOffset),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        ])
    }
}
