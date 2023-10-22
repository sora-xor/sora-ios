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
