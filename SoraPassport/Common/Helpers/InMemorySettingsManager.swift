/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore

final class InMemorySettingsManager: SettingsManagerProtocol {
    private var settings: [String: Any] = [:]

    func set(value: Bool, for key: String) {
        settings[key] = value
    }

    func bool(for key: String) -> Bool? {
        return settings[key] as? Bool
    }

    func set(value: Int, for key: String) {
        settings[key] = value
    }

    func integer(for key: String) -> Int? {
        return settings[key] as? Int
    }

    func set(value: Double, for key: String) {
        settings[key] = value
    }

    func double(for key: String) -> Double? {
        return settings[key] as? Double
    }

    func set(value: String, for key: String) {
        settings[key] = value
    }

    func string(for key: String) -> String? {
        return settings[key] as? String
    }

    func set(value: Data, for key: String) {
        settings[key] = value
    }

    func data(for key: String) -> Data? {
        return settings[key] as? Data
    }

    func removeValue(for key: String) {
        settings[key] = nil
    }

    func removeAll() {
        settings.removeAll()
    }
}
