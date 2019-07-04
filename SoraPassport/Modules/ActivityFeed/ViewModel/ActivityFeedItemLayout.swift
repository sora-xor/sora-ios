/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

struct ActivityFeedItemLayoutMetadata: Withable {
    var itemWidth: CGFloat = 338.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
    var iconTypeSpacing: CGFloat = 10.0
    var typeTimestampSpacing: CGFloat = 10.0
    var titleTopSpacing: CGFloat = 15.0
    var detailsTopSpacing: CGFloat = 8.0

    var typeFont: UIFont = UIFont.activityType
    var titleFont: UIFont = UIFont.activityTitle
    var detailsFont: UIFont = UIFont.activityDetails
    var timestampFont: UIFont = UIFont.activityTimestamp

    var drawingOptions: NSStringDrawingOptions = .usesLineFragmentOrigin
}

struct ActivityFeedAmountItemLayoutMetadata: Withable {
    var itemWidth: CGFloat = 338.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
    var iconTypeSpacing: CGFloat = 10.0
    var typeTimestampSpacing: CGFloat = 10.0
    var detailsTopSpacing: CGFloat = 15.0
    var detailsAmountSpacing: CGFloat = 8.0
    var amountStateIconTexSpacing: CGFloat = 6.0
    var amountTexSymbolSpacing: CGFloat = 4.0

    var typeFont: UIFont = UIFont.activityType
    var timestampFont: UIFont = UIFont.activityTimestamp
    var detailsFont: UIFont = UIFont.activityDetails
    var amountFont: UIFont = UIFont.activityAmount

    var drawingOptions: NSStringDrawingOptions = .usesLineFragmentOrigin
}
