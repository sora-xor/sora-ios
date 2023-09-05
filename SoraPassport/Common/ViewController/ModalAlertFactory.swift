// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
