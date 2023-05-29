import SoraUIKit

class SwitcherButtonViewModel {
    let title: String
    var isSelected: Bool
    var actionBlock: (() -> Void)?
    
    init(title: String, isSelected: Bool, actionBlock: (() -> Void)? = nil) {
        self.title = title
        self.isSelected = isSelected
        self.actionBlock = actionBlock
    }
}

struct SwitcherViewModel {
    let buttonViewModels: [SwitcherButtonViewModel]
}

final class SwitcherView: SoramitsuView {

    var viewModel: SwitcherViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            
            mainStackView.arrangedSubviews.forEach { subview in
                mainStackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

            let butttonViews = viewModel.buttonViewModels.map { buttonViewModel -> SoramitsuButton in
                let title = SoramitsuTextItem(text:  buttonViewModel.title,
                                              fontData: FontType.textBoldS,
                                              textColor: buttonViewModel.isSelected ? .bgSurface : .accentSecondary,
                                              alignment: .center)
                let button = SoramitsuButton()
                button.sora.attributedText = title
                button.sora.cornerRadius = .circle
                button.sora.backgroundColor = buttonViewModel.isSelected ? .accentSecondary : .bgSurfaceVariant
                button.sora.horizontalOffset = 12
                button.sora.addHandler(for: .touchUpInside) {
                    buttonViewModel.actionBlock?()
                }
                return button
            }

            mainStackView.addArrangedSubviews(butttonViews)
        }
    }
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .horizontal
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 8
        return mainStackView
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        translatesAutoresizingMaskIntoConstraints = false
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubview(mainStackView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStackView.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}
