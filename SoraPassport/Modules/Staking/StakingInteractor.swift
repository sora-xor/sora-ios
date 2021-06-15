import UIKit

final class StakingInteractor {
    weak var presenter: StakingInteractorOutputProtocol!
}

extension StakingInteractor: StakingInteractorInputProtocol {

}
