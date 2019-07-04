/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

struct SupportViewStyle {
    static var topBackgroundColor: UIColor {
        return UIColor(red: 28.0 / 255.0,
                       green: 80.0 / 255.0,
                       blue: 78.0 / 255.0,
                       alpha: 1.0)
    }

    static var bottomBackgroundColor: UIColor {
        return UIColor.white
    }

    static var shadowColor: UIColor {
        return UIColor(red: 124.0 / 255.0,
                       green: 158.0 / 255.0,
                       blue: 168.0 / 255.0,
                       alpha: 0.25)
    }

    static var highlightColor: UIColor {
        return UIColor(red: 208.0 / 255.0,
                       green: 2.0 / 255.0,
                       blue: 27.0 / 255.0,
                       alpha: 1.0)
    }

    static var titleColor: UIColor {
        return UIColor.white
    }

    static var detailsColor: UIColor {
        return UIColor.black
    }

    static var titleFont: UIFont {
        return R.font.soraRc0040417SemiBold(size: 13)!
    }

    static var detailsFont: UIFont {
        return R.font.soraRc0040417Regular(size: 14)!
    }
}

final class SupportViewFactory: PosterViewFactoryProtocol {
    static func createView(from contentInsets: UIEdgeInsets,
                           preferredWidth: CGFloat) -> PosterView? {
        guard
            let posterView = UINib(resource: R.nib.posterView)
                .instantiate(withOwner: nil, options: nil).first as? PosterView else {
                    return nil
        }

        let metadata = createLayoutMetadata(from: contentInsets, preferredWidth: preferredWidth)

        posterView.contentInsets = metadata.contentInsets
        posterView.titleInsets = metadata.titleInsets
        posterView.detailsInsets = metadata.detailsInsets

        posterView.topRoundedView.fillColor = SupportViewStyle.topBackgroundColor
        posterView.topRoundedView.cornerRadius = 10.0

        posterView.bottomRoundedView.fillColor = SupportViewStyle.bottomBackgroundColor
        posterView.bottomRoundedView.cornerRadius = 10.0
        posterView.bottomRoundedView.shadowOpacity = 1.0
        posterView.bottomRoundedView.shadowColor = SupportViewStyle.shadowColor
        posterView.bottomRoundedView.shadowOffset = CGSize(width: 0.0, height: 3.0)
        posterView.bottomRoundedView.shadowRadius = 2.5

        return posterView
    }

    static func createLayoutMetadata(from contentInsets: UIEdgeInsets,
                                     preferredWidth: CGFloat) -> PosterLayoutMetadata {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: SupportViewStyle.titleColor,
            .font: SupportViewStyle.titleFont
        ]

        let detailsAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: SupportViewStyle.detailsColor,
            .font: SupportViewStyle.detailsFont
        ]

        return PosterLayoutMetadata(itemWidth: preferredWidth,
                                    titleInsets: UIEdgeInsets(top: 13.0, left: 20.0, bottom: 10.0, right: 20.0),
                                    detailsInsets: UIEdgeInsets(top: 18.0, left: 20.0, bottom: 20.0, right: 20.0),
                                    contentInsets: contentInsets,
                                    titleAttributes: titleAttributes,
                                    detailsAttributes: detailsAttributes)
    }
}
