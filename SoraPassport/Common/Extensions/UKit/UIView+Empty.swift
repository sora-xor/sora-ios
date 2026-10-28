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
import Then
import Anchorage
import SnapKit

public extension UIView {
    static func empty(height: CGFloat? = nil, width: CGFloat? = nil) -> UIView {
        UIView().then {
            $0.backgroundColor = .clear

            if let height = height {
                $0.heightAnchor == height
            }

            if let width = width {
                $0.widthAnchor == width
            }
        }
    }

    func wrapped(height: CGFloat? = nil, width: CGFloat? = nil) -> UIView {
        UIView.empty(height: height, width: width).then {
            $0.addSubview(self)
            self.edgeAnchors == $0.edgeAnchors
        }
    }
}

extension UIView {
    func addSubview(_ view: UIView, _ closure: (_ make: ConstraintMaker) -> Void) {
        self.addSubview(view)
        view.snp.makeConstraints(closure)
    }
}
