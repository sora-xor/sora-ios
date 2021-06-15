import UIKit

protocol PosterViewFactoryProtocol {
    static func createView(from contentInsets: UIEdgeInsets,
                           preferredWidth: CGFloat) -> PosterView?

    static func createLayoutMetadata(from contentInsets: UIEdgeInsets,
                                     preferredWidth: CGFloat) -> PosterLayoutMetadata
}
