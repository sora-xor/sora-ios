import Foundation
import UIKit

public struct LinkViewModel {
    public let title: String
    public let link: URL
    public var linkTitle: String
    public var image: UIImage?

    init(title: String, link: URL, linkTitleText: String? = nil, image: UIImage? = nil) {
        self.title = title
        self.link = link
        self.image = image

        if let linkTitleText = linkTitleText {
            self.linkTitle = linkTitleText
        } else {
            self.linkTitle = String(link.path.split(separator: "/").last ?? "")
        }
    }
}
