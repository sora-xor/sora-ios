/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

enum CommandError: Error {
    case invalidAssetId
    case noAssets
    case notEligibleAsset
    case invalidOptionId
}
