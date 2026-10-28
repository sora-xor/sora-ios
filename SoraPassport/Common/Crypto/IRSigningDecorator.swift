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
import SoraKeystore
import IrohaCrypto

class IRSigningDecorator {
    var keystore: KeystoreProtocol
    var identifier: String

    var logger: LoggerProtocol?

    init(keystore: KeystoreProtocol, identifier: String) {
        self.keystore = keystore
        self.identifier = identifier
    }
}

extension IRSigningDecorator: IRSignatureCreatorProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        guard
            let lifecycleLease =
                try WalletLifecycleCoordinator.shared
                    .tryAcquireForMutableWalletAccess()
        else {
            throw WalletNetworkMigrationError.lifecycleMutationBusy
        }
        defer { lifecycleLease.release() }
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        let rawKey = try keystore.fetchKey(for: identifier)

        let privateKey = try IRIrohaPrivateKey(rawData: rawKey)

        let rawSigner = IRIrohaSigner(privateKey: privateKey)

        return try rawSigner.sign(originalData)
    }

    func sign(_ originalData: Data, privateKey: IRPrivateKeyProtocol) throws -> IRSignatureProtocol {
        guard
            let lifecycleLease =
                try WalletLifecycleCoordinator.shared
                    .tryAcquireForMutableWalletAccess()
        else {
            throw WalletNetworkMigrationError.lifecycleMutationBusy
        }
        defer { lifecycleLease.release() }
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        let rawSigner = IRIrohaSigner(privateKey: privateKey)

        return try rawSigner.sign(originalData)
    }
}
