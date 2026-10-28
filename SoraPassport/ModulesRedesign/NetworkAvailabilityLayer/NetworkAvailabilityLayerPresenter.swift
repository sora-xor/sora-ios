// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SoraFoundation

final class NetworkAvailabilityLayerPresenter {
    var view: ApplicationStatusPresentable!
    weak var interactor: NetworkAvailabilityLayerInteractorInputProtocol!

    var unavailbleStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: R.color.statusError()!,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.styled(for: .paragraph3))
    }

    var availableStyle: ApplicationStatusStyle {
        return ApplicationStatusStyle(backgroundColor: R.color.statusWarningBackground()!,
                                      titleColor: UIColor.white,
                                      titleFont: UIFont.styled(for: .paragraph3))
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {

    func didDecideUnreachableNodesAllertPresentation() {

        let languages = localizationManager?.preferredLocalizations
        let alert = UIAlertController(
            title: R.string.localizable.nodeOffline(preferredLanguages: languages),
            message: R.string.localizable.nodeConnectionIssue(preferredLanguages: languages),
            preferredStyle: .alert
        )
        alert.addAction(.init(title: R.string.localizable.commonClose(preferredLanguages: languages), style: .cancel))

        view.presentAlert(alert: alert, animated: true)
    }

    func didDecideUnreachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.presentStatus(title: R.string.localizable
            .networkUnavailable(preferredLanguages: languages),
                           style: unavailbleStyle,
                           animated: true)
    }

    func didDecideReachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.dismissStatus(title: R.string.localizable
            .networkAvailable(preferredLanguages: languages),
                           style: availableStyle,
                           animated: true)
    }
}

extension NetworkAvailabilityLayerPresenter: Localizable {
    func applyLocalization() {}
}
