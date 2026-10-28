// SPDX-License-Identifier: Apache-2.0
import Foundation
import IrohaCrypto
import SSFUtils
import SoraKeystore
import XCTest

@testable import SoraPassport

/// Signs a fixed, non-transaction message with public synthetic fixture keys.
/// All keys, selection, ownership state, and lifecycle locks are isolated.
final class LocalSigningIdentityFlowTests: XCTestCase {
  private let message = Data("SORA offline regression fixture; not a transaction".utf8)
  private func make(_ type: CryptoType = .sr25519, path: String = "") throws -> LocalSignerFixture {
    try LocalSignerFixture(type: type, path: path)
  }
  private func reject(
    _ f: LocalSignerFixture, _ error: SigningWrapperError, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try f.signer.sign(message), file: file, line: line) {
      XCTAssertEqual($0 as? SigningWrapperError, error, file: file, line: line)
    }
  }
  private func verify(_ f: LocalSignerFixture, file: StaticString = #filePath, line: UInt = #line)
    throws
  {
    let before = try f.keys.snapshot()
    let signature = try f.signer.sign(message)
    let secret = try XCTUnwrap(
      LegacySoraSecretResolver.resolve(account: f.account, keystore: f.keys, recoveryGate: f.gate))
    XCTAssertNoThrow(
      try Sora2SignatureVerifier.verify(
        signature: signature, originalData: message, secretKey: secret, account: f.account),
      file: file, line: line)
    XCTAssertEqual(try f.keys.snapshot(), before, file: file, line: line)
  }
  func testSr25519SignsAndVerifiesWithoutChangingStoredMaterial() throws { try verify(make()) }
  func testEd25519SignsAndVerifiesWithoutChangingStoredMaterial() throws {
    try verify(make(.ed25519))
  }
  func testEcdsaSignsAndVerifiesWithoutChangingStoredMaterial() throws { try verify(make(.ecdsa)) }
  func testDerivedSr25519SignsTheExistingAddress() throws {
    try verify(make(.sr25519, path: "//fixture"))
  }
  func testDerivedEd25519SignsTheExistingAddress() throws {
    try verify(make(.ed25519, path: "//fixture"))
  }
  func testDerivedEcdsaSignsTheExistingAddress() throws {
    try verify(make(.ecdsa, path: "//fixture"))
  }
  func testEntropyOnlySr25519AccountSignsWithoutWritingFallbackKeys() throws {
    let f = try make()
    try f.keys.deleteKey(for: KeystoreTag.secretKeyTagForAddress(f.account.address))
    try f.keys.deleteKey(for: KeystoreTag.seedTagForAddress(f.account.address))
    try verify(f)
  }
  func testSeedOnlyEd25519AccountSignsWithoutWritingFallbackKeys() throws {
    let f = try make(.ed25519)
    try f.keys.deleteKey(for: KeystoreTag.secretKeyTagForAddress(f.account.address))
    try f.keys.deleteKey(for: KeystoreTag.entropyTagForAddress(f.account.address))
    try verify(f)
  }
  func testEntropyOnlyDerivedEcdsaAccountSignsItsExistingIdentity() throws {
    let f = try make(.ecdsa, path: "//fixture")
    try f.keys.deleteKey(for: KeystoreTag.secretKeyTagForAddress(f.account.address))
    try f.keys.deleteKey(for: KeystoreTag.seedTagForAddress(f.account.address))
    try verify(f)
  }
  func testMissingSelectedAccountBlocksBeforeAnyKeyRead() throws {
    let f = try make()
    f.selected = nil
    let reads = f.keys.reads
    reject(f, .missingSelectedAccount)
    XCTAssertEqual(f.keys.reads, reads)
  }
  func testUnselectedMatchingAccountCannotSign() throws {
    let f = try make()
    f.selected = f.account.replacingSelection(false)
    reject(f, .missingSelectedAccount)
  }
  func testAnotherSelectedAddressCannotUseThisSigner() throws {
    let f = try make()
    f.selected = f.changed(address: "other")
    reject(f, .missingSelectedAccount)
  }
  func testSelectedPublicKeyMustMatchTheBoundSigner() throws {
    let f = try make()
    f.selected = f.changed(publicKey: Data(repeating: 9, count: 32))
    reject(f, .missingSelectedAccount)
  }
  func testSelectedCryptoTypeMustMatchTheBoundSigner() throws {
    let f = try make()
    f.selected = f.changed(type: .ed25519)
    reject(f, .missingSelectedAccount)
  }
  func testSelectedNetworkPrefixMustMatchTheBoundSigner() throws {
    let f = try make()
    f.selected = f.changed(network: 42)
    reject(f, .missingSelectedAccount)
  }
  func testMissingNetworkSnapshotCannotSign() throws {
    let f = try make()
    f.snapshot = nil
    reject(f, .missingNetworkSnapshot)
  }
  func testUnknownSnapshotSchemaCannotSign() throws {
    let f = try make()
    f.changeSnapshot(schema: 99)
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotSelectedWalletMustMatch() throws {
    let f = try make()
    f.changeSnapshot(selected: "other")
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotRequiresTheWalletIdentity() throws {
    let f = try make()
    f.changeSnapshot(wallets: [])
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotWalletMustPreserveItsExistingSoraAddress() throws {
    let f = try make()
    f.changeSnapshot(wallets: [
      .init(
        id: f.account.address, displayName: "Fixture", existingSoraAddress: "other",
        secretSource: .mnemonicEntropy)
    ])
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotRequiresItsSora2NetworkAccount() throws {
    let f = try make()
    f.changeSnapshot(accounts: [])
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotRejectsAnotherNetworkAccount() throws {
    let f = try make()
    f.changeSnapshot(accounts: [f.network(network: .taira)])
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotRejectsWrongDerivationVersion() throws {
    let f = try make()
    f.changeSnapshot(accounts: [f.network(version: 1)])
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotRejectsWrongAccountPublicKey() throws {
    let f = try make()
    f.changeSnapshot(accounts: [f.network(publicKey: Data(repeating: 7, count: 32))])
    reject(f, .missingNetworkSnapshot)
  }
  func testSnapshotRejectsWrongAccountAddress() throws {
    let f = try make()
    f.changeSnapshot(accounts: [f.network(address: "other")])
    reject(f, .missingNetworkSnapshot)
  }
  func testWatchOnlyPreferenceBlocksBeforeSecretReads() throws {
    let f = try make()
    f.watchOnly = true
    let reads = f.keys.reads
    reject(f, .keysNotVerified)
    XCTAssertEqual(f.keys.reads, reads)
  }
  func testWatchOnlySnapshotCannotBeOverriddenByPresentKeys() throws {
    let f = try make()
    f.source(.watchOnly)
    reject(f, .keysNotVerified)
  }
  func testSigningUnavailableWithPresentMaterialReportsUnverifiedKeys() throws {
    let f = try make()
    f.source(.signingUnavailable)
    reject(f, .keysNotVerified)
  }
  func testSigningUnavailableWithoutMaterialReportsMissingKeys() throws {
    let f = try make()
    f.source(.signingUnavailable)
    try f.eraseSigningMaterial()
    reject(f, .keysNotOnThisDevice)
  }
  func testMissingAllSigningMaterialNeverCreatesNewKeys() throws {
    let f = try make()
    try f.eraseSigningMaterial()
    let before = try f.keys.snapshot()
    reject(f, .keysNotOnThisDevice)
    XCTAssertEqual(try f.keys.snapshot(), before)
  }
  func testInvalidDirectSecretDoesNotFallBackToGoodEntropy() throws {
    let f = try make()
    try f.keys.updateKey(
      Data(repeating: 8, count: 32), with: KeystoreTag.secretKeyTagForAddress(f.account.address))
    reject(f, .keysNotVerified)
  }
  func testMismatchedSecretFromAnotherAccountFailsIdentityProof() throws {
    let f = try make(.ed25519)
    try f.keys.updateKey(
      Data(repeating: 8, count: 32), with: KeystoreTag.secretKeyTagForAddress(f.account.address))
    reject(f, .keysNotVerified)
  }
  func testRecoveryGatePreventsAnySigningMaterialRead() throws {
    let f = try make()
    f.settings.setWalletMigrationRecovery(reason: "offline regression recovery")
    let reads = f.keys.reads
    XCTAssertThrowsError(try f.signer.sign(message))
    XCTAssertEqual(f.keys.reads, reads)
  }
  func testHeldLifecycleLeaseRejectsTheLeaseLessSigningEntry() throws {
    let f = try make()
    let lease = f.coordinator.acquire()
    defer { lease.release() }
    XCTAssertThrowsError(try f.signer.sign(message)) {
      if case WalletNetworkMigrationError.lifecycleMutationBusy = $0 {
      } else {
        XCTFail("Expected lifecycle admission refusal: \($0)")
      }
    }
  }
  func testExistingLifecycleLeaseAllowsItsAuthorizedLocalSign() throws {
    let f = try make()
    let lease = f.coordinator.acquire()
    defer { lease.release() }
    let signature = try f.signer.sign(message, lifecycleLease: lease)
    XCTAssertEqual(signature.rawData().count, 64)
  }
  func testForeignLifecycleLeaseCannotAuthorizeThisSigner() throws {
    let f = try make()
    let other = try make()
    let lease = other.coordinator.acquire()
    defer { lease.release() }
    XCTAssertThrowsError(try f.signer.sign(message, lifecycleLease: lease))
  }
  func testSnapshotReadErrorIsPropagatedAndReleasesTheLifecycleLock() throws {
    let f = try make()
    f.snapshotError = LocalSignerFailure.unavailable
    XCTAssertThrowsError(try f.signer.sign(message)) { XCTAssertTrue($0 is LocalSignerFailure) }
    f.snapshotError = nil
    try verify(f)
  }
  func testSignatureForOneMessageCannotVerifyAnotherMessage() throws {
    let f = try make()
    let s = try f.signer.sign(message)
    let secret = try XCTUnwrap(
      LegacySoraSecretResolver.resolve(account: f.account, keystore: f.keys, recoveryGate: f.gate))
    XCTAssertThrowsError(
      try Sora2SignatureVerifier.verify(
        signature: s, originalData: Data("different".utf8), secretKey: secret, account: f.account)
    ) { XCTAssertEqual($0 as? SigningWrapperError, .signatureVerificationFailed) }
  }
}
private enum LocalSignerFailure: Error { case unavailable }
private final class LocalSignerFixture {
  let keys = LocalSignerKeys(), settings = InMemorySettingsManager(),
    gate: WalletRecoveryCapabilityGate, coordinator: WalletLifecycleCoordinator,
    account: AccountItem
  var selected: AccountItem?, snapshot: WalletNetworkSnapshot?, watchOnly = false,
    snapshotError: Error?
  lazy var signer = SigningWrapper(
    keystore: keys, account: account, lifecycleCoordinator: coordinator, recoveryGate: gate,
    selectedAccount: { [weak self] in self?.selected },
    networkSnapshot: { [weak self] in
      if let e = self?.snapshotError { throw e }
      return self?.snapshot
    }, isWatchOnly: { [weak self] _ in self?.watchOnly ?? true })
  init(type: CryptoType, path: String) throws {
    gate = WalletRecoveryCapabilityGate(
      settings: settings, unresolvedMigrationJournal: { false },
      unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
    coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
    let f = AccountOperationFactory(keystore: keys, recoveryGate: gate)
    let phrase = try IRMnemonicCreator(language: .english).mnemonic(
      fromList:
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    )
    let op = f.prepareAccountOperation(
      request: AccountCreationRequest(
        username: "Public fixture", type: .sora, derivationPath: path, cryptoType: type),
      mnemonic: phrase)
    op.start()
    let prepared = try XCTUnwrap(op.result).get()
    try f.persistPreparedAccount(prepared)
    account = prepared.account.replacingSelection(true)
    selected = account
    snapshot = WalletNetworkSnapshot(
      schemaVersion: 1, selectedWalletId: account.address,
      wallets: [
        .init(
          id: account.address, displayName: "Fixture", existingSoraAddress: account.address,
          secretSource: .mnemonicEntropy)
      ],
      accounts: [
        .init(
          walletId: account.address, networkId: .sora2, derivationVersion: 0,
          publicKey: account.publicKeyData, address: account.address)
      ], createdAt: Date(timeIntervalSince1970: 1))
  }
  func changed(
    address: String? = nil, publicKey: Data? = nil, type: CryptoType? = nil, network: UInt16? = nil
  ) -> AccountItem {
    .init(
      address: address ?? account.address, cryptoType: type ?? account.cryptoType,
      networkType: network ?? account.networkType, username: account.username,
      publicKeyData: publicKey ?? account.publicKeyData, settings: account.settings, order: 0,
      isSelected: true)
  }
  func network(
    network: NetworkId = .sora2, version: Int = 0, publicKey: Data? = nil, address: String? = nil
  ) -> NetworkAccount {
    .init(
      walletId: account.address, networkId: network, derivationVersion: version,
      publicKey: publicKey ?? account.publicKeyData, address: address ?? account.address)
  }
  func changeSnapshot(
    schema: Int? = nil, selected: String? = nil, wallets: [WalletIdentity]? = nil,
    accounts: [NetworkAccount]? = nil
  ) {
    let old = snapshot!
    snapshot = .init(
      schemaVersion: schema ?? old.schemaVersion,
      selectedWalletId: selected ?? old.selectedWalletId, wallets: wallets ?? old.wallets,
      accounts: accounts ?? old.accounts, createdAt: old.createdAt)
  }
  func source(_ source: WalletSecretSource) {
    changeSnapshot(wallets: [
      .init(
        id: account.address, displayName: "Fixture", existingSoraAddress: account.address,
        secretSource: source)
    ])
  }
  func eraseSigningMaterial() throws {
    for tag in [
      KeystoreTag.secretKeyTagForAddress(account.address),
      KeystoreTag.seedTagForAddress(account.address),
      KeystoreTag.entropyTagForAddress(account.address),
    ] { try keys.deleteKey(for: tag) }
  }
}
private final class LocalSignerKeys: KeystoreProtocol {
  private let base = InMemoryKeychain()
  var reads = 0
  func addKey(_ key: Data, with identifier: String) throws {
    try base.addKey(key, with: identifier)
  }
  func saveKey(_ key: Data, with identifier: String) throws {
    try base.saveKey(key, with: identifier)
  }
  func updateKey(_ key: Data, with identifier: String) throws {
    try base.updateKey(key, with: identifier)
  }
  func deleteKey(for identifier: String) throws { try base.deleteKey(for: identifier) }
  func fetchKey(for identifier: String) throws -> Data {
    reads += 1
    return try base.fetchKey(for: identifier)
  }
  func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
  func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
  func snapshot() throws -> [String: Data] {
    try Dictionary(
      uniqueKeysWithValues: base.allKeyIdentifiers().map { ($0, try base.fetchKey(for: $0)) })
  }
}
