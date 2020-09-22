/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class SoraLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let loadingView = LoadingView(frame: UIScreen.main.bounds,
                                      indicatorImage: R.image.iconLoadingIndicator() ?? UIImage())
        loadingView.backgroundColor = UIColor.loadingBackground
        loadingView.contentBackgroundColor = UIColor.loadingContent
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}
