import UIKit

final class UnsupportedVersionInteractor {
    weak var presenter: UnsupportedVersionInteractorOutputProtocol!
}

extension UnsupportedVersionInteractor: UnsupportedVersionInteractorInputProtocol {}
