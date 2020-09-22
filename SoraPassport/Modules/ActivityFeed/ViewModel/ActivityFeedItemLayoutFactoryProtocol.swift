import Foundation

protocol ActivityFeedItemLayoutFactoryProtocol: class {
    func createLayout(for content: ActivityFeedItemContent,
                      metadata: ActivityFeedItemLayoutMetadata) -> ActivityFeedItemLayout

    func createLayout(for content: ActivityFeedAmountItemContent,
                      metadata: ActivityFeedAmountItemLayoutMetadata) -> ActivityFeedAmountItemLayout
}

extension ActivityFeedViewModelFactory: ActivityFeedItemLayoutFactoryProtocol {}
