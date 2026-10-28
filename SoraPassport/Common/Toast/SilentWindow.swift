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

protocol SilentViewController: UIViewController {
    var tappableView: UIView? { get }
}

extension SilentViewController {
    var tappableView: UIView? { nil }
}

final class SilentWindow: UIWindow {
    private let root: SilentViewController

    init(root: SilentViewController) {
        self.root = root
        // A window without a scene is never displayed in a scene-based app.
        if let windowScene = UIApplication.shared.soraWindowScene {
            super.init(windowScene: windowScene)
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        rootViewController = root

        isHidden = false
        windowLevel = UIWindow.Level(rawValue: CGFloat.greatestFiniteMagnitude)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let view = root.tappableView else { return false }
        let viewPoint = convert(point, to: view)
        return view.point(inside: viewPoint, with: event)
    }
}

