import Foundation
import UIKit
import SoraUIKit

protocol GenerateQRViewProtocol: ControllerBackedProtocol {}

final class GenerateQRViewController: SoramitsuViewController {

    private var spaceConstraint: NSLayoutConstraint?

    private let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .center
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    private let scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
        scrollView.sora.cancelsTouchesOnDragging = true
        return scrollView
    }()
    
    private lazy var switcherView: SwitcherView = SwitcherView()
    
    private let inputSendInfoView: InputSendInfoView = {
        let view = InputSendInfoView()
        view.isHidden = true
        return view
    }()
    
    private var receiveView: ReceiveQRView = {
        let view = ReceiveQRView()
        view.isHidden = true
        return view
    }()

    private lazy var scanQrButton: SoramitsuButton = {
        let text = SoramitsuTextItem(
            text: R.string.localizable.commomScanQr(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .accentSecondary,
            alignment: .center
        )
        
        let button = SoramitsuButton()
        button.sora.attributedText = text
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .bgSurface
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.dismiss(animated: true)
        }
        return button
    }()

    var viewModel: GenerateQRViewModelProtocol

    init(viewModel: GenerateQRViewModelProtocol) {
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
        addCloseButton()

        navigationItem.title = R.string.localizable.receiveTokens(preferredLanguages: .currentLocale)

        viewModel.setupReceiveView = { [weak self] viewModel in
            DispatchQueue.main.async {
                self?.receiveView.viewModel = viewModel
            }
        }
        
        viewModel.setupSwicherView = { [weak self] viewModel in
            DispatchQueue.main.async {
                self?.switcherView.viewModel = viewModel
            }
        }
        
        viewModel.setupRequestView = { [weak self] viewModel in
            DispatchQueue.main.async {
                self?.inputSendInfoView.viewModel = viewModel
            }
        }

        viewModel.updateContent = { [weak self] mode in
            DispatchQueue.main.async {
                self?.receiveView.isHidden = mode == .request
                self?.scanQrButton.isHidden = mode == .request
                self?.inputSendInfoView.isHidden = mode == .receive
                
                if mode == .receive {
                    self?.view.endEditing(true)
                } else {
                    self?.inputSendInfoView.assetView.textField.becomeFirstResponder()
                }
            }
        }
        
        viewModel.showShareContent = { [weak self] sources in
            DispatchQueue.main.async {
                let activityController = UIActivityViewController(activityItems: sources, applicationActivities: nil)
                self?.present(activityController, animated: true, completion: nil)
            }
        }
        
        viewModel.viewDidLoad()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)

        view.addSubviews(scrollView)
        scrollView.addSubview(stackView)
        view.addSubview(scanQrButton)
        
        stackView.addArrangedSubview(switcherView)
        stackView.addArrangedSubview(receiveView)
        stackView.addArrangedSubview(inputSendInfoView)

        let spaceView = SoramitsuView()
        spaceConstraint = spaceView.heightAnchor.constraint(equalToConstant: 0)
        spaceConstraint?.isActive = true
        stackView.addArrangedSubviews(spaceView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        spaceConstraint?.constant = UIScreen.main.bounds.height - 300
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scanQrButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            scanQrButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanQrButton.heightAnchor.constraint(equalToConstant: 56),
            scanQrButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            
            inputSendInfoView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 24),
            inputSendInfoView.centerXAnchor.constraint(equalTo: stackView.centerXAnchor),
            
            receiveView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            receiveView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            switcherView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}

extension GenerateQRViewController: GenerateQRViewProtocol {}
