import Foundation
import SoraUIKit
import UIKit

final class OptionsView: SoramitsuView {

    let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.clipsToBounds = false
        view.spacing = 4
        return view
    }()
    
    public let slipageTitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        label.sora.text = R.string.localizable.slippage(preferredLanguages: .currentLocale)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    public lazy var slipageButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .bleached(.secondary))
        button.sora.horizontalOffset = 12
        button.sora.cornerRadius = .circle
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
        }
        return button
    }()
    
    public let marketLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isHidden = true
        label.sora.alignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.sora.text = R.string.localizable.polkaswapMarket(preferredLanguages: .currentLocale)
        return label
    }()
    
    public lazy var marketButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .bleached(.secondary))
        button.sora.horizontalOffset = 12
        button.sora.title = "Smart"
        button.sora.cornerRadius = .circle
        button.sora.isHidden = true
        button.clipsToBounds = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
        }
        return button
    }()
    
    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        stackView.addArrangedSubviews(marketLabel, marketButton)
        stackView.setCustomSpacing(16, after: marketButton)
        stackView.addArrangedSubviews(slipageTitleLabel, slipageButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
