import Foundation
import UIKit
import SoraUIKit

protocol LiquidityViewProtocol: ControllerBackedProtocol, Warningable {
    func update(details: [DetailViewModel])
    func updateFirstAsset(balance: String)
    func updateSecondAsset(balance: String)
    func updateFirstAsset(symbol: String, image: UIImage?)
    func updateSecondAsset(symbol: String, image: UIImage?)
    func updateFirstAsset(fiatText: String)
    func updateSecondAsset(fiatText: String)
    func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor)
    func updateSecondAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor)
    func update(slippageTolerance: String)
    func update(selectedMarket: String)
    func updateMiddleButton(isEnabled: Bool)
    func set(firstAmountText: String)
    func set(secondAmountText: String)
    func setupButton(isEnabled: Bool)
    func setAccessoryView(isHidden: Bool)
    func setupMarketButton(isLoadingState: Bool)
    func focus(field: FocusedField)
    func update(isNeedLoadingState: Bool)
    func updateReviewButton(title: String)
}

final class PolkaswapViewController: SoramitsuViewController {
    
    private var spaceConstraint: NSLayoutConstraint?
    
    private lazy var accessoryView: InputAccessoryView = {
        let rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 48))
        let view = InputAccessoryView(frame: rect)
        view.delegate = viewModel
        view.variants = [ InputAccessoryVariant(displayValue: "25%", value: 0.25),
                          InputAccessoryVariant(displayValue: "50%", value: 0.5),
                          InputAccessoryVariant(displayValue: "75%", value: 0.75),
                          InputAccessoryVariant(displayValue: "100%", value: 1) ]
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .center
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    private lazy var scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        return scrollView
    }()
    
    private lazy var assetsView: InputAssetsView = {
        let view = InputAssetsView()
        view.middleButton.sora.image = viewModel.actionButtonImage
        view.middleButton.sora.tintColor = .additionalPolkaswap
        view.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.viewModel.middleButtonActionHandler?()
            
            if self.viewModel.isSwap {
                self.rotateAnimation()
            }
        }
        
        view.firstAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.firstAsset.sora.fullFiatText = viewModel.firstFieldEmptyStateFullFiatText
        view.firstAsset.sora.text = ""
        view.firstAsset.sora.assetImage = R.image.wallet.emptyToken()
        view.firstAsset.textField.inputAccessoryView = accessoryView
        view.firstAsset.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel.choiсeBaseAssetButtonTapped()
        }
        view.firstAsset.textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.viewModel.focusedField = .one
        }
        view.firstAsset.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.viewModel.focusedField = .one
            self?.viewModel.inputedFirstAmount = Decimal(string: self?.assetsView.firstAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel.recalculate(field: .one)
        }
        
        view.secondAsset.sora.assetSymbol = R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
        view.secondAsset.sora.fullFiatText = viewModel.secondFieldEmptyStateFullFiatText
        view.secondAsset.sora.text = ""
        view.secondAsset.sora.assetImage = R.image.wallet.emptyToken()
        view.secondAsset.textField.inputAccessoryView = accessoryView
        view.secondAsset.sora.assetChoiceHandler = { [weak self] in
            self?.viewModel.choiсeTargetAssetButtonTapped()
        }
        view.secondAsset.textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.viewModel.focusedField = .two
        }
        view.secondAsset.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.viewModel.focusedField = .two
            self?.viewModel.inputedSecondAmount = Decimal(string: self?.assetsView.secondAsset.textField.text ?? "", locale: Locale.current) ?? 0
            self?.viewModel.recalculate(field: .two)
        }
        return view
    }()
    
    private lazy var optionsView: OptionsView = {
        let view = OptionsView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.marketLabel.sora.isHidden = !viewModel.isSwap
        view.marketButton.sora.isHidden = !viewModel.isSwap
        view.slipageButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.changeSlippageTolerance()
        }
        view.marketButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.changeMarket()
        }
        return view
    }()
    
    private lazy var warningView: WarningView = {
        let view = WarningView()
        view.sora.isHidden = true
        return view
    }()
    
    private lazy var reviewLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.review(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.isEnabled = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.reviewButtonTapped()
        }
        return button
    }()

    var viewModel: LiquidityViewModelProtocol

    init(viewModel: LiquidityViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        
        if let imageName = viewModel.imageName {
            let logo = UIImage(named: imageName)
            let imageView = UIImageView(image: logo)
            navigationItem.titleView = imageView
        }
        
        if let title = viewModel.title {
            navigationItem.title = title
        }

        addCloseButton()
        
        if !viewModel.isSwap {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.wallet.info24(),
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(infoTapped))
            navigationItem.leftBarButtonItem?.tintColor = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        }

        viewModel.viewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        spaceConstraint?.constant = UIScreen.main.bounds.height - 300
    }
    
    @objc
    func infoTapped() {
        viewModel.infoButtonTapped()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(scrollView)
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(assetsView)
        stackView.addArrangedSubview(optionsView)
        stackView.addArrangedSubview(warningView)
        stackView.addArrangedSubview(reviewLiquidity)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            
            assetsView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            assetsView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            warningView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            warningView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),

            reviewLiquidity.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            reviewLiquidity.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
        ])
    }
    
    private func rotateAnimation() {
        UIView.animate(withDuration: 0.5) {
            self.assetsView.middleButton.transform = CGAffineTransform(rotationAngle: .pi)
        }

        UIView.animate(
            withDuration: 0.5,
            delay: 0.45,
            options: UIView.AnimationOptions.curveEaseIn
        ) {
            self.assetsView.middleButton.transform = CGAffineTransform(rotationAngle: 2 * .pi)
        }
    }
}

