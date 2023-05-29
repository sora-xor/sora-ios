import SoraUIKit
import Anchorage

enum FrozenDetailType: Int, CaseIterable {
    case frozen = 0
    case locked
    case bonded
    case reserved
    case redeemable
    case unbonding
    
    var title: String {
        switch self {
        case .frozen: return R.string.localizable.detailsFrozen(preferredLanguages: .currentLocale)
        case .locked: return R.string.localizable.walletBalanceLocked(preferredLanguages: .currentLocale)
        case .bonded: return R.string.localizable.walletBonded(preferredLanguages: .currentLocale)
        case .reserved: return R.string.localizable.walletBalanceReserved(preferredLanguages: .currentLocale)
        case .redeemable: return R.string.localizable.walletRedeemable(preferredLanguages: .currentLocale)
        case .unbonding: return R.string.localizable.walletUnbonding(preferredLanguages: .currentLocale)
        }
    }
}

enum BalanceDetailType {
    case header
    case body
    
    var titleColor: SoramitsuColor {
        return self == .header ? .fgPrimary : .fgSecondary
    }
    
    var titleFont: FontData {
        return self == .header ? FontType.headline2 : FontType.textBoldXS
    }
    
    var amountFont: FontData {
        return self == .header ? FontType.headline2 : FontType.textM
    }
    
    var fiatAmountFont: FontData {
        return self == .header ? FontType.headline3 : FontType.textBoldXS
    }
}

struct BalanceDetailViewModel {
    let title: SoramitsuTextItem
    let amount: SoramitsuTextItem
    let fiatAmount: SoramitsuTextItem
}

final class BalanceDetailView: SoramitsuView {
    
    var viewModel: BalanceDetailViewModel? {
        didSet {
            titleLabel.sora.attributedText = viewModel?.title
            amountLabel.sora.attributedText = viewModel?.amount
            fiatAmountLabel.sora.attributedText = viewModel?.fiatAmount
        }
    }

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.sora.alignment  = .left
        return label
    }()
    
    let amountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.sora.alignment = .right
        return label
    }()
    
    let fiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false

        addSubviews(titleLabel, amountLabel, fiatAmountLabel)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor),
            
            amountLabel.topAnchor.constraint(equalTo: topAnchor),
            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            
            fiatAmountLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 4),
            fiatAmountLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            fiatAmountLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            fiatAmountLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
        ])
    }
}
