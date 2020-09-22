/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
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
    case invitationCode
    case isCheckedInvitation
    case selectedLocalization
    case lastStreamEventId
    case streamToken
}

extension SettingsManagerProtocol {
    var isRegistered: Bool {
        return decentralizedId != nil && verificationState == nil
    }

    var decentralizedId: String? {
        get {
            return string(for: SettingsKey.decentralizedId.rawValue)
        }

        set {
            if let exisingValue = newValue {
                set(value: exisingValue, for: SettingsKey.decentralizedId.rawValue)
            } else {
                removeValue(for: SettingsKey.decentralizedId.rawValue)
            }
        }
    }

    var publicKeyId: String? {
        get {
            string(for: SettingsKey.publicKeyId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.publicKeyId.rawValue)
            } else {
                removeValue(for: SettingsKey.publicKeyId.rawValue)
            }
        }
    }

    var biometryEnabled: Bool? {
        get {
            bool(for: SettingsKey.biometryEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }
    }

    var verificationState: VerificationState? {
        get {
            value(of: VerificationState.self, for: SettingsKey.verificationState.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.verificationState.rawValue)
            } else {
                removeValue(for: SettingsKey.verificationState.rawValue)
            }
        }
    }

    var hasVerificationState: Bool {
        return data(for: SettingsKey.verificationState.rawValue) != nil
    }

    var invitationCode: String? {
        get {
            string(for: SettingsKey.invitationCode.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.invitationCode.rawValue)
            } else {
                removeValue(for: SettingsKey.invitationCode.rawValue)
            }
        }
    }

    var isCheckedInvitation: Bool? {
        get {
            bool(for: SettingsKey.isCheckedInvitation.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.isCheckedInvitation.rawValue)
            } else {
                removeValue(for: SettingsKey.isCheckedInvitation.rawValue)
            }
        }
    }

    var selectedLocalization: String? {
        get {
            string(for: SettingsKey.selectedLocalization.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.selectedLocalization.rawValue)
            } else {
                removeValue(for: SettingsKey.selectedLocalization.rawValue)
            }
        }
    }

    var lastStreamEventId: String? {
        get {
            string(for: SettingsKey.lastStreamEventId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.lastStreamEventId.rawValue)
            } else {
                removeValue(for: SettingsKey.lastStreamEventId.rawValue)
            }
        }
    }

    var streamToken: String? {
        get {
            string(for: SettingsKey.streamToken.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.streamToken.rawValue)
            } else {
                removeValue(for: SettingsKey.streamToken.rawValue)
            }
        }
    }
}
