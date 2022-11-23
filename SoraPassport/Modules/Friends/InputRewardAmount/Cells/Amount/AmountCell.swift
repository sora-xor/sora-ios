import UIKit
import Then
import Anchorage

protocol AmountCellDelegate: AnyObject {
    func isMinusEnabled(_ currentInvitationCount: Decimal) -> Bool
    func isPlusEnabled(_ currentInvitationCount: Decimal) -> Bool
    func userChanged(_ currentInvitationCount: Decimal)
}

final class AmountCell: UITableViewCell {

    private var delegate: AmountCellDelegate?
    private var fee: Decimal = Decimal(0)

    private var currentInvitationCount: Decimal = Decimal(0) {
        didSet {
            amountView.textField.text =  "\(currentInvitationCount)"
            amountView.underMinusLabel.text =  "\(currentInvitationCount * fee) XOR"
            delegate?.userChanged(currentInvitationCount)
        }
    }

    // MARK: - Outlets
    private var amountView = AmountView()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @objc
    func plusTapped() {
        guard delegate?.isPlusEnabled(currentInvitationCount) == true else { return }
        currentInvitationCount += 1
    }

    @objc
    func minusTapped() {
        guard delegate?.isMinusEnabled(currentInvitationCount) == true else { return }
        currentInvitationCount -= 1
    }

    @objc
    func textFieldChanged() {
        let text = amountView.textField.text ?? "0"
        currentInvitationCount = Decimal(string: text) ?? Decimal(0)
    }

}

extension AmountCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let model = viewModel as? AmountViewModelProtocol else { return }
        amountView.textField.becomeFirstResponder()

        let balanceText = R.string.localizable.commonBalance(preferredLanguages: .currentLocale) + ": \(model.currentBalance)"
        amountView.underPlusLabel.text = balanceText
        amountView.underMinusLabel.text = "\(model.bondedAmount) XOR"

        let invitationNumber = (model.bondedAmount / model.fee).rounded(mode: .down)

        if invitationNumber > 0 {
            amountView.textField.text =  "\(invitationNumber)"
        }

        self.fee = model.fee
        self.currentInvitationCount = invitationNumber
        self.delegate = model.delegate
    }
}

private extension AmountCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(amountView)

        amountView.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 16
            $0.heightAnchor == 80
            $0.bottomAnchor == contentView.bottomAnchor - 10
        }

        amountView.plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        amountView.minusButton.addTarget(self, action: #selector(minusTapped), for: .touchUpInside)
        amountView.textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }
}
