// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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


