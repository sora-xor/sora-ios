import Foundation
import SoraUIKit

final class ErrorView: SoramitsuView {

    // MARK: - UI

    let titleLabel: SoramitsuLabel = {
        let emptyLabel = SoramitsuLabel()
        emptyLabel.sora.font = FontType.paragraphM
        emptyLabel.sora.textColor = .fgSecondary
        emptyLabel.sora.text = R.string.localizable.activityEmptyContentTitle(preferredLanguages: .currentLocale)
        emptyLabel.sora.alignment = .center
        emptyLabel.sora.numberOfLines = 0
        return emptyLabel
    }()

    let button: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.shadow = .small
        button.sora.cornerRadius = .circle
        button.sora.horizontalOffset = 32
        button.sora.backgroundColor = .bgSurface
        return button
    }()

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ErrorView {
    func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        clipsToBounds = false
        addSubviews(titleLabel, button)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            
            button.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}
