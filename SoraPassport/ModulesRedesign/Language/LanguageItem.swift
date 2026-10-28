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

import SoraUIKit

final class LanguageItem: NSObject {
    
    static var itemHeight: CGFloat {
        64
    }

    let title: String
    let subtitle: String
    let code: String
    var selected: Bool
    let onTap: (()->())?

    init(code: String, title: String, subtitle: String, selected: Bool = false, onTap: (()->())? = nil) {
        self.code = code
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.onTap = onTap
    }
}

extension LanguageItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        LanguageCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        false
    }
    
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        return LanguageItem.itemHeight
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
