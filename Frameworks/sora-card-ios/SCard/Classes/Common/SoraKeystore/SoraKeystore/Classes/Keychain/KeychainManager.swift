/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public class KeychainManager {
    public static let shared: KeychainManager = KeychainManager()
    fileprivate static let queueLabel = "keychain.concurrent"

    fileprivate lazy var concurentQueue: DispatchQueue = DispatchQueue(label: KeychainManager.queueLabel,
                                                                   qos: .default,
                                                                   attributes: .concurrent)
    fileprivate lazy var keystore: Keychain = Keychain()

    private init() {}
}

extension KeychainManager: SecretStoreManagerProtocol {
    func loadSecret(for identifier: String,
                           completionQueue: DispatchQueue,
                           completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
        concurentQueue.async {
            let data = try? self.keystore.fetchKey(for: identifier)

            completionQueue.async {
                completionBlock(data)
            }
        }
    }

    func saveSecret(_ secret: SecretDataRepresentable,
                           for identifier: String,
                           completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        concurentQueue.async {
            guard let secretExists = try? self.keystore.checkKey(for: identifier) else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            guard let secretData = secret.asSecretData() else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            do {
                if !secretExists {
                    try self.keystore.addKey(secretData, with: identifier)
                } else {
                    try self.keystore.updateKey(secretData, with: identifier)
                }

                completionQueue.async {
                    completionBlock(true)
                }

            } catch {
                completionQueue.async {
                    completionBlock(false)
                }
            }
        }
    }

    public func removeSecret(for identifier: String,
                             completionQueue: DispatchQueue,
                             completionBlock: @escaping (Bool) -> Void) {
        concurentQueue.async {
            guard let secretExists = try? self.keystore.checkKey(for: identifier), secretExists else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            do {
                try self.keystore.deleteKey(for: identifier)

                completionQueue.async {
                    completionBlock(true)
                }

            } catch {
                completionQueue.async {
                    completionBlock(false)
                }
            }
        }
    }

    public func checkSecret(for identifier: String,
                            completionQueue: DispatchQueue,
                            completionBlock: @escaping (Bool) -> Void) {
        concurentQueue.async {
            let result = self.checkSecret(for: identifier)

            completionQueue.async {
                completionBlock(result)
            }
        }
    }

    public func checkSecret(for identifier: String) -> Bool {
        return (try? self.keystore.checkKey(for: identifier)) ?? false
    }
}
