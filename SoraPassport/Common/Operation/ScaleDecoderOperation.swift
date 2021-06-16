/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils
import RobinHood

final class ScaleDecoderOperation<T: ScaleDecodable>: BaseOperation<T?> {
    var data: Data?

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        guard let data = data else {
            result = .success(nil)
            return
        }

        do {
            let decoder = try ScaleDecoder(data: data)
            let item = try T.init(scaleDecoder: decoder)
            result = .success(item)
        } catch {
            result = .failure(error)
        }
    }
}
