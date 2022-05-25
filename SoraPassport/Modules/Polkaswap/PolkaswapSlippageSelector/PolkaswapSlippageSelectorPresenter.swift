import Foundation
import CommonWallet

protocol PolkaswapSlippageSelectorPresenterProtocol: AnyObject {
    var view: PolkaswapSlippageSelectorViewProtocol? { get set }
    func setup(preferredLocalizations languages: [String]?)
    func didSelectPredefinedSlippage(atIndex: Int)
    func didSelectSlippage(_: Double)
}

class PolkaswapSlippageSelectorPresenter: PolkaswapSlippageSelectorPresenterProtocol {
    weak var view: PolkaswapSlippageSelectorViewProtocol?
    let predefinedSlippage: [Double] = [0.1, 0.5, 1.0]
    let mayFailTreshold         = 0.1
    let mayBeFrontrunTreshold   = 5.0
    let slippageMax             = 10.0
    let defaultSlippage         = 0.5
    var slippage: Double?
    var languages: [String]?
    var amountFormatterFactory: AmountFormatterFactoryProtocol

    init(amountFormatterFactory: AmountFormatterFactoryProtocol) {
        self.amountFormatterFactory = amountFormatterFactory
    }

    func setup(preferredLocalizations languages: [String]?) {
        let formatter = amountFormatterFactory.createPercentageFormatter(maxPrecision: 2).value(for: view?.localizationManager?.selectedLocale ?? Locale.current)
        let amountInputViewModel = AmountInputViewModel(symbol: "", amount: nil, limit: Decimal(slippageMax), formatter: formatter, inputLocale: view?.localizationManager?.selectedLocale ?? Locale.current)

        let slippage = slippage ?? defaultSlippage
        let warning = warning(for: slippage)
        let warningText = text(for: warning)
        let viewModel = PolkaswapSlippageSelectorViewModel(
            title: R.string.localizable.polkaswapSlippageTolerance(preferredLanguages: languages).uppercased(),
            warning: warningText,
            description: R.string.localizable.polkaswapSlippageInfo(preferredLanguages: languages),
            buttons: predefinedSlippage.map({formatter.stringFromDecimal(Decimal($0)) ?? "\($0)%"}),
            amountInputViewModel: amountInputViewModel
        )
        view?.didReceive(viewModel: viewModel)
        view?.slippage = slippage
        view?.warning = warning
    }

    func didSelectPredefinedSlippage(atIndex index: Int) {
        let slippage = predefinedSlippage[index]
        didSelectSlippage(slippage)
    }

    func didSelectSlippage(_ slippage: Double) {
        self.slippage = slippage
        view?.slippage = slippage
//        setup(preferredLocalizations: languages)
        view?.warning = warning(for: slippage)
    }

    func warning(for slippage: Double) -> PolkaswapSlippageSelectorView.Warning {
        if slippage <= mayFailTreshold {
            return .mayFail
        } else if slippage >= mayBeFrontrunTreshold {
            return .mayBeFrontrun
        } else {
            return .none
        }
    }

    func text(for warning: PolkaswapSlippageSelectorView.Warning) -> String? {
        switch warning {
        case .none:
            return nil
        case .mayBeFrontrun:
            return R.string.localizable.polkaswapSlippageFrontrun(preferredLanguages: languages)
        case .mayFail:
            return R.string.localizable.polkaswapSlippageMayfail(preferredLanguages: languages)
        }
    }
}
