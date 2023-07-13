import UIKit
import SoraUIKit
import SnapKit

protocol InvitationsCellDelegate: AnyObject {
    func isMinusEnabled(_ currentInvitationCount: Decimal) -> Bool
    func isPlusEnabled(_ currentInvitationCount: Decimal) -> Bool
    func userChanged(_ currentInvitationCount: Decimal)
    func buttonTapped()
}

final class InvitationsCell: SoramitsuTableViewCell {
    
    private enum Constants {
        static let smallSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
    }
    
    private weak var delegate: InvitationsCellDelegate?
    
    private var fee: Decimal = Decimal(0)
    private var currentInvitationCount: Decimal = Decimal(0) {
        didSet {
            amountView.textField.sora.text =  "\(currentInvitationCount)"
            amountView.underMinusLabel.sora.text =  "\(currentInvitationCount * fee) XOR"
            delegate?.userChanged(currentInvitationCount)
        }
    }
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .left
        label.sora.numberOfLines = 0
        return label
    }()
    
    private lazy var descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .left
        label.sora.numberOfLines = 0
        return label
    }()
    
    private lazy var amountView: AmountView = {
        let view = AmountView()
        return view
    }()
    
    private lazy var feeView: FeeView = {
        let view = FeeView()
        return view
    }()
    
    private lazy var button: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.buttonTapped()
        }
        return button
    }()
    
    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.sora.backgroundColor = .bgSurface
        stackView.sora.cornerRadius = .max
        stackView.sora.cornerMask = .all
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
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
        sora.selectionStyle = .none
        sora.backgroundColor = .custom(uiColor: .clear)
        configure()
    }
    
    private func setupHierarchy() {
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubviews([
            titleLabel,
            descriptionLabel,
            amountView,
            feeView,
            button
        ])
    }
    
    private func setupLayout() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        
        stackView.setCustomSpacing(Constants.smallSpacing, after: titleLabel)
        stackView.setCustomSpacing(Constants.largeSpacing, after: descriptionLabel)
        stackView.setCustomSpacing(Constants.smallSpacing, after: amountView)
        stackView.setCustomSpacing(Constants.largeSpacing, after: feeView)
    }
    
    private func configure() {
        amountView.minusButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.minusTapped()
        }
        
        amountView.plusButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.plusTapped()
        }
        
        amountView.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.textFieldChanged()
        }
    }
    
    private func buttonTapped() {
        delegate?.buttonTapped()
    }
    
    private func plusTapped() {
        guard delegate?.isPlusEnabled(currentInvitationCount) == true else { return }
        currentInvitationCount += 1
    }

    private func minusTapped() {
        guard delegate?.isMinusEnabled(currentInvitationCount) == true else { return }
        currentInvitationCount -= 1
    }

    private func textFieldChanged() {
        let text = amountView.textField.sora.text ?? "0"
        currentInvitationCount = Decimal(string: text) ?? Decimal(0)
    }
}

extension InvitationsCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? InvitationsViewModel else { return }
        titleLabel.sora.text = viewModel.title
        descriptionLabel.sora.text = viewModel.description
        feeView.feeLabel.sora.text = "\(viewModel.fee) \(viewModel.feeSymbol)"
        button.sora.title = viewModel.buttonTitle
        button.sora.isEnabled = viewModel.isEnabled
        
        amountView.textField.becomeFirstResponder()
        amountView.underMinusLabel.sora.text = "\(viewModel.bondedAmount) \(viewModel.feeSymbol)"
        amountView.underPlusLabel.sora.text = R.string.localizable.commonBalance(preferredLanguages: .currentLocale) + ":\(viewModel.balance)"
        
        let invitationCount = (viewModel.bondedAmount / viewModel.fee).rounded(mode: .down)
        
        if invitationCount > 0 {
            amountView.textField.sora.text = "\(invitationCount)"
        }
        
        self.currentInvitationCount = invitationCount
        self.fee = viewModel.fee
        self.delegate = viewModel.delegate
    }
}
