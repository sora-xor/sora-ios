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
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case decentralizedId
    case publicKeyId
    case biometryEnabled
    case disclaimerHidden
    case invitationCode
    case isCheckedInvitation
    case selectedLocalization
    case lastStreamEventId
    case streamToken
    case selectedAccount
    case hasMigrated
    case externalGenesis
    case externalExistentialDeposit
    case externalPrefix
    case assetList
    case inputBlockDate
    case failInputPinCount
    case lastSuccessfulUrl
}

extension SettingsManagerProtocol {
    var hasSelectedAccount: Bool {
        SelectedWalletSettings.shared.hasValue
    }

    var lastSuccessfulUrl: URL? {
        get {
            value(of: URL.self, for: SettingsKey.lastSuccessfulUrl.rawValue)
        }
        set {
            set(value: newValue, for: SettingsKey.lastSuccessfulUrl.rawValue)
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
        return decentralizedId != nil
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
            SelectedWalletSettings.shared.currentAccount?.username
        }
    }

    var inputBlockTimeInterval: Int? {
        get {
            integer(for: SettingsKey.inputBlockDate.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.inputBlockDate.rawValue)
            } else {
                removeValue(for: SettingsKey.inputBlockDate.rawValue)
            }
        }
    }

    var failInputPinCount: Int? {
        get {
            integer(for: SettingsKey.failInputPinCount.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.failInputPinCount.rawValue)
            } else {
                removeValue(for: SettingsKey.failInputPinCount.rawValue)
            }
        }
    }
}
