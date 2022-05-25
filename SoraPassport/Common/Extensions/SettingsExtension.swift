import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case decentralizedId
    case publicKeyId
    case biometryEnabled
    case disclaimerHidden
    case verificationState
    case selectedCurrency
    case invitationCode
    case isCheckedInvitation
    case selectedLocalization
    case lastStreamEventId
    case streamToken
    case userName
    case selectedAccount
    case selectedConnection
    case hasMigrated
    case externalGenesis
    case externalExistentialDeposit
    case externalPrefix
    case assetList
}

extension SettingsManagerProtocol {
    var hasSelectedAccount: Bool {
        selectedAccount != nil
    }

    var selectedAccount: AccountItem? {
        get {
            value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)
        }

        set {
            if let newValue = newValue {
                set(value: newValue, for: SettingsKey.selectedAccount.rawValue)
            } else {
                removeValue(for: SettingsKey.selectedAccount.rawValue)
            }
        }
    }

    var selectedConnection: ConnectionItem {
        get { //while we're on single network
//            if let nodeItem = value(of: ConnectionItem.self, for: SettingsKey.selectedConnection.rawValue) {
//                return nodeItem
//            } else {
                return .defaultConnection
//            }
        }

        set {
            set(value: newValue, for: SettingsKey.selectedConnection.rawValue)
        }
    }

    var externalGenesis: String? {
        get {
            if let value = string(for: SettingsKey.externalGenesis.rawValue) {
                return value
            }
            return nil
        }

        set {
            set(value: newValue, for: SettingsKey.externalGenesis.rawValue)
        }
    }

    var externalExistentialDeposit: UInt? {
        get {
            if let value = integer(for: SettingsKey.externalExistentialDeposit.rawValue) {
                return UInt(value)
            }
            return nil
        }

        set {
            set(value: newValue, for: SettingsKey.externalExistentialDeposit.rawValue)
        }
    }

    var externalAddressPrefix: UInt? {
        get {
            if let value = integer(for: SettingsKey.externalPrefix.rawValue), value != 0 {
                return UInt(value)
            }
            return 69
        }

        set {
            set(value: newValue, for: SettingsKey.externalPrefix.rawValue)
        }
    }

    var hasMigrated: Bool {
        get {
            if let value = bool(for: SettingsKey.hasMigrated.rawValue) {
                return value
            }
            return false
        }
        set {
            set(value: newValue, for: SettingsKey.hasMigrated.rawValue)
        }
    }

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

    var disclaimerHidden: Bool? {
        get {
            bool(for: SettingsKey.disclaimerHidden.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.disclaimerHidden.rawValue)
            } else {
                removeValue(for: SettingsKey.disclaimerHidden.rawValue)
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

    var userName: String? {
        get {
            selectedAccount?.username ?? string(for: SettingsKey.userName.rawValue)
        }
    }
}
