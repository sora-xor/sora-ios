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
import SoraUI
import SoraFoundation

struct ModalAlertFactory {
    static func createSuccessAlert(_ title: String) -> UIViewController {
        return createAlert(title, image: R.image.success())
    }

    static func createAlert(_ title: String, image: UIImage?) -> UIViewController {
        let titleProvider = LocalizableResource { _ in
            title
        }
        return createAlert(titleProvider: titleProvider, image: image)
    }

    static func createAlert(titleProvider: LocalizableResource<String>, image: UIImage?) -> UIViewController {
        let contentView = ImageWithTitleView()
        contentView.iconImage = image
        contentView.title = titleProvider.value(for: LocalizationManager.shared.selectedLocale)
        contentView.spacingBetweenLabelAndIcon = 8.0
        contentView.layoutType = .verticalImageFirst
        contentView.titleColor = R.color.neumorphism.textDark()
        contentView.titleFont = UIFont.styled(for: .paragraph3).withSize(15)

        let contentWidth = contentView.intrinsicContentSize.width + 24.0

        let controller = ImageWithTitleViewController(titleProvider: titleProvider)
        controller.view = contentView

        let preferredSize = CGSize(
            width: max(160.0, contentWidth),
            height: 87.0
        )

        let style = ModalAlertPresentationStyle(
            backgroundColor: R.color.utilityNotification()!,
            backdropColor: .clear,
            cornerRadius: 24.0
        )

        let configuration = ModalAlertPresentationConfiguration(
            style: style,
            preferredSize: preferredSize,
            dismissAfterDelay: 1.5,
            completionFeedback: .success
        )

        controller.modalTransitioningFactory = ModalAlertPresentationFactory(configuration: configuration)
        controller.modalPresentationStyle = .custom

        return controller
    }

}

private class ImageWithTitleViewController: UIViewController, Localizable {

    private let titleProvider: LocalizableResource<String>

    init(titleProvider: LocalizableResource<String>) {
        self.titleProvider = titleProvider
        super.init(nibName: nil, bundle: nil)

        LocalizationManager.shared.addObserver(with: self) { [weak self] (_, selectedLocalization) in
            (self?.view as? ImageWithTitleView)?.title = self?.titleProvider.value(for: Locale(identifier: selectedLocalization)) ?? ""
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
