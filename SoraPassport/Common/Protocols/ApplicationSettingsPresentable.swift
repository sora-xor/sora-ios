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

protocol ApplicationSettingsPresentable {
    func askOpenApplicationSettings(with message: String,
                                   title: String?,
                                   from view: ControllerBackedProtocol?,
                                   locale: Locale?)
}

extension ApplicationSettingsPresentable {
    func askOpenApplicationSettings(with message: String,
                                   title: String?,
                                   from view: ControllerBackedProtocol?,
                                   locale: Locale?) {
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let closeTitle = R.string.localizable.notNow(preferredLanguages: locale?.rLanguages)
        let closeAction = UIAlertAction(title: closeTitle, style: .cancel, handler: nil)

        let settingsTitle = R.string.localizable.goSettings(preferredLanguages: locale?.rLanguages)
        let settingsAction = UIAlertAction(title: settingsTitle, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        alert.addAction(closeAction)
        alert.addAction(settingsAction)

        controller.present(alert, animated: true, completion: nil)
    }
}
