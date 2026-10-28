// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import SoraKeystore
import XCTest
@testable import SoraPassport

final class SettingsPersistenceBoundaryTests: XCTestCase {
    private let settings = InMemorySettingsManager()
    private func strings() -> [(SettingsKey, (String?) -> Void, () -> String?)] {
        [(.decentralizedId, { self.settings.decentralizedId = $0 }, { self.settings.decentralizedId }),
         (.publicKeyId, { self.settings.publicKeyId = $0 }, { self.settings.publicKeyId }),
         (.invitationCode, { self.settings.invitationCode = $0 }, { self.settings.invitationCode }),
         (.selectedLocalization, { self.settings.selectedLocalization = $0 }, { self.settings.selectedLocalization }),
         (.lastStreamEventId, { self.settings.lastStreamEventId = $0 }, { self.settings.lastStreamEventId }),
         (.streamToken, { self.settings.streamToken = $0 }, { self.settings.streamToken })]
    }
    func testHistoricalStringKeysRemainReadableWithoutMigratingTheirEncoding() {
        for (key, _, read) in strings() {
            settings.set(value: "Legacy value 日本語", for: key.rawValue)
            XCTAssertEqual(read(), "Legacy value 日本語", key.rawValue)
        }
    }
    func testChangingAndClearingStringPreferencesUsesPlainValuesAndRemovesOnlyTheChosenKey() {
        settings.set(value: "retained", for: "unrelated-fixture")
        for (key, write, read) in strings() {
            write("Updated value"); XCTAssertEqual(settings.anyValue(for: key.rawValue) as? String, "Updated value")
            write(""); XCTAssertEqual(read(), ""); XCTAssertTrue(settings.allKeys().contains(key.rawValue))
            write(nil); XCTAssertNil(read()); XCTAssertFalse(settings.allKeys().contains(key.rawValue))
        }
        XCTAssertEqual(settings.string(for: "unrelated-fixture"), "retained")
    }
    func testRegistrationRequiresAnIdentifierAndClearsWhenItIsRemoved() {
        XCTAssertFalse(settings.isRegistered); settings.decentralizedId = "public-identity"; XCTAssertTrue(settings.isRegistered)
        settings.decentralizedId = nil; XCTAssertFalse(settings.isRegistered)
    }
    func testOptionalBooleanPreferencesPreserveTheDifferenceBetweenFalseAndAbsent() {
        let fields: [(SettingsKey, (Bool?) -> Void, () -> Bool?)] = [
            (.biometryEnabled, { self.settings.biometryEnabled = $0 }, { self.settings.biometryEnabled }),
            (.disclaimerHidden, { self.settings.disclaimerHidden = $0 }, { self.settings.disclaimerHidden }),
            (.isCheckedInvitation, { self.settings.isCheckedInvitation = $0 }, { self.settings.isCheckedInvitation })]
        for (key, write, read) in fields {
            XCTAssertNil(read())
            for value in [true, false] { write(value); XCTAssertEqual(read(), value); XCTAssertEqual(settings.anyValue(for: key.rawValue) as? Bool, value) }
            write(nil); XCTAssertNil(read()); XCTAssertFalse(settings.allKeys().contains(key.rawValue))
        }
    }
    func testPinThrottleCoordinatesRemainIntegersAndCanBeIndependentlyCleared() {
        settings.failInputPinCount = 3; settings.inputBlockTimeInterval = 1_800_000_000
        XCTAssertEqual(settings.integer(for: SettingsKey.failInputPinCount.rawValue), 3)
        XCTAssertEqual(settings.integer(for: SettingsKey.inputBlockDate.rawValue), 1_800_000_000)
        settings.failInputPinCount = nil; XCTAssertNil(settings.failInputPinCount); XCTAssertEqual(settings.inputBlockTimeInterval, 1_800_000_000)
        settings.inputBlockTimeInterval = nil; XCTAssertNil(settings.inputBlockTimeInterval)
        XCTAssertFalse(settings.allKeys().contains(SettingsKey.inputBlockDate.rawValue))
    }
    func testMigrationCompletionDefaultsToFalseAndPersistsBothTransitions() {
        XCTAssertFalse(settings.hasMigrated); settings.hasMigrated = true; XCTAssertTrue(settings.hasMigrated)
        settings.hasMigrated = false; XCTAssertFalse(settings.hasMigrated)
        XCTAssertEqual(settings.anyValue(for: SettingsKey.hasMigrated.rawValue) as? Bool, false)
    }
    func testLastSuccessfulEndpointRetainsTheExactURLAndRemovalDoesNotAffectOtherPreferences() {
        let endpoint = URL(string: "wss://node.example.org:9944/path?network=sora")!
        settings.lastSuccessfulUrl = endpoint; XCTAssertEqual(settings.lastSuccessfulUrl, endpoint)
        settings.streamToken = "public-test-token"; settings.lastSuccessfulUrl = nil
        XCTAssertNil(settings.lastSuccessfulUrl); XCTAssertEqual(settings.streamToken, "public-test-token")
    }
}
