import Foundation
import SoraUI

final class SoraLoadingViewPresenter: LoadingViewPresenter {
    static let shared = SoraLoadingViewPresenter(factory: SoraLoadingViewFactory.self)

    override private init(factory: LoadingViewFactoryProtocol.Type) {
        super.init(factory: factory)
    }
}
