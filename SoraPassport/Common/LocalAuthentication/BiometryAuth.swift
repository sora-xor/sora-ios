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
import LocalAuthentication
import Security

public enum AvailableBiometryType {
    case none
    case touchId
    case faceId
}

public protocol BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { get }
    /// True only while the faces or fingers enrolled on this iPhone are the set
    /// the owner approved by typing or setting the app PIN.
    var isEnrollmentApproved: Bool { get }
    /// True when a set was approved here and the one enrolled now differs. The
    /// owner has to say yes to it: someone who knows the iPhone passcode can
    /// enroll a face, and typing the PIN as usual must not approve it for them.
    var hasEnrollmentChanged: Bool { get }
    func authenticate(localizedReason: String, completionQueue: DispatchQueue,
                      completionBlock: @escaping (Bool) -> Void)
    /// Approves the faces or fingers enrolled right now. Call only after the
    /// owner set the app PIN or said yes to a changed set.
    func approveCurrentEnrollment()
    /// Approves the set enrolled now only when none was ever approved here: the
    /// first unlock after updating from a version without approvals. Call only
    /// after the owner typed the app PIN.
    func approveFirstEnrollment()
}

public extension BiometryAuthProtocol {
    var isEnrollmentApproved: Bool { true }
    var hasEnrollmentChanged: Bool { false }
    func approveCurrentEnrollment() {}
    func approveFirstEnrollment() {}
}

/// The enrollment set iOS reports for Face ID or Touch ID, as an opaque hash.
public struct BiometryEnrollment: Equatable {
    public let type: AvailableBiometryType
    public let state: Data?

    public init(type: AvailableBiometryType, state: Data?) {
        self.type = type
        self.state = state
    }
}

/// The LocalAuthentication calls BiometryAuth makes, so tests can stand in.
public protocol BiometryPolicyEvaluating {
    /// The current biometry, or nil when biometrics cannot be used now.
    func currentEnrollment() -> BiometryEnrollment?
    /// Shows the system prompt. Reports success and the enrollment set that
    /// produced it.
    func evaluate(localizedReason: String, completion: @escaping (Bool, Data?) -> Void)
}

public final class LocalAuthenticationPolicyEvaluator: BiometryPolicyEvaluating {
    public init() {}

    public func currentEnrollment() -> BiometryEnrollment? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return nil
        }
        let type: AvailableBiometryType
        switch context.biometryType {
        case .touchID:
            type = .touchId
        case .faceID:
            type = .faceId
        default:
            type = .none
        }
        return BiometryEnrollment(type: type, state: Self.enrollmentState(of: context))
    }

    public func evaluate(localizedReason: String, completion: @escaping (Bool, Data?) -> Void) {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: localizedReason) { result, _ in
            completion(result, result ? Self.enrollmentState(of: context) : nil)
        }
    }

    /// Changes whenever a face or finger is added or removed.
    static func enrollmentState(of context: LAContext) -> Data? {
        if #available(iOS 18.0, *) {
            return context.domainState.biometry.stateHash
        }
        return context.evaluatedPolicyDomainState
    }
}

/// Where the approved enrollment set is kept.
public protocol BiometryEnrollmentApprovalStoring {
    func load() -> Data?
    func save(_ state: Data)
}

/// Keeps the approved enrollment hash in a device-only Keychain item. It is a
/// generic password, not a `kSecClassKey` item, so the scans that look for
/// wallet keys never count it, and it never leaves this iPhone in a backup.
public final class KeychainBiometryEnrollmentApprovals: BiometryEnrollmentApprovalStoring {
    static let service = "co.jp.sora.biometry.enrollment"
    static let account = "approved-enrollment-state"

    public init() {}

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
    }

    public func load() -> Data? {
        var query = itemQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    public func save(_ state: Data) {
        let attributes: [String: Any] = [
            kSecValueData as String: state,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(itemQuery as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }
        let item = itemQuery.merging(attributes) { _, new in new }
        SecItemAdd(item as CFDictionary, nil)
    }
}

/// Face ID or Touch ID unlock that works only for the faces or fingers the
/// owner approved with the app PIN. Someone who knows the iPhone passcode can
/// enroll their own face or finger, but that changes the enrollment set, so
/// the app asks for its PIN again before biometrics work.
public class BiometryAuth: BiometryAuthProtocol {
    private let evaluator: BiometryPolicyEvaluating
    private let approvals: BiometryEnrollmentApprovalStoring

    public init(evaluator: BiometryPolicyEvaluating = LocalAuthenticationPolicyEvaluator(),
                approvals: BiometryEnrollmentApprovalStoring = KeychainBiometryEnrollmentApprovals()) {
        self.evaluator = evaluator
        self.approvals = approvals
    }

    public var availableBiometryType: AvailableBiometryType {
        evaluator.currentEnrollment()?.type ?? .none
    }

    public var isEnrollmentApproved: Bool {
        guard let current = evaluator.currentEnrollment(), current.type != .none,
              let state = current.state, let approved = approvals.load() else { return false }
        return state == approved
    }

    public var hasEnrollmentChanged: Bool {
        guard let approved = approvals.load(), let current = evaluator.currentEnrollment(),
              current.type != .none, let state = current.state else { return false }
        return state != approved
    }

    public func authenticate(localizedReason: String, completionQueue: DispatchQueue,
                             completionBlock: @escaping (Bool) -> Void) {
        guard let current = evaluator.currentEnrollment(), current.type != .none,
              let state = current.state, let approved = approvals.load(), state == approved else {
            completionQueue.async {
                completionBlock(false)
            }
            return
        }

        evaluator.evaluate(localizedReason: localizedReason) { result, matchedState in
            // The set can change while the prompt is up. The face or finger
            // that matched must still belong to the approved set.
            let accepted = result && matchedState == approved
            completionQueue.async {
                completionBlock(accepted)
            }
        }
    }

    public func approveCurrentEnrollment() {
        guard let current = evaluator.currentEnrollment(), current.type != .none,
              let state = current.state else { return }
        approvals.save(state)
    }

    public func approveFirstEnrollment() {
        guard approvals.load() == nil else { return }
        approveCurrentEnrollment()
    }
}
