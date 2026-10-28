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

final class AccountMenuItem: NSObject {
    
    static var itemHeight: CGFloat {
        72
    }
    
    let title: String
    let image: UIImage?
    var capabilityBadge: String?
    var isSelected: Bool
    var isMultiselectionMode: Bool
    let onTap: (() -> ())?
    let onMore: (() -> ())?
    
    init(title: String,
         image: UIImage?,
         isSelected: Bool,
         isMultiselectionMode: Bool,
         onTap: (()->())? = nil,
         onMore: (()->())? = nil) {
        self.title = title
        self.image = image
        self.isSelected = isSelected
        self.isMultiselectionMode = isMultiselectionMode
        self.onTap = onTap
        self.onMore = onMore
    }
    
}

extension AccountMenuItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        AccountTableViewCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        false
    }
    
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        guard let badge = capabilityBadge, !badge.isEmpty else { return AccountMenuItem.itemHeight }
        // Account titles and the capability badge share a vertical stack. The
        // badge must remain readable at accessibility sizes and in long locales.
        // The table passes its full width. AccountTableViewCell also insets
        // this view by 24 points on each side, outside the view's controls.
        let labelWidth = max(1, width - 48 - (image == nil ? 109 : 149))
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        let badgeHeight = (badge as NSString).boundingRect(
            with: CGSize(width: labelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil).height
        let titleHeight = FontType.textM.attriburedString(with: title).size().height
        return max(AccountMenuItem.itemHeight, ceil(titleHeight + 3 + badgeHeight + 32))
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
    
    func itemActionMore(with context: SoramitsuTableViewContext?) {
        onMore?()
    }
}
