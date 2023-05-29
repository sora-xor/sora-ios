import UIKit
import SoraUI

final class SoraLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let loadingView = LoadingView(frame: UIScreen.main.bounds,
                                      indicatorImage: R.image.iconLoadingIndicator() ?? UIImage())
        loadingView.backgroundColor = R.color.baseBackgroundHover()!
        loadingView.contentBackgroundColor = R.color.baseContentQuaternary()!
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}
