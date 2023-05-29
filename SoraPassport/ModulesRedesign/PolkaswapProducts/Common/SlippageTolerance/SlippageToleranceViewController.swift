import Foundation
import UIKit
import SoraUIKit

protocol SlippageToleranceViewProtocol: ControllerBackedProtocol {
    func setup(tolerance: Float)
    func setupDoneButton(isEnabled: Bool)
}

final class SlippageToleranceViewController: SoramitsuViewController {

    private lazy var accessoryView: InputAccessoryView = {
        let rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 48))
        let view = InputAccessoryView(frame: rect)
        view.delegate = viewModel
        view.variants = [ InputAccessoryVariant(displayValue: "0.1%", value: 0.1),
                          InputAccessoryVariant(displayValue: "0.5%", value: 0.5),
                          InputAccessoryVariant(displayValue: "1%", value: 1) ]
        return view
    }()
    
    private lazy var slippageToleranceView: SlippageToleranceView = {
        let view = SlippageToleranceView()
        view.delegate = viewModel
        view.slipageButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.doneButtonTapped()
        }
        view.field.textField.inputAccessoryView = accessoryView
        return view
    }()

    var viewModel: SlippageToleranceViewModelProtocol

    init(viewModel: SlippageToleranceViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.backButtonTitle = ""
        navigationItem.title = R.string.localizable.polkaswapSlippageTolerance(preferredLanguages: .currentLocale)
        setupView()
        setupConstraints()
        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        slippageToleranceView.field.textField.becomeFirstResponder()
    }

    @objc
    func closeTapped() {
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(slippageToleranceView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            slippageToleranceView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            slippageToleranceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            slippageToleranceView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}

extension SlippageToleranceViewController: SlippageToleranceViewProtocol {
    func setupDoneButton(isEnabled: Bool) {
        slippageToleranceView.slipageButton.sora.isEnabled = isEnabled
        if isEnabled {
            slippageToleranceView.slipageButton.sora.backgroundColor = .additionalPolkaswap
        }
    }
    
    func setup(tolerance: Float) {
        slippageToleranceView.field.sora.text = "\(tolerance)%"
    }
}


