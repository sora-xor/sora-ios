import UIKit

protocol PosterViewModelFactoryProtocol: class {
    func createViewModel(from title: String,
                         details: String,
                         layoutMetadata: PosterLayoutMetadata) -> PosterViewModelProtocol
}

class PosterViewModelFactory: PosterViewModelFactoryProtocol {
    let detailsDecorator: AttributedStringDecoratorProtocol?

    init(detailsDecorator: AttributedStringDecoratorProtocol? = nil) {
        self.detailsDecorator = detailsDecorator
    }

    func createViewModel(from title: String,
                         details: String,
                         layoutMetadata: PosterLayoutMetadata) -> PosterViewModelProtocol {

        let titleAttributedString = NSAttributedString(string: title,
                                                       attributes: layoutMetadata.titleAttributes)
        var detailsAttributedString = NSAttributedString(string: details,
                                                        attributes: layoutMetadata.detailsAttributes)

        if let decorator = detailsDecorator {
            detailsAttributedString = decorator.decorate(attributedString: detailsAttributedString)
        }

        let boundingWidth = layoutMetadata.itemWidth - layoutMetadata.contentInsets.left
            - layoutMetadata.contentInsets.right

        let titleBoundingWidth = boundingWidth - layoutMetadata.titleInsets.left
            - layoutMetadata.titleInsets.right

        let detailsBoundingWidth = boundingWidth - layoutMetadata.detailsInsets.left
            - layoutMetadata.detailsInsets.right

        var itemSize = CGSize(width: layoutMetadata.itemWidth,
                              height: layoutMetadata.contentInsets.top + layoutMetadata.contentInsets.bottom)

        let titleBoundingSize = CGSize(width: titleBoundingWidth,
                                       height: CGFloat.greatestFiniteMagnitude)

        let titleSize = titleAttributedString
            .boundingRect(with: titleBoundingSize,
                          options: .usesLineFragmentOrigin,
                          context: nil).size

        let detailsBoundingSize = CGSize(width: detailsBoundingWidth,
                                         height: CGFloat.greatestFiniteMagnitude)

        let detailsSize = detailsAttributedString
            .boundingRect(with: detailsBoundingSize,
                          options: .usesLineFragmentOrigin,
                          context: nil).size

        itemSize.height += layoutMetadata.titleInsets.top + titleSize.height
            + layoutMetadata.titleInsets.bottom
        itemSize.height += layoutMetadata.detailsInsets.top + detailsSize.height
            + layoutMetadata.detailsInsets.bottom

        let layout = PosterLayout(itemSize: itemSize,
                                  titleSize: titleSize,
                                  detailsSize: detailsSize)

        let content = PosterContent(title: titleAttributedString,
                                    details: detailsAttributedString)

        return PosterViewModel(content: content,
                               layout: layout)
    }
}
