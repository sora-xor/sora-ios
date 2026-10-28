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

import Foundation
import LocalAuthentication

public enum AvailableBiometryType {
    case none
    case touchId
    case faceId
}

public protocol BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { get }
    func authenticate(localizedReason: String, completionQueue: DispatchQueue,
                      completionBlock: @escaping (Bool) -> Void)
}

public class BiometryAuth: BiometryAuthProtocol {
    private lazy var context: LAContext = LAContext()

    public var availableBiometryType: AvailableBiometryType {
        let available = context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
        guard available else { return .none }

        switch context.biometryType {
        case .touchID:
            return .touchId
        case .faceID:
            return .faceId
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    public func authenticate(localizedReason: String, completionQueue: DispatchQueue,
                             completionBlock: @escaping (Bool) -> Void) {
        guard availableBiometryType != .none else {
            completionQueue.async {
                completionBlock(false)
            }
            return
        }

        context.evaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: localizedReason) { (result: Bool, _: Error?) -> Void in
            completionQueue.async {
                completionBlock(result)
            }
        }
    }
}
