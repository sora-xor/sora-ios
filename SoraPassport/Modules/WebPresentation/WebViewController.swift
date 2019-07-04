/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import WebKit

final class WebViewController: UIViewController {

    var logger: LoggerProtocol?

    private var webView: WKWebView!
    private var secondaryTitleLabel: UILabel?

    private(set) var url: URL

    private(set) var secondaryTitle: String {
        didSet {
            updateTitleIfNeeded()
        }
    }

    init(url: URL, secondaryTitle: String) {
        self.url = url
        self.secondaryTitle = secondaryTitle

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        webView.stopLoading()
    }

    // Initialization

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .white
        self.view = view

        configureWebView()
        configureTitle()
        configureClose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        didStartLoading()
        webView.load(URLRequest(url: url))
    }

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        if #available(iOS 11.0, *) {
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        } else {
            webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        }
    }

    private func configureTitle() {
        let secondaryTitleLabel = UILabel()
        secondaryTitleLabel.textColor = UIColor.navigationBarTitleColor
        secondaryTitleLabel.font = UIFont.navigationTitleFont
        secondaryTitleLabel.text = secondaryTitle

        let screenBounds = UIScreen.main.bounds
        let width = min(screenBounds.size.width, screenBounds.size.height) * 0.75

        if #available(iOS 11.0, *) {
            secondaryTitleLabel.translatesAutoresizingMaskIntoConstraints = false

            let leftBarButtonItem = UIBarButtonItem(customView: secondaryTitleLabel)
            navigationItem.leftBarButtonItem = leftBarButtonItem

            secondaryTitleLabel.widthAnchor.constraint(equalToConstant: width).isActive = true
        } else {
            let size = secondaryTitleLabel.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            secondaryTitleLabel.frame = CGRect(origin: .zero, size: size)

            let leftBarButtonItem = UIBarButtonItem(customView: secondaryTitleLabel)
            navigationItem.leftBarButtonItem = leftBarButtonItem
        }
    }

    private func updateTitleIfNeeded() {
        if isViewLoaded {
            secondaryTitleLabel?.text = secondaryTitle
        }
    }

    private func configureClose() {
        let righBarButtonItem = UIBarButtonItem(image: R.image.iconClose(),
                                                style: .plain,
                                                target: self,
                                                action: #selector(actionClose))

        navigationItem.rightBarButtonItem = righBarButtonItem
    }

    // MARK: Action

    @objc private func actionClose() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension WebViewController: LoadableViewProtocol {}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger?.warning("WebView: \(error)")

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
