/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import RobinHood

enum ActivityFeedViewState {
    case data
    case loading
    case empty
}

typealias ActivityFeedViewModelChange =
    SectionedListDifference<ActivityFeedSectionViewModel, ActivityFeedOneOfItemViewModel>

typealias ActivityFeedStateChange = (state: ActivityFeedViewState, changes: [ActivityFeedViewModelChange])

protocol ActivityFeedHeaderLayoutContainable {
    var iconSize: CGSize { get }
    var typeSize: CGSize { get }
    var timestampSize: CGSize { get }
}

extension ActivityFeedHeaderLayoutContainable {
    var itemHeaderHeight: CGFloat {
        return max(max(iconSize.height, typeSize.height), timestampSize.height)
    }
}

struct ActivityFeedItemLayout: Withable, ActivityFeedHeaderLayoutContainable {
    var itemSize: CGSize = .zero
    var iconSize: CGSize = .zero
    var typeSize: CGSize = .zero
    var timestampSize: CGSize = .zero
    var titleSize: CGSize = .zero
    var detailsSize: CGSize = .zero
}

struct ActivityFeedAmountItemLayout: Withable, ActivityFeedHeaderLayoutContainable {
    var itemSize: CGSize = .zero
    var iconSize: CGSize = .zero
    var typeSize: CGSize = .zero
    var timestampSize: CGSize = .zero
    var detailsSize: CGSize = .zero
    var amountStateIconSize: CGSize = .zero
    var amountTextSize: CGSize = .zero
    var amountSymbolSize: CGSize = .zero
}

struct ActivityFeedItemContent: Withable {
    var icon: UIImage?
    var type: String = ""
    var timestamp: String = ""
    var title: String?
    var details: String?
}

struct ActivityFeedAmountItemContent: Withable {
    var icon: UIImage?
    var type: String = ""
    var timestamp: String = ""
    var details: String = ""
    var amountStateIcon: UIImage?
    var amountText: String = ""
    var amountSymbolIcon: UIImage?
}

protocol ActivityFeedItemViewModelProtocol: class {
    var content: ActivityFeedItemContent { get }
    var layout: ActivityFeedItemLayout { get }
}

final class ActivityFeedItemViewModel: ActivityFeedItemViewModelProtocol {
    var content: ActivityFeedItemContent
    var layout: ActivityFeedItemLayout

    init(content: ActivityFeedItemContent, layout: ActivityFeedItemLayout) {
        self.content = content
        self.layout = layout
    }
}

protocol ActivityFeedAmountItemViewModelProtocol: class {
    var content: ActivityFeedAmountItemContent { get }
    var layout: ActivityFeedAmountItemLayout { get }
}

final class ActivityFeedAmountItemViewModel: ActivityFeedAmountItemViewModelProtocol {
    var content: ActivityFeedAmountItemContent
    var layout: ActivityFeedAmountItemLayout

    init(content: ActivityFeedAmountItemContent, layout: ActivityFeedAmountItemLayout) {
        self.content = content
        self.layout = layout
    }
}

enum ActivityFeedOneOfItemViewModel {
    case basic(concreteViewModel: ActivityFeedItemViewModelProtocol)
    case amount(concreteViewModel: ActivityFeedAmountItemViewModelProtocol)
}

protocol ActivityFeedSectionViewModelProtocol: class {
    var title: String { get }
    var items: [ActivityFeedOneOfItemViewModel] { get }
}

final class ActivityFeedSectionViewModel: ActivityFeedSectionViewModelProtocol {
    var title: String
    var items: [ActivityFeedOneOfItemViewModel]

    init(title: String, items: [ActivityFeedOneOfItemViewModel]) {
        self.title = title
        self.items = items
    }
}
