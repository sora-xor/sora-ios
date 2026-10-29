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

protocol AppEventDisplayLogic: SilentViewController {
    func show()

    func hide(completion: @escaping () -> Void)
}

final class AppEventService {
    enum HideMode {
        case never
        case after(delay: Double)
    }

    var hideMode: HideMode

    private var viewController: AppEventDisplayLogic?
    private var windowShowed = false
    private var window: UIWindow?
    private var hideWorkItem: DispatchWorkItem?
    private var isStopped: Bool = false
    private let throttler = Throttler(minimumDelay: 0.3)

    init(hideMode: HideMode = .after(delay: 3)) {
        self.hideMode = hideMode
    }
    
    deinit {
        hideWorkItem?.cancel()
        window = nil
    }
}

extension AppEventService {
    func showToasterIfNeeded(viewController: AppEventDisplayLogic, isNeedHide: Bool = true, isNeedForceUpdate: Bool = false) {
        guard !windowShowed || isNeedForceUpdate else { return }
        throttler.throttle { [weak self] in
            guard let self, !isStopped else { return }
            guard !windowShowed || isNeedForceUpdate else { return }
            let show: (Bool) -> Void = { [weak self] shouldHide in
                guard let self, !isStopped else { return }
                self.viewController = viewController
                window = SilentWindow(root: viewController)
                windowShowed = true
                viewController.show()
                hideWorkItem?.cancel()
                if shouldHide, case let .after(delay) = hideMode {
                    let work = DispatchWorkItem { [weak self] in self?.hideToasterIfNeeded() }
                    hideWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
                }
            }
            if isNeedForceUpdate {
                hideToasterIfNeeded(with: isNeedHide, completion: show)
            } else {
                show(isNeedHide)
            }
        }
    }

    func hideToasterIfNeeded(with isNeedHide: Bool = true, completion: ((Bool) -> Void)? = nil) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        throttler.throttle { [weak self] in
            guard let self else { return }
            windowShowed = false
            let hiddenWindow = window
            let finish = { [weak self] in
                guard let self else { return }
                hiddenWindow?.isHidden = true
                hiddenWindow?.rootViewController = nil
                if window === hiddenWindow { window = nil }
                completion?(isNeedHide)
            }
            if let viewController {
                viewController.hide(completion: finish)
            } else {
                finish()
            }
        }
    }

    func start() {
        isStopped = false
        guard let viewController else { return }
        showToasterIfNeeded(viewController: viewController)
    }

    func stop(with completion: (() -> Void)? = nil) {
        isStopped = true
        hideToasterIfNeeded { _ in completion?() }
    }
}
