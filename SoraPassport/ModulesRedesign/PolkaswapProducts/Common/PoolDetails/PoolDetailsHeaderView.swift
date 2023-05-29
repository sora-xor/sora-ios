import Foundation
import SoraUIKit
import UIKit

final class PoolDetailsHeaderView: SoramitsuControl {

    public let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let firstCurrencyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    public let secondCurrencyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    public let rewardViewContainter: SoramitsuView = {
        let view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgPage
        view.sora.cornerRadius = .circle
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let rewardImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.cornerRadius = .circle
        view.sora.borderColor = .bgPage
        view.sora.isUserInteractionEnabled = false
        view.sora.backgroundColor = .additionalPolkaswap
        return view
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
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
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addSubviews(currenciesView, titleLabel)
        
        currenciesView.addSubview(firstCurrencyImageView)
        rewardViewContainter.addSubviews(rewardImageView)
        
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(rewardViewContainter)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            currenciesView.leadingAnchor.constraint(equalTo: leadingAnchor),
            currenciesView.topAnchor.constraint(equalTo: topAnchor),
            currenciesView.centerYAnchor.constraint(equalTo: centerYAnchor),
            currenciesView.heightAnchor.constraint(equalToConstant: 40),
            currenciesView.widthAnchor.constraint(equalToConstant: 64),
            
            titleLabel.leadingAnchor.constraint(equalTo: currenciesView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            firstCurrencyImageView.heightAnchor.constraint(equalToConstant: 40),
            firstCurrencyImageView.widthAnchor.constraint(equalToConstant: 40),
            
            secondCurrencyImageView.leadingAnchor.constraint(equalTo: firstCurrencyImageView.leadingAnchor, constant: 24),
            secondCurrencyImageView.heightAnchor.constraint(equalToConstant: 40),
            secondCurrencyImageView.widthAnchor.constraint(equalToConstant: 40),
            
            rewardImageView.trailingAnchor.constraint(equalTo: secondCurrencyImageView.trailingAnchor),
            rewardImageView.bottomAnchor.constraint(equalTo: secondCurrencyImageView.bottomAnchor),
            rewardImageView.heightAnchor.constraint(equalToConstant: 18),
            rewardImageView.widthAnchor.constraint(equalToConstant: 18),

            rewardViewContainter.centerXAnchor.constraint(equalTo: rewardImageView.centerXAnchor),
            rewardViewContainter.centerYAnchor.constraint(equalTo: rewardImageView.centerYAnchor),
            rewardViewContainter.heightAnchor.constraint(equalToConstant: 22),
            rewardViewContainter.widthAnchor.constraint(equalToConstant: 22)
        ])
    }
}
