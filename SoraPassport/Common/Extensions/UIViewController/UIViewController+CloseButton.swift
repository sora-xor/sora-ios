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
import SoraUIKit

enum CloseButtonPosition {
    case left
    case right
}

extension UIViewController {
    
    func addCloseButton(position: CloseButtonPosition = .right) {
        let closeButton = UIBarButtonItem(image: R.image.wallet.cross(),
                                     style: .plain,
                                     target: self,
                                     action: #selector(close))
        closeButton.accessibilityLabel = R.string.localizable.commonClose(preferredLanguages: nil)
        
        switch position {
        case .right: navigationItem.rightBarButtonItem = closeButton
        case .left:  navigationItem.leftBarButtonItem = closeButton
        }
    }
    
    func addBackButton() {
        let backButton = UIBarButtonItem(image: R.image.wallet.backArrow(),
                                     style: .plain,
                                     target: self,
                                     action: #selector(backward))
        
        navigationItem.leftBarButtonItem = backButton
    }
    
    @objc
    func close() {
        dismiss(animated: true)
    }
    
    @objc
    func backward() {
        guard let navigationController = self.navigationController else { return }
        navigationController.popViewController(animated: true)
    }
}

extension SoramitsuViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -120 {
            close()
        }
    }
}
