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
import SoraUIKit
import Combine

/// Creation rules for the password of a NEW Google Drive backup or JSON
/// export. Both files are salted scrypt + XSalsa20-Poly1305, so once a file
/// leaks the password is the only defence against offline guessing; the app
/// PIN throttle does not help. Never apply this when decrypting or importing
/// an existing backup or JSON file: those keep accepting the password they
/// were created with.
enum BackupPasswordPolicy {
    enum Violation: Error, Equatable {
        case tooShort
        case repeatedCharacter
        case sequence
        case commonPassword
    }

    /// Counted in characters, ignoring leading and trailing whitespace.
    static let minimumLength = 12

    static func violation(for password: String) -> Violation? {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLength else { return .tooShort }
        let candidate = trimmed.lowercased()
        guard Set(candidate).count > 1 else { return .repeatedCharacter }
        guard !isSequence(candidate) else { return .sequence }
        guard !commonPasswords.contains(candidate) else { return .commonPassword }
        return nil
    }

    static func validate(_ password: String) throws {
        if let violation = violation(for: password) { throw violation }
    }

    /// The text shown under a new-password field: why the password is
    /// refused, or that it meets the requirements when `violation` is nil.
    static func guidance(for violation: Violation?, preferredLanguages: [String]?) -> String {
        switch violation {
        case nil:
            return R.string.localizable.backupPasswordPolicyFulfilled(preferredLanguages: preferredLanguages)
        case .tooShort?:
            return R.string.localizable.backupPasswordPolicyRequirements(preferredLanguages: preferredLanguages)
        case .repeatedCharacter?:
            return R.string.localizable.backupPasswordPolicyRepeated(preferredLanguages: preferredLanguages)
        case .sequence?:
            return R.string.localizable.backupPasswordPolicySequence(preferredLanguages: preferredLanguages)
        case .commonPassword?:
            return R.string.localizable.backupPasswordPolicyCommon(preferredLanguages: preferredLanguages)
        }
    }

    /// 123456789012, abcdefghijkl, 210987654321 and the like: each character
    /// is the next (or each the previous) digit or letter, wrapping 9 to 0
    /// and z to a.
    private static func isSequence(_ candidate: String) -> Bool {
        let characters = Array(candidate)
        return ["0123456789", "abcdefghijklmnopqrstuvwxyz"].contains { letters in
            let alphabet = Array(letters)
            let positions = characters.compactMap { alphabet.firstIndex(of: $0) }
            guard positions.count == characters.count else { return false }
            return [1, alphabet.count - 1].contains { step in
                zip(positions, positions.dropFirst()).allSatisfy {
                    ($1 - $0 + alphabet.count) % alphabet.count == step
                }
            }
        }
    }

    /// The most common breached passwords that would otherwise pass the
    /// length rule (shorter ones are already refused), lowercased.
    private static let commonPasswords: Set<String> = [
        "password1234", "password12345", "password123456", "password123!",
        "passwordpassword", "passw0rd1234", "p@ssw0rd1234", "administrator",
        "qwerty123456", "123456qwerty", "qwertyqwerty", "qwertyuiop123",
        "qwertyuiopasdfghjkl", "qwertyuiopasdfghjklzxcvbnm", "1234567890qwerty",
        "1q2w3e4r5t6y", "q1w2e3r4t5y6", "1q2w3e4r5t6y7u8i9o0p", "1qaz2wsx3edc",
        "1qaz2wsx3edc4rfv", "1qazxsw23edc", "zaq12wsxcde3", "qazwsxedcrfv",
        "qazwsxedcrfvtgbyhn", "123qweasdzxc", "1234qwerasdfzxcv", "asdfghjkl123",
        "zxcvbnm12345", "a1b2c3d4e5f6", "abc123abc123", "abc123456789",
        "abcdef123456", "123456789abc", "123123123123", "123456123456",
        "112233445566", "iloveyou1234", "welcome12345", "letmein12345",
        "changeme1234", "football1234", "baseball1234", "princess1234",
        "sunshine1234", "trustno1trustno1", "!@#$%^&*()_+", "1234567890-=",
    ]
}

final class SetupPasswordItem: NSObject {
    
    var setupPasswordButtonTapped: ((String) -> Void)?
    
    private let output: PassthroughSubject<Output, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    enum Input {
        case passwordChanged(String)
        case confirmPasswordChanged(String)
        case checkViewChanged(Bool)
        case setupPasswordButtonTapped
    }

    enum Output {
        case lowSecurityPassword(BackupPasswordPolicy.Violation)
        case securedPassword
        case notMatchPasswords
        case matchedPasswords
    }
    
    @Published var isButtonEnable: Bool = false
    
    private var password: String = "" {
        didSet {
            validateCurrentState()
        }
    }
    
    private var confirmedPassword: String = "" {
        didSet {
            validateCurrentState()
        }
    }
    
    private var isCheckSelected: Bool = false {
        didSet {
            validateCurrentState()
        }
    }
    
    deinit {
        print("deinit")
    }

    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        cancellables.removeAll()
        password = ""
        confirmedPassword = ""
        isCheckSelected = false
        input.sink { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .passwordChanged(let text): self.password = text
            case .confirmPasswordChanged(let text): self.confirmedPassword = text
            case .checkViewChanged(let isEnabled): self.isCheckSelected = isEnabled
            case .setupPasswordButtonTapped:
                guard self.isButtonEnable else { return }
                self.setupPasswordButtonTapped?(self.password)
            }
        }.store(in: &cancellables)
        return output.eraseToAnyPublisher()
    }
    
    private func validateCurrentState() {
        let violation = BackupPasswordPolicy.violation(for: password)
        isButtonEnable = violation == nil && password == confirmedPassword && isCheckSelected

        if let violation {
            output.send(.lowSecurityPassword(violation))
        } else {
            output.send(.securedPassword)
        }

        if !confirmedPassword.isEmpty {
            output.send(password != confirmedPassword ? .notMatchPasswords : .matchedPasswords)
        }
    }
}

extension SetupPasswordItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        SetupPasswordCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
}
