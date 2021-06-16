/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils

extension StorageUpdateData {
    func decodeUpdatedData<V: ScaleDecodable>(for key: String) throws -> V? {
        let keyData = try Data(hexString: key)

        guard let value = changes.first(where: { $0.key == keyData })?.value else {
            return nil
        }

        let scaleDecoder = try ScaleDecoder(data: value)

        return try V(scaleDecoder: scaleDecoder)
    }
}
