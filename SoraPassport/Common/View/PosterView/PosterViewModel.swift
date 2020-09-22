import UIKit

struct PosterLayoutMetadata {
    var itemWidth: CGFloat
    var titleInsets: UIEdgeInsets
    var detailsInsets: UIEdgeInsets
    var contentInsets: UIEdgeInsets
    var titleAttributes: [NSAttributedString.Key: Any]
    var detailsAttributes: [NSAttributedString.Key: Any]
}

struct PosterLayout {
    var itemSize: CGSize
    var titleSize: CGSize
    var detailsSize: CGSize
}

struct PosterContent {
    var title: NSAttributedString
    var details: NSAttributedString
}

protocol PosterViewModelProtocol: class {
    var content: PosterContent { get }
    var layout: PosterLayout { get }
}

final class PosterViewModel: PosterViewModelProtocol {
    var content: PosterContent
    var layout: PosterLayout

    init(content: PosterContent, layout: PosterLayout) {
        self.content = content
        self.layout = layout
    }
}
