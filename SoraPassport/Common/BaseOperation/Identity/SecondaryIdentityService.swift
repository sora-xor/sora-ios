/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore

protocol SecondaryIdentityServiceProtocol {
    func createIdentity(using keystore: KeystoreProtocol, skipIfExists: Bool) throws
    func removeIdentitiy(from keystore: KeystoreProtocol) throws
    func copyIdentity(oldKeystore: KeystoreProtocol, newKeystore: KeystoreProtocol) throws
}
