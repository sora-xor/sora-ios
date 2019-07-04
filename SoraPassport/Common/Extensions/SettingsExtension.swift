/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case decentralizedId
    case publicKeyId
    case biometryEnabled
    case verificationState
    case selectedCurrency
}

extension SettingsManagerProtocol {
    var decentralizedId: String? {
        set {
            if let exisingValue = newValue {
                set(value: exisingValue, for: SettingsKey.decentralizedId.rawValue)
            } else {
                removeValue(for: SettingsKey.decentralizedId.rawValue)
            }
        }

        get {
            return string(for: SettingsKey.decentralizedId.rawValue)
        }
    }

    var publicKeyId: String? {
        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.publicKeyId.rawValue)
            } else {
                removeValue(for: SettingsKey.publicKeyId.rawValue)
            }
        }

        get {
            return string(for: SettingsKey.publicKeyId.rawValue)
        }
    }

    var biometryEnabled: Bool? {
        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }

        get {
            return bool(for: SettingsKey.biometryEnabled.rawValue)
        }
    }

    var verificationState: VerificationState? {
        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.verificationState.rawValue)
            } else {
                removeValue(for: SettingsKey.verificationState.rawValue)
            }
        }

        get {
            return value(of: VerificationState.self, for: SettingsKey.verificationState.rawValue)
        }
    }

    var hasVerificationState: Bool {
        return data(for: SettingsKey.verificationState.rawValue) != nil
    }
}
