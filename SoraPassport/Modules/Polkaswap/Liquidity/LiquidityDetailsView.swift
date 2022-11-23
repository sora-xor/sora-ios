import SoraFoundation
import Foundation
import UIKit
import Anchorage

protocol LiquidityDetailsViewDelegate {
    func didTapSbApy()
    func didTapFee()
}

final class LiquidityDetailsView: UIView & Localizable {

    var viewModel: PoolDetailsViewModel!
    var languages: [String]?
    var formatter: NumberFormatter?
    var percentageFormatter: NumberFormatter?
    var delegate: LiquidityDetailsViewDelegate?

    let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    init(viewModel: PoolDetailsViewModel, languages: [String]?, formatter: NumberFormatter, percentageFormatter: NumberFormatter) {
        self.viewModel = viewModel
        self.languages = languages
        self.formatter = formatter
        self.percentageFormatter = percentageFormatter
        super.init(frame: .zero)
        setupView()
    }

    private func setupView() {
        addStack()
        addYourPositionTitle()
        addFirstAsset()
        addSecondAsset()
        addShareOfPool()
        addPricesAndFeeTitle()
        addDirectExchangeRate()
        addInverseExchangeRate()
        addSbApyIfNecessary()
        addFeeIfNecessary()
    }

    private func addStack() {
        stack.axis = .vertical
        addSubview(stack)
        stack.edgeAnchors == edgeAnchors
    }

    private func addYourPositionTitle() {
        let text = R.string.localizable.polkaswapYourPosition(preferredLanguages: languages).uppercased()
        let titleView = title(text: text)
        stack.addArrangedSubview(titleView)
    }

    private func addFirstAsset() {
        let left = left(text: viewModel?.firstAsset.symbol)
        let right = right(text: formatter?.stringFromDecimal(viewModel.firstAssetValue) ?? "")
        let separator = separator()
        let container = container(left: left, right: right, separator: separator)
        stack.addArrangedSubview(container)
    }

    private func addSecondAsset() {
        let left = left(text: viewModel?.secondAsset.symbol)
        let right = right(text: formatter?.stringFromDecimal(viewModel.secondAssetValue) ?? "")
        let separator = separator()
        let container = container(left: left, right: right, separator: separator)
        stack.addArrangedSubview(container)
    }

    private func addShareOfPool() {
        let left = left(text: R.string.localizable.poolShareTitle(preferredLanguages: languages).uppercased())
        let right = right(text: percentageFormatter?.stringFromDecimal(viewModel.shareOfPoolValue) ?? "")
        let separator = separator()
        let container = container(left: left, right: right, separator: separator)
        stack.addArrangedSubview(container)
    }

    private func addPricesAndFeeTitle() {
        let text = R.string.localizable.polkaswapInfoPricesAndFees(preferredLanguages: languages).uppercased()
        let titleView = title(text: text)
        stack.addArrangedSubview(titleView)
    }

    private func addDirectExchangeRate() {
        let left = left(text: viewModel.directExchangeRateTitle)
        let right = right(text: formatter?.stringFromDecimal(viewModel.directExchangeRateValue) ?? "")
        let separator = separator()
        let container = container(left: left, right: right, separator: separator)
        stack.addArrangedSubview(container)
    }

    private func addInverseExchangeRate() {
        let left = left(text: viewModel.inversedExchangeRateTitle)
        let right = right(text: formatter?.stringFromDecimal(viewModel.inversedExchangeRateValue) ?? "")
        let separator = separator()
        let container = container(left: left, right: right, separator: separator)
        stack.addArrangedSubview(container)
    }

