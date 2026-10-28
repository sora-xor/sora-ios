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

public protocol AdaptiveDesignable {
    var baseDesignSize: CGSize { get }
    var designScaleRatio: CGSize { get }
    var isAdaptiveHeightDecreased: Bool { get }
    var isAdaptiveHeightIncreased: Bool { get }
    var isAdaptiveWidthDecreased: Bool { get }
    var isAdaptiveWidthIncreased: Bool { get }
}

extension AdaptiveDesignable {
    public var baseDesignSize: CGSize {
        return CGSize(width: 375, height: 667)
    }

    public var designScaleRatio: CGSize {
        let screenBounds = UIScreen.main.bounds
        return CGSize(width: screenBounds.width / baseDesignSize.width,
                      height: screenBounds.height / baseDesignSize.height)
    }

    public var isAdaptiveHeightDecreased: Bool {
        return designScaleRatio.height < 1.0
    }

    public var isAdaptiveHeightIncreased: Bool {
        return designScaleRatio.height > 1.0
    }

    public var isAdaptiveWidthDecreased: Bool {
        return designScaleRatio.width < 1.0
    }

    public var isAdaptiveWidthIncreased: Bool {
        return designScaleRatio.width > 1.0
    }
}
