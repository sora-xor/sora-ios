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

import UIKit

final class AppEventViewController: UIViewController {
    struct ViewModel {
        let title: NSAttributedString
    }

    enum Style {
        case custom(ViewModel)

        var viewModel: ViewModel {
            switch self {
            case let .custom(viewModel):
                return viewModel
            }
        }
    }

    private let eventView: AppEventView

    private lazy var hideConstraint = eventView.topAnchor.constraint(
        equalTo: view.bottomAnchor
    )
    private lazy var showConstraint = eventView.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -16
    )

    private let style: Style

    init(style: Style) {
        self.eventView = AppEventView(frame: .zero)
        self.style = style
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        eventView.fill(via: style.viewModel)
    }
}

extension AppEventViewController: AppEventDisplayLogic {
    func show() {
        updateConstraints(for: true)
    }

    func hide(completion: @escaping () -> Void) {
        updateConstraints(for: false, completion: completion)
    }
}

private extension AppEventViewController {
    enum Configuration {
        static let animationDuration = 0.3
        static let horizontalOffset: CGFloat = 16
    }

    func setup() {
        view.backgroundColor = .clear

        view.addSubview(eventView)

        hideConstraint.activate()

        NSLayoutConstraint.activate([
            eventView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 55),
            eventView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        view.rebuildLayout()
    }

    func updateConstraints(for mode: Bool, completion: (() -> Void)? = nil) {
        showConstraint.isActive = mode
        hideConstraint.isActive = !mode

        view.rebuildLayout(animated: false, duration: Configuration.animationDuration, options: .curveEaseOut) { _ in
            completion?()
        }
    }
}


