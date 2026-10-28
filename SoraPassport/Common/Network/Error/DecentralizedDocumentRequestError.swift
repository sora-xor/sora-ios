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

enum DecentralizedDocumentQueryDataError: Error {
    case decentralizedIdNotFound

    static func error(from status: StatusData) -> DecentralizedDocumentQueryDataError? {
        switch status.code {
        case "DID_NOT_FOUND":
            return .decentralizedIdNotFound
        default:
            return nil
        }
    }
}

enum DecentralizedDocumentCreationDataError: Error {
    case decentralizedIdTooLong
    case decentralizedIdDuplicated
    case invalidProof
    case proofVerificationFailed
    case publicKeyNotFound

    static func error(from status: StatusData) -> DecentralizedDocumentCreationDataError? {
        switch status.code {
        case "DID_IS_TOO_LONG":
            return .decentralizedIdTooLong
        case "DID_DUPLICATE":
            return .decentralizedIdDuplicated
        case "INVALID_PROOF_SIGNATURE":
            return .proofVerificationFailed
        case "INVALID_PROOF":
            return .invalidProof
        case "PUBLIC_KEY_VALUE_NOT_PRESENTED":
            return .publicKeyNotFound
        default:
            return nil
        }
    }
}