    private func addSbApyIfNecessary() {
        guard viewModel.sbApyValue > 0 else { return }

        let left = left(text: R.string.localizable.polkaswapSbapy(preferredLanguages: languages))
        let right = right(text: percentageFormatter?.stringFromDecimal(viewModel.sbApyValue) ?? "")
        let separator = separator()
        let button = UIButton()
        button.addTarget(self, action: #selector(didTapSbApy), for: .touchUpInside)
        let container = infoContainer(left: left, right: right, separator: separator, button: button)
        stack.addArrangedSubview(container)
    }

    private func addFeeIfNecessary() {
        guard viewModel.networkFeeValue > 0,
              let networkFee = formatter?.stringFromDecimal(viewModel.networkFeeValue) else {
            return
        }

        let left = left(text: R.string.localizable.polkaswapNetworkFee(preferredLanguages: languages).uppercased())
        let right = right(text: "\(networkFee) XOR")
        let separator = separator()
        let button = UIButton()
        button.addTarget(self, action: #selector(didTapFee), for: .touchUpInside)
        let container = infoContainer(left: left, right: right, separator: separator, button: button)
        stack.addArrangedSubview(container)
    }

    @objc private func didTapFee() {
        delegate?.didTapFee()
    }

    @objc private func didTapSbApy() {
        delegate?.didTapSbApy()
    }

    //MARK: - UI

    private func container(left: UILabel, right: UILabel, separator: UIView) -> UIView {
        let container = UIView()
        container.addSubview(left)
        container.addSubview(right)
        container.addSubview(separator)

        left.leadingAnchor == container.leadingAnchor + 24
        left.topAnchor == container.topAnchor + 14
        left.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        right.trailingAnchor == container.trailingAnchor - 24
        right.topAnchor == left.topAnchor
        right.bottomAnchor == left.bottomAnchor
        right.setContentHuggingPriority(.defaultLow, for: .horizontal)

        left.trailingAnchor == right.leadingAnchor - 8

        separator.leadingAnchor == container.leadingAnchor + 24
        separator.trailingAnchor == container.trailingAnchor - 24
        separator.topAnchor == right.bottomAnchor + 6
        separator.bottomAnchor == container.bottomAnchor

        return container
    }

    private func infoContainer(left: UILabel, right: UILabel, separator: UIView, button: UIButton) -> UIView {
        let container = UIView()
        container.addSubview(left)
        container.addSubview(right)
        container.addSubview(separator)
        container.addSubview(button)
        let info = info()
        container.addSubview(info)

        left.leadingAnchor == container.leadingAnchor + 24
        left.topAnchor == container.topAnchor + 14
        left.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        info.centerYAnchor == left.centerYAnchor
        left.trailingAnchor >= info.leadingAnchor - 8
        info.trailingAnchor == right.leadingAnchor - 8

        right.trailingAnchor == container.trailingAnchor - 24
        right.topAnchor == left.topAnchor
        right.bottomAnchor == left.bottomAnchor
        right.setContentHuggingPriority(.defaultLow, for: .horizontal)

        separator.leadingAnchor == container.leadingAnchor + 24
        separator.trailingAnchor == container.trailingAnchor - 24
        separator.topAnchor == right.bottomAnchor + 6
        separator.bottomAnchor == container.bottomAnchor

        button.edgeAnchors == container.edgeAnchors

        return container
    }

    private func info() -> UIImageView {
        let imageView = UIImageView(image: R.image.iconWalletInfo()!)
        imageView.widthAnchor == 14
        imageView.heightAnchor == 14
        return imageView
    }

    private func left(text: String?) -> UILabel {
        let label = UILabel(frame: .zero)
        label.text = text
        label.textColor = R.color.neumorphism.text()!
        label.font = UIFont.styled(for: .paragraph1)
        label.textAlignment = .left
        return label
    }

    private func right(text: String?) -> UILabel {
        let label = UILabel(frame: .zero)
        label.text = text
        label.textColor = R.color.neumorphism.text()!
        label.font = UIFont.styled(for: .paragraph1)
        label.textAlignment = .right
        return label
    }

    private func titleLabel(text: String) -> UILabel {
        let label = UILabel(frame: .zero)
        label.text = text
        label.textColor = R.color.neumorphism.text()!
        label.font = UIFont.styled(for: .paragraph1, isBold: true)
        label.textAlignment = .left
        return label
    }

    private func title(text: String) -> UIView {
        let label = titleLabel(text: text)
        let titleView = UIView()
        titleView.addSubview(label)
        label.leadingAnchor == titleView.leadingAnchor + 24
        label.trailingAnchor == titleView.trailingAnchor - 24
        label.topAnchor == titleView.topAnchor + 16
        label.bottomAnchor == titleView.bottomAnchor - 6
        return titleView
    }

    private func separator() -> UIView {
        let separator = UIView(frame: .zero)
        separator.backgroundColor = R.color.neumorphism.separator()!
        separator.heightAnchor == 1
        return separator
    }
}
