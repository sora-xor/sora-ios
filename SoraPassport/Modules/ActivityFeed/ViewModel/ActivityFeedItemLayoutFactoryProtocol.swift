/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol ActivityFeedItemLayoutFactoryProtocol: class {
    func createLayout(for content: ActivityFeedItemContent,
                      metadata: ActivityFeedItemLayoutMetadata) -> ActivityFeedItemLayout

    func createLayout(for content: ActivityFeedAmountItemContent,
                      metadata: ActivityFeedAmountItemLayoutMetadata) -> ActivityFeedAmountItemLayout
}

extension ActivityFeedViewModelFactory: ActivityFeedItemLayoutFactoryProtocol {}
