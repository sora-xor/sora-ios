import UIKit

final class ParliamentInteractor {
    weak var presenter: ParliamentInteractorOutputProtocol!
}

extension ParliamentInteractor: ParliamentInteractorInputProtocol {

}
