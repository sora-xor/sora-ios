import UIKit

protocol TutorialViewModelProtocol: class {
    var details: String { get }
    var image: UIImage { get }
}

final class TutorialViewModel: TutorialViewModelProtocol {
    var details: String
    var imageName: String

    var image: UIImage {
        return UIImage(named: imageName)!
    }

    init(details: String, imageName: String) {
        self.details = details
        self.imageName = imageName
    }
}
