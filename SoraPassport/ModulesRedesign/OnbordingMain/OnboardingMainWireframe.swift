// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SSFCloudStorage
import UIKit
import SoraUIKit

final class OnboardingMainWireframe: OnboardingMainWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    var activityIndicatorWindow: UIWindow?
    var endAddingBlock: (() -> Void)?

    func showSignup(from view: OnboardingMainViewProtocol?, isGoogleBackupSelected: Bool) {
        guard
            let endBlock = endAddingBlock,
            let usernameSetupController = SetupAccountNameViewFactory.createViewForAdding(isGoogleBackupSelected: isGoogleBackupSelected,
                                                                                          isNeedSetupName: false,
                                                                                          endEditingBlock: endBlock)?.controller,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        
        DispatchQueue.main.async {
            navigationController.pushViewController(usernameSetupController, animated: true)
        }
    }
    
    func showAccountRestoreRedesign(from view: OnboardingMainViewProtocol?, sourceType: AccountImportSource) {
        guard
            let endBlock = endAddingBlock,
            let restorationController = AccountImportViewFactory.createViewForRedesignAdding(sourceType: sourceType, endAddingBlock: endBlock)?.controller,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        
        navigationController.pushViewController(restorationController, animated: true)
    }

    func showAccountRestore(from view: OnboardingMainViewProtocol?) {
        guard
            let endBlock = endAddingBlock,
            let restorationController = AccountImportViewFactory.createViewForAdding(endAddingBlock: endBlock)?.controller,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        
        navigationController.pushViewController(restorationController, animated: true)
    }

    func showKeystoreImport(from view: OnboardingMainViewProtocol?) {
        guard
            let navigationController = view?.controller.navigationController,
            navigationController.viewControllers.count == 1,
            navigationController.presentedViewController == nil
        else {
            return
        }
        
        showAccountRestore(from: view)
    }
    
    func showBackupedAccounts(from view: OnboardingMainViewProtocol?, accounts: [OpenBackupAccount]) {
        guard let viewController = BackupedAccountsViewFactory.createView(with: accounts, endAddingBlock: endAddingBlock)?.controller else { return }
        
        DispatchQueue.main.async {
            view?.controller.navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

enum OnboardingImportMethod: CaseIterable {
    case passphrase, rawSeed, google

    var title: String {
        switch self {
        case .passphrase: return R.string.localizable.recoveryPassphrase(preferredLanguages: .currentLocale)
        case .rawSeed: return R.string.localizable.commonRawSeed(preferredLanguages: .currentLocale)
        case .google: return "Google"
        }
    }

    var symbol: String {
        switch self {
        case .passphrase: return "list.number"
        case .rawSeed: return "key"
        case .google: return "cloud"
        }
    }
}

extension OnboardingMainWireframeProtocol {
    func showImportMethods(from view: OnboardingMainViewProtocol?, select: @escaping (OnboardingImportMethod) -> Void) {
        guard let host = view?.controller, host.presentedViewController == nil else { return }
        let sheet = OnboardingImportSheet(select: select)
        sheet.modalPresentationStyle = .pageSheet
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        host.present(sheet, animated: true)
    }
}

final class OnboardingImportSheet: UIViewController {
    private let select: (OnboardingImportMethod) -> Void
    private let stack = UIStackView()
    private var didEnter = false

    init(select: @escaping (OnboardingImportMethod) -> Void) {
        self.select = select
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let page = AuroraView(frame: view.bounds)
        page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(page)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12)
        ])
        WalletDisplay.pinReadable(stack, inScroll: scroll, margin: 24)
        let title = WalletUX.label(R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale), style: .title2)
        title.accessibilityTraits.insert(.header)
        stack.addArrangedSubview(title)
        stack.setCustomSpacing(20, after: title)
        for method in OnboardingImportMethod.allCases {
            let button = ImportMethodButton(type: .custom)
            var configuration = UIButton.Configuration.plain()
            configuration.title = method.title
            configuration.baseForegroundColor = WalletUX.foreground
            configuration.titleLineBreakMode = .byWordWrapping
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = WalletUX.font(.headline)
                return attributes
            }
            configuration.image = UIImage(systemName: method.symbol)
            configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in Lit.lacquerText }
            configuration.imagePadding = 16
            configuration.contentInsets = .init(top: 14, leading: 20, bottom: 14, trailing: 20)
            button.configuration = configuration
            button.accessibilityLabel = method.title
            button.contentHorizontalAlignment = .leading
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            button.addAction(UIAction { [weak self] _ in
                guard let self, self.view.isUserInteractionEnabled else { return }
                self.view.isUserInteractionEnabled = false
                self.dismiss(animated: true) { self.select(method) }
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        stack.addArrangedSubview(WalletUX.button(R.string.localizable.commonCancel(preferredLanguages: .currentLocale),
                                                  style: .tertiary) { [weak self] in self?.dismiss(animated: true) })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didEnter else { return }
        didEnter = true
        for (index, button) in stack.arrangedSubviews.compactMap({ $0 as? ImportMethodButton }).enumerated() {
            LitMotion.rise(button, by: 6, after: Double(index) * 0.035)
        }
    }
}

private final class ImportMethodButton: UIButton {
    private lazy var backing = LitBacking(host: self)

    override func layoutSubviews() {
        super.layoutSubviews()
        backing.layout(radius: Lit.controlRadius)
    }

    override var isHighlighted: Bool {
        didSet { if LitMotion.allowed { LitMotion.press(self, pressed: isHighlighted) } }
    }
}
