import UIKit
import SoraUI

final class SoraLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let loadingView = LoadingView(frame: UIScreen.main.bounds,
                                      indicatorImage: R.image.iconLoadingIndicator() ?? UIImage())
        loadingView.backgroundColor = .clear
        loadingView.contentBackgroundColor = .lightGray
        loadingView.contentSize = CGSize(width: 30.0, height: 30.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}
