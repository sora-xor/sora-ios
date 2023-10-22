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
    private var isStopped: Bool = false
    private let throttler = Throttler(minimumDelay: 0.3)

    init(hideMode: HideMode = .after(delay: 3)) {
        self.hideMode = hideMode
    }
    
    deinit {
        window = nil
    }
}

extension AppEventService {
    func showToasterIfNeeded(viewController: AppEventDisplayLogic, isNeedHide: Bool = true, isNeedForceUpdate: Bool = false) {
        guard !windowShowed else { return }
        throttler.throttle { [weak self] in
            guard !(self?.isStopped ?? false) else { return }
            
            self?.viewController = viewController
            
            guard (!(self?.windowShowed ?? false)) || isNeedForceUpdate else { return  }
            
            let completion: (Bool) -> Void = { [weak self] isNeedHide1 in
                self?.window = SilentWindow(root: viewController)
                viewController.show()
                
                self?.windowShowed = true

                if isNeedHide1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.hideToasterIfNeeded()
                    }
                }
            }
            
            if isNeedForceUpdate {
                self?.hideToasterIfNeeded(with: isNeedHide, completion: completion)
                return
            }

            completion(isNeedHide)
        }
    }
    
    func hideToasterIfNeeded(with isNeedHide: Bool = true, completion: ((Bool) -> Void)? = nil) {
        throttler.throttle { [weak self] in
            self?.viewController?.hide { [weak self] in
                if self?.windowShowed == false {
                    self?.window = nil
                }
                completion?(isNeedHide)
            }
            self?.windowShowed = false
        }
    }
    
    func start() {
        isStopped = false
        
        guard let viewController = viewController else { return }
        showToasterIfNeeded(viewController: viewController)
    }
    
    func stop(with completion: (() -> Void)? = nil) {
        hideToasterIfNeeded { [weak self] _ in
            self?.isStopped = true
        }
    }
}

