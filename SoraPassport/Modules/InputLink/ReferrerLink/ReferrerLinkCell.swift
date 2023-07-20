import UIKit
import SoraUIKit
import SoraFoundation
import SnapKit
import Combine

final class ReferrerLinkCell: SoramitsuTableViewCell {
    
    private var cancellables: Set<AnyCancellable> = []
    private weak var viewModel: ReferrerLinkViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            viewModel.$isEnabled
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.activateButton.sora.isEnabled = viewModel.isEnabled ?? false
                }
                .store(in: &cancellables)
        }
    }
    
    private lazy var containerView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.axis = .vertical
            $0.sora.distribution = .fill
            $0.sora.cornerRadius = .max
            $0.spacing = 24
            $0.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            $0.isLayoutMarginsRelativeArrangement = true
        }
    }()

    private lazy var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.paragraphM
            $0.sora.numberOfLines = 0
            $0.setContentHuggingPriority(.required, for: .vertical)
        }
    }()

    private lazy var linkView: ReferrerLinkView = {
        let view = ReferrerLinkView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.textFieldDidChange()
        }
        return view
    }()

    private lazy var activateButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.backgroundColor = .accentPrimary
            $0.sora.cornerRadius = .max
            $0.sora.isEnabled = false
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.activeLinkTapped()
            }
        }
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupCell() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        applyLocalization()
    }
    
    private func setupHierarchy() {
        contentView.addSubview(containerView)
        
        containerView.addArrangedSubviews([
            descriptionLabel,
            linkView,
            activateButton
        ])
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        linkView.textField.becomeFirstResponder()
    }
    
    private func textFieldDidChange() {
        guard let viewModel = viewModel else { return }
        viewModel.userChangeTextField(with: linkView.textField.sora.text ?? "")
    }

    private func activeLinkTapped() {
        guard let viewModel = viewModel else { return }
        viewModel.userTappedOnActivate()
    }
}

extension ReferrerLinkCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ReferrerLinkViewModel else { return }
        activateButton.sora.isEnabled = viewModel.isEnabled ?? false
        linkView.textField.sora.text = viewModel.address
        self.viewModel = viewModel
    }
}

extension ReferrerLinkCell: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        descriptionLabel.sora.text = R.string.localizable.referralReferrerDescription(preferredLanguages: languages)
        activateButton.sora.title = R.string.localizable.referralActivateButtonTitle(preferredLanguages: languages)
    }
}
