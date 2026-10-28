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
import SoraUI

final class EmptyStateListViewModel: EmptyStateListViewModelProtocol {
    static let cellIdentifier: String = "emptyStateCellId"

    private(set) var displayInsetsForEmptyState: UIEdgeInsets

    private(set) var emptyStateView: UIView

    init(image: UIImage?, title: String?, spacing: CGFloat, displayInsets: UIEdgeInsets) {
        self.displayInsetsForEmptyState = displayInsets

        let emptyStateView = EmptyStateView()
        emptyStateView.image = image
        emptyStateView.title = title
        emptyStateView.titleColor = R.color.baseContentPrimary()!
        emptyStateView.titleFont = UIFont.styled(for: .paragraph3)
        emptyStateView.trimStrategy = .hideTitle
        emptyStateView.verticalSpacing = spacing

        self.emptyStateView = emptyStateView
    }
}
