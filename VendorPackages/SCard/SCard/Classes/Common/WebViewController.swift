import UIKit
import WebKit

final class WebViewController: UIViewController {

    private var webView: WKWebView?

    let request: URLRequest
    let configuration: WKWebViewConfiguration

    init(configuration: WKWebViewConfiguration, request: URLRequest) {
        self.request = request
        self.configuration = configuration

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureWebView()

        webView?.load(request)
    }

    private func configureWebView() {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true

        self.webView = webView
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        didStartLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        didStopLoading()
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(WKNavigationResponsePolicy.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didStopLoading()
    }
}

protocol ControllerBackedProtocol: AnyObject {
    var isSetup: Bool { get }
    var controller: UIViewController { get }
}

extension ControllerBackedProtocol where Self: UIViewController {
    var isSetup: Bool {
        return controller.isViewLoaded
    }

    var controller: UIViewController {
        return self
    }
}

protocol WebPresentingViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {}

extension WebViewController: WebPresentingViewProtocol {}

final class WKWebViewController: UIViewController {

    private let viewModel: XOneViewModel


    private var rootView: WKWebView {
        view as! WKWebView
    }

    init(viewModel: XOneViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = WKWebView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.loadHTMLString(viewModel.xOneHtmlString, baseURL: nil)
        // viewModel.checkStatus()
    }
}


protocol LoadableViewProtocol: AnyObject {
    var loadableContentView: UIView! { get }
    var shouldDisableInteractionWhenLoading: Bool { get }

    func didStartLoading()
    func didStopLoading()
}

struct LoadableViewProtocolConstants {
    static let activityIndicatorIdentifier: String = "LoadingIndicatorIdentifier"
    static let animationDuration = 0.35
}

extension LoadableViewProtocol where Self: UIViewController {
    var loadableContentView: UIView! {
        return view
    }

    var shouldDisableInteractionWhenLoading: Bool {
        return true
    }

    func didStartLoading() {
        let activityIndicator = loadableContentView.subviews.first {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        }

        guard activityIndicator == nil else {
            return
        }

        let newIndicator = SoraLoadingViewFactory.createLoadingView()
        newIndicator.accessibilityIdentifier = LoadableViewProtocolConstants.activityIndicatorIdentifier
        newIndicator.frame = loadableContentView.bounds
        newIndicator.autoresizingMask = UIView.AutoresizingMask.flexibleWidth.union(.flexibleHeight)
        newIndicator.alpha = 0.0
        loadableContentView.addSubview(newIndicator)

        loadableContentView.isUserInteractionEnabled = shouldDisableInteractionWhenLoading

        newIndicator.startAnimating()

        UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration) {
            newIndicator.alpha = 1.0
        }
    }

    func didStopLoading() {
        let activityIndicator = loadableContentView.subviews.first {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        }

        guard let currentIndicator = activityIndicator as? LoadingView else {
            return
        }

        currentIndicator.accessibilityIdentifier = nil
        loadableContentView.isUserInteractionEnabled = true

        UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration,
                       animations: {
                        currentIndicator.alpha = 0.0
        }, completion: { _ in
            currentIndicator.stopAnimating()
            currentIndicator.removeFromSuperview()
        })
    }
}

public protocol LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView
}

final class SoraLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let loadingView = LoadingView(frame: UIScreen.main.bounds,
                                      indicatorImage: .init(named: "iconLoadingIndicator") ?? UIImage())
        loadingView.backgroundColor = .init(red: 236, green: 239, blue: 240, alpha: 1)
        loadingView.contentBackgroundColor = .init(red: 163, green: 164, blue: 168, alpha: 1)
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}

public final class LoadingView: UIView {
    private struct Constants {
        static let animationPath = "transform.rotation.z"
        static let animationKey = "loading.animation.key"
    }

    public var contentSize: CGSize {
        set(newValue) {
            contentViewWidthConstraint.constant = newValue.width
            contentViewHeightConstraint.constant = newValue.height
            setNeedsLayout()
        }

        get {
            return CGSize(width: contentViewWidthConstraint.constant,
                          height: contentViewHeightConstraint.constant)
        }
    }

    public var contentCornerRadius: CGFloat {
        set(newValue) {
            contentView.layer.cornerRadius = newValue
        }

        get {
            return contentView.layer.cornerRadius
        }
    }

    public var contentBackgroundColor: UIColor {
        set(newValue) {
            contentView.backgroundColor = newValue
        }

        get {
            return contentView.backgroundColor ?? .white
        }
    }

    public var indicatorImage: UIImage? {
        set(newValue) {
            imageView.image = newValue
        }

        get {
            return imageView.image
        }
    }

    public var isAnimating: Bool = false

    public var animationDuration: TimeInterval = 1.0

    private var imageView: UIImageView!
    private var contentView: UIView! // RoundedView!

    private var contentViewWidthConstraint: NSLayoutConstraint!
    private var contentViewHeightConstraint: NSLayoutConstraint!

    deinit {
        clearApplicationStateHandlers()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    convenience public init(frame: CGRect, indicatorImage: UIImage) {
        self.init(frame: frame)

        self.indicatorImage = indicatorImage
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        configureContentView()
        configureImageView()
    }

    private func configureContentView() {
        contentView = UIView() // RoundedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
//        contentView.strokeWidth = 0.0
//        contentView.shadowOpacity = 0.0
        addSubview(contentView)

        contentView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        contentView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        contentViewWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: 120.0)
        contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 120.0)

        contentViewWidthConstraint.isActive = true
        contentViewHeightConstraint.isActive = true
    }

    private func configureImageView() {
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }

    public func startAnimating() {
        guard !isAnimating else {
            return
        }

        isAnimating = true

        let animation = createAnimation()
        imageView.layer.add(animation, forKey: Constants.animationKey)

        setupApplicationStateHandlers()
    }

    public func stopAnimating() {
        guard isAnimating else {
            return
        }

        imageView.layer.removeAnimation(forKey: Constants.animationKey)

        isAnimating = false

        clearApplicationStateHandlers()
    }

    public func createAnimation() -> CAAnimation {
        let animation = CAKeyframeAnimation(keyPath: Constants.animationPath)
        animation.values = [0.0, CGFloat.pi, 2.0 * CGFloat.pi]
        animation.timingFunctions = [CAMediaTimingFunction(name: .easeIn), CAMediaTimingFunction(name: .easeOut)]
        animation.calculationMode = .linear
        animation.keyTimes = [0.0, 0.5, 1.0]
        animation.repeatDuration = TimeInterval.infinity
        animation.duration = animationDuration
        animation.isCumulative = false
        return animation
    }

    // MARK: Application state handling

    private func setupApplicationStateHandlers() {
        clearApplicationStateHandlers()

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil,
                                               queue: OperationQueue.main) { [weak self] (_) in
                                                self?.resumeSnapshotAnimation()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil,
                                               queue: OperationQueue.main) { [weak self] (_) in
                                                self?.imageView.layer.removeAnimation(forKey: Constants.animationKey)
        }
    }

    private func clearApplicationStateHandlers() {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
    }

    private func resumeSnapshotAnimation() {
        if isAnimating {
            let animation = createAnimation()
            imageView.layer.add(animation, forKey: Constants.animationKey)
        }
    }

}