extension PolkaswapViewController: LiquidityViewProtocol {
    func update(details: [DetailViewModel]) {
        stackView.arrangedSubviews.filter { $0 is DetailView || $0.tag == 1 }.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        
        let detailsViews = details.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.isHidden = detailModel.rewardAssetImage == nil
            detailModel.rewardAssetImage?.loadImage { (icon, _) in
                view.assetImageView.image = icon
            }

            view.titleLabel.sora.text = detailModel.title
            view.valueLabel.sora.attributedText = detailModel.assetAmountText
            view.fiatValueLabel.sora.attributedText = detailModel.fiatAmountText
            view.fiatValueLabel.sora.isHidden = detailModel.fiatAmountText == nil
            view.infoButton.sora.isHidden = detailModel.infoHandler == nil
            view.infoButton.sora.addHandler(for: .touchUpInside) { [weak detailModel] in
                detailModel?.infoHandler?()
            }
            return view
        }
        
        stackView.addArrangedSubviews(detailsViews)
        detailsViews.forEach {
            $0.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16).isActive = true
            $0.centerXAnchor.constraint(equalTo: stackView.centerXAnchor).isActive = true
        }
        
        let spaceView = SoramitsuView()
        spaceView.tag = 1
        spaceConstraint = spaceView.heightAnchor.constraint(equalToConstant: 0)
        spaceConstraint?.isActive = true
        stackView.addArrangedSubviews(spaceView)
    }
    
    func updateFirstAsset(balance: String) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.fullFiatText = balance
        }
    }
    
    func updateSecondAsset(balance: String) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.fullFiatText = balance
        }
    }
    
    func updateFirstAsset(symbol: String, image: UIImage?) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.assetSymbol = symbol
            self.assetsView.firstAsset.sora.assetImage = image
        }
    }
    
    func updateSecondAsset(symbol: String, image: UIImage?) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.assetSymbol = symbol
            self.assetsView.secondAsset.sora.assetImage = image
        }
    }
    
    func updateFirstAsset(fiatText: String) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.inputedFiatAmountText = fiatText
        }
    }
    
    func updateSecondAsset(fiatText: String) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.inputedFiatAmountText = fiatText
        }
    }
    
    func update(slippageTolerance: String) {
        optionsView.slipageButton.sora.title = slippageTolerance
    }
    
    func update(selectedMarket: String) {
        optionsView.marketButton.sora.title = selectedMarket
    }
    
    func set(firstAmountText: String) {
        assetsView.firstAsset.textField.sora.text = firstAmountText == "0" ? "" : firstAmountText
    }
    
    func set(secondAmountText: String) {
        assetsView.secondAsset.textField.sora.text = secondAmountText == "0" ? "" : secondAmountText
    }
    
    func setupButton(isEnabled: Bool) {
        DispatchQueue.main.async {
            self.reviewLiquidity.sora.isEnabled = isEnabled
            if isEnabled {
                self.reviewLiquidity.sora.backgroundColor = .additionalPolkaswap
            }
        }
    }
    
    func focus(field: FocusedField) {
        if field == .one {
            assetsView.firstAsset.textField.becomeFirstResponder()
        } else {
            assetsView.secondAsset.textField.becomeFirstResponder()
        }
    }
    
    func updateFirstAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {
        DispatchQueue.main.async {
            self.assetsView.firstAsset.sora.state = state
            self.assetsView.firstAsset.textField.sora.textColor = amountColor
            self.assetsView.firstAsset.inputedFiatAmountLabel.sora.textColor = fiatColor
        }
    }
    
    func updateSecondAsset(state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor) {
        DispatchQueue.main.async {
            self.assetsView.secondAsset.sora.state = state
            self.assetsView.secondAsset.textField.sora.textColor = amountColor
            self.assetsView.secondAsset.inputedFiatAmountLabel.sora.textColor = fiatColor
        }
    }
    
    func update(isNeedLoadingState: Bool) {
        reviewLiquidity.sora.loadingPlaceholder.type = isNeedLoadingState ? .shimmer : .none
    }
    
    func updateMiddleButton(isEnabled: Bool) {
        assetsView.middleButton.sora.isEnabled = isEnabled
    }
    
    func setupMarketButton(isLoadingState: Bool) {
        optionsView.marketButton.sora.loadingPlaceholder.type = isLoadingState ? .shimmer : .none
    }
    
    func setAccessoryView(isHidden: Bool) {
        accessoryView.isHidden = isHidden
    }

    func updateReviewButton(title: String) {
        DispatchQueue.main.async {
            self.reviewLiquidity.sora.title = title
        }
    }
    
    func updateWarinignView(model: WarningViewModel) {
//        warningView.setupView(with: model)
    }
}

extension PolkaswapViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -236 {
            close()
        }
    }
}
