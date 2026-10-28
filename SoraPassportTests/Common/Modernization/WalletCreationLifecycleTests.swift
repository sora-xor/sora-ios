// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import IrohaCrypto
import RobinHood
import SSFCloudStorage
import SoraKeystore
import XCTest

@testable import SoraPassport

@MainActor
final class WalletCreationLifecycleTests: XCTestCase {
  private var fixtures = [CreationLifecycleFixture]()
  private func make() throws -> CreationLifecycleFixture {
    let f = try CreationLifecycleFixture()
    fixtures.append(f)
    return f
  }
  override func tearDown() async throws {
    for f in fixtures {
      f.settings.cancelPending()
      f.factory.prepared.forEach { $0.discard() }
    }
    fixtures.removeAll()
    try await Task.sleep(nanoseconds: 20_000_000)
    try await super.tearDown()
  }
  private func waitUntil(
    _ condition: @escaping () -> Bool, file: StaticString = #filePath, line: UInt = #line
  ) async {
    for _ in 0..<100 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertTrue(condition(), file: file, line: line)
  }
  private func assertLeaseReleased(file: StaticString = #filePath, line: UInt = #line) {
    let lease = WalletLifecycleCoordinator.shared.tryAcquire()
    XCTAssertNotNil(lease, file: file, line: line)
    lease?.release()
  }
  func testSetupRequestsTwentyFourWordStrength() throws {
    let f = try make()
    f.interactor.setup()
    XCTAssertEqual(f.creator.strengths, [.entropy256])
    XCTAssertEqual(f.output.metadata.first?.mnemonic, Array(repeating: "abandon", count: 23) + ["art"])
  }
  func testSetupRetainsSupportedNetworksAndDefaults() throws {
    let f = try make()
    f.interactor.setup()
    XCTAssertEqual(f.output.metadata.first?.availableNetworks, [.sora])
    XCTAssertEqual(f.output.metadata.first?.defaultNetwork, .sora)
    XCTAssertEqual(f.output.metadata.first?.defaultCryptoType, .sr25519)
    XCTAssertEqual(f.output.metadata.first?.availableCryptoTypes, CryptoType.allCases)
  }
  func testMnemonicGenerationFailureIsReportedWithoutCreatingAnything() throws {
    let f = try make()
    f.creator.failure = CreationLifecycleFailure.prepare
    f.interactor.setup()
    XCTAssertEqual(f.output.mnemonicErrors.count, 1)
    XCTAssertTrue(f.output.metadata.isEmpty)
    XCTAssertTrue(f.factory.requests.isEmpty)
  }
  func testServicePassesReviewedNameCryptoPathAndPhraseToPreparation() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    XCTAssertEqual(f.factory.requests.first?.username, f.request.username)
    XCTAssertEqual(f.factory.requests.first?.cryptoType, .sr25519)
    XCTAssertEqual(f.factory.requests.first?.derivationPath, "//fixture")
    XCTAssertEqual(f.factory.words.first, f.mnemonic.allWords())
  }
  func testServiceDoesNotReportSuccessBeforeSelectionCommits() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    XCTAssertTrue(f.results.isEmpty)
    XCTAssertTrue(f.events.events.isEmpty)
    XCTAssertTrue(f.factory.persisted.isEmpty)
  }
  func testServicePersistsOnlyThePreparedAccountWhenSelectionRequestsIt() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.results.count == 1 }
    XCTAssertEqual(f.factory.persisted.map(\.address), [f.factory.prepared[0].account.address])
    XCTAssertEqual(try f.results[0].get().address, f.factory.prepared[0].account.address)
  }
  func testServiceSuccessNotifiesSelectionBeforeCompleting() async throws {
    let f = try make()
    f.events.deferCompletion = true
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.events.events.count == 1 }
    XCTAssertTrue(f.events.events[0] is SelectedAccountChanged)
    XCTAssertTrue(f.results.isEmpty)
    f.events.finish()
    await waitUntil { f.results.count == 1 }
    XCTAssertTrue(f.completionThreads.allSatisfy { $0 })
  }
  func testServiceSelectionFailureReturnsErrorWithoutNotifying() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.results.count == 1 }
    XCTAssertThrowsError(try f.results[0].get())
    XCTAssertTrue(f.events.events.isEmpty)
    XCTAssertTrue(f.factory.persisted.isEmpty)
    XCTAssertTrue(f.completionThreads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testServicePreparationFailureReturnsOnMainAndReleasesLease() async throws {
    let f = try make()
    f.factory.failure = CreationLifecycleFailure.prepare
    f.create()
    await waitUntil { f.results.count == 1 }
    XCTAssertThrowsError(try f.results[0].get())
    XCTAssertTrue(f.settings.pending.isEmpty)
    XCTAssertTrue(f.completionThreads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testServiceCanRetryAfterPreparationFailure() async throws {
    let f = try make()
    f.factory.failure = CreationLifecycleFailure.prepare
    f.create()
    await waitUntil { f.results.count == 1 }
    f.factory.failure = nil
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.results.count == 2 }
    XCTAssertNoThrow(try f.results[1].get())
  }
  func testServiceCanRetryAfterSelectionFailure() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.results.count == 1 }
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.results.count == 2 }
    XCTAssertEqual(f.factory.requests.count, 2)
  }
  func testConcurrentServiceRequestCompletesWithBusyInsteadOfHanging() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    f.create()
    await waitUntil { f.results.count == 1 }
    let result = try XCTUnwrap(f.results.first)
    XCTAssertThrowsError(try result.get())
    XCTAssertEqual(f.settings.pending.count, 1)
  }
  func testConcurrentServiceRequestDoesNotPrepareAnotherWallet() async throws {
    let f = try make()
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    f.create()
    XCTAssertEqual(f.factory.requests.count, 1)
  }
  func testServiceDeallocationDiscardsPreparedMaterialAndCompletes() async throws {
    let f = try make()
    let lease = try XCTUnwrap(WalletLifecycleCoordinator.shared.tryAcquire())
    var service: CreateAccountService? = f.newService()
    weak var reference = service
    service?.createAccount(request: f.request, mnemonic: f.mnemonic) { result in
      if let result { f.results.append(result) }
    }
    service = nil
    XCTAssertNil(reference)
    lease.release()
    await waitUntil { f.results.count == 1 }
    XCTAssertThrowsError(try f.results[0].get())
    XCTAssertThrowsError(try f.factory.real.persistPreparedAccount(f.factory.prepared[0]))
    XCTAssertTrue(f.settings.pending.isEmpty)
    assertLeaseReleased()
  }
  func testServiceReleasesLeaseBeforeWaitingForEventDelivery() async throws {
    let f = try make()
    f.events.deferCompletion = true
    f.create()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.events.events.count == 1 }
    assertLeaseReleased()
    f.events.finish()
    await waitUntil { f.results.count == 1 }
  }
  func testInteractorPassesTheReviewedRequestAndMnemonic() async throws {
    let f = try make()
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    XCTAssertEqual(f.factory.requests.first?.username, f.request.username)
    XCTAssertEqual(f.factory.words.first, f.mnemonic.allWords())
    XCTAssertTrue(f.output.accounts.isEmpty)
  }
  func testInteractorSuccessPublishesTheInsertedAccountOnMain() async throws {
    let f = try make()
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.output.accounts[0].address, f.factory.prepared[0].account.address)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    XCTAssertEqual(f.events.events.count, 1)
    assertLeaseReleased()
  }
  func testInteractorWaitsForSelectedAccountNotificationDelivery() async throws {
    let f = try make()
    f.events.deferCompletion = true
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.events.events.count == 1 }
    XCTAssertTrue(f.output.accounts.isEmpty)
    f.events.finish()
    await waitUntil { f.output.accounts.count == 1 }
  }
  func testInteractorSelectionFailureDoesNotPublishSuccess() async throws {
    let f = try make()
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.output.errors.count == 1 }
    XCTAssertTrue(f.output.accounts.isEmpty)
    XCTAssertTrue(f.events.events.isEmpty)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testInteractorPreparationFailureDoesNotSelectAnAccount() async throws {
    let f = try make()
    f.factory.failure = CreationLifecycleFailure.prepare
    f.skip()
    await waitUntil { f.output.errors.count == 1 }
    XCTAssertTrue(f.settings.pending.isEmpty)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testInteractorCanRetryAfterSelectionFailure() async throws {
    let f = try make()
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.output.errors.count == 1 }
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.factory.requests.count, 2)
  }
  func testInteractorIgnoresDuplicateConfirmationBeforePreparation() async throws {
    let f = try make()
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    f.skip()
    XCTAssertEqual(f.factory.requests.count, 1)
    XCTAssertEqual(f.settings.pending.count, 1)
  }
  func testInteractorDeallocationDiscardsThePreparedAccount() async throws {
    let f = try make()
    let lease = try XCTUnwrap(WalletLifecycleCoordinator.shared.tryAcquire())
    var interactor: AccountCreateInteractor? = f.newInteractor()
    interactor?.presenter = f.output
    weak var reference = interactor
    interactor?.skipConfirmation(request: f.request, mnemonic: f.mnemonic)
    interactor = nil
    XCTAssertNil(reference)
    lease.release()
    await waitUntil { f.factory.operations[0].isFinished }
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertThrowsError(try f.factory.real.persistPreparedAccount(f.factory.prepared[0]))
    XCTAssertTrue(f.output.accounts.isEmpty)
    XCTAssertTrue(f.settings.pending.isEmpty)
    assertLeaseReleased()
  }
  func testInteractorCanRetryAfterPreparationFailure() async throws {
    let f = try make()
    f.factory.failure = CreationLifecycleFailure.prepare
    f.skip()
    await waitUntil { f.output.errors.count == 1 }
    f.factory.failure = nil
    f.skip()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
  }
  func testRootConfirmationPublishesTheSameShuffledWordsOnFailure() throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.requestWords()
    interactor.confirm(words: [])
    XCTAssertEqual(f.output.wordUpdates.count, 2)
    XCTAssertEqual(f.output.wordUpdates[0].0.sorted(), f.mnemonic.allWords().sorted())
    XCTAssertEqual(f.output.wordUpdates[0].0, f.output.wordUpdates[1].0)
    XCTAssertFalse(f.output.wordUpdates[0].1)
    XCTAssertTrue(f.output.wordUpdates[1].1)
    XCTAssertTrue(f.factory.requests.isEmpty)
  }
  func testRootConfirmationRejectsCorrectWordsInTheWrongOrder() throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.confirm(words: f.mnemonic.allWords().reversed())
    XCTAssertTrue(f.factory.requests.isEmpty)
    XCTAssertEqual(f.output.wordUpdates.count, 1)
    XCTAssertTrue(f.output.wordUpdates[0].1)
  }
  func testRootConfirmationCommitsTheExactReviewedAccount() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.confirm(words: f.mnemonic.allWords())
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.output.accounts[0].address, f.factory.prepared[0].account.address)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testRootConfirmationSkipStillUsesTheSuppliedMnemonic() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    XCTAssertEqual(f.factory.words, [f.mnemonic.allWords()])
    XCTAssertEqual(f.factory.requests.first?.derivationPath, "//fixture")
    XCTAssertTrue(f.output.accounts.isEmpty)
  }
  func testRootConfirmationPreparationFailureReleasesTheLease() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    f.factory.failure = CreationLifecycleFailure.prepare
    interactor.skipConfirmation()
    await waitUntil { f.output.errors.count == 1 }
    XCTAssertTrue(f.settings.pending.isEmpty)
    XCTAssertTrue(f.output.accounts.isEmpty)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testRootConfirmationSelectionFailureDoesNotReportSuccess() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.output.errors.count == 1 }
    XCTAssertTrue(f.output.accounts.isEmpty)
    XCTAssertTrue(f.events.events.isEmpty)
    assertLeaseReleased()
  }
  func testRootConfirmationCanRetryAfterFailedPersistence() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.output.errors.count == 1 }
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.factory.requests.count, 2)
  }
  func testRootConfirmationIgnoresRepeatedSubmitWhileSelectionIsPending() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: false)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    interactor.skipConfirmation()
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertEqual(f.settings.pending.count, 1)
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.factory.persisted.count, 1)
  }
  func testRootConfirmationDeallocationDiscardsUncommittedMaterial() async throws {
    let f = try make()
    let lease = try XCTUnwrap(WalletLifecycleCoordinator.shared.tryAcquire())
    var interactor: BaseAccountConfirmInteractor? = f.confirmation(additional: false)
    weak var reference = interactor
    interactor?.skipConfirmation()
    interactor = nil
    XCTAssertNil(reference)
    lease.release()
    await waitUntil { f.factory.operations[0].isFinished }
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertThrowsError(try f.factory.real.persistPreparedAccount(f.factory.prepared[0]))
    XCTAssertTrue(f.settings.pending.isEmpty)
    assertLeaseReleased()
  }
  func testAdditionalConfirmationPublishesTheSameShuffledWordsOnFailure() throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.requestWords()
    interactor.confirm(words: [])
    XCTAssertEqual(f.output.wordUpdates.count, 2)
    XCTAssertEqual(f.output.wordUpdates[0].0.sorted(), f.mnemonic.allWords().sorted())
    XCTAssertEqual(f.output.wordUpdates[0].0, f.output.wordUpdates[1].0)
    XCTAssertFalse(f.output.wordUpdates[0].1)
    XCTAssertTrue(f.output.wordUpdates[1].1)
    XCTAssertTrue(f.factory.requests.isEmpty)
  }
  func testAdditionalConfirmationRejectsCorrectWordsInTheWrongOrder() throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.confirm(words: f.mnemonic.allWords().reversed())
    XCTAssertTrue(f.factory.requests.isEmpty)
    XCTAssertEqual(f.output.wordUpdates.count, 1)
    XCTAssertTrue(f.output.wordUpdates[0].1)
  }
  func testAdditionalConfirmationCommitsTheExactReviewedAccount() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.confirm(words: f.mnemonic.allWords())
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.output.accounts[0].address, f.factory.prepared[0].account.address)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testAdditionalConfirmationSkipStillUsesTheSuppliedMnemonic() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    XCTAssertEqual(f.factory.words, [f.mnemonic.allWords()])
    XCTAssertEqual(f.factory.requests.first?.derivationPath, "//fixture")
    XCTAssertTrue(f.output.accounts.isEmpty)
  }
  func testAdditionalConfirmationPreparationFailureReleasesTheLease() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    f.factory.failure = CreationLifecycleFailure.prepare
    interactor.skipConfirmation()
    await waitUntil { f.output.errors.count == 1 }
    XCTAssertTrue(f.settings.pending.isEmpty)
    XCTAssertTrue(f.output.accounts.isEmpty)
    XCTAssertTrue(f.output.threads.allSatisfy { $0 })
    assertLeaseReleased()
  }
  func testAdditionalConfirmationSelectionFailureDoesNotReportSuccess() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.output.errors.count == 1 }
    XCTAssertTrue(f.output.accounts.isEmpty)
    XCTAssertTrue(f.events.events.isEmpty)
    assertLeaseReleased()
  }
  func testAdditionalConfirmationCanRetryAfterFailedPersistence() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    f.settings.fail()
    await waitUntil { f.output.errors.count == 1 }
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.factory.requests.count, 2)
  }
  func testAdditionalConfirmationIgnoresRepeatedSubmitWhileSelectionIsPending() async throws {
    let f = try make()
    let interactor = f.confirmation(additional: true)
    interactor.skipConfirmation()
    await waitUntil { f.settings.pending.count == 1 }
    interactor.skipConfirmation()
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertEqual(f.settings.pending.count, 1)
    try f.settings.commit()
    await waitUntil { f.output.accounts.count == 1 }
    XCTAssertEqual(f.factory.persisted.count, 1)
  }
  func testAdditionalConfirmationDeallocationDiscardsUncommittedMaterial() async throws {
    let f = try make()
    let lease = try XCTUnwrap(WalletLifecycleCoordinator.shared.tryAcquire())
    var interactor: BaseAccountConfirmInteractor? = f.confirmation(additional: true)
    weak var reference = interactor
    interactor?.skipConfirmation()
    interactor = nil
    XCTAssertNil(reference)
    lease.release()
    await waitUntil { f.factory.operations[0].isFinished }
    try? await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertThrowsError(try f.factory.real.persistPreparedAccount(f.factory.prepared[0]))
    XCTAssertTrue(f.settings.pending.isEmpty)
    assertLeaseReleased()
  }
}
private enum CreationLifecycleFailure: Error { case prepare, selection }
private final class CreationLifecycleFixture {
  let keys = InMemoryKeychain(), storage = InMemorySettingsManager(),
    settings = CreationLifecycleSettings(), events = CreationLifecycleEvents(),
    output = CreationLifecycleOutput(), creator = CreationLifecycleMnemonic()
  let request = AccountCreationRequest(
    username: "Public creation fixture", type: .sora, derivationPath: "//fixture",
    cryptoType: .sr25519)
  let mnemonic: IRMnemonicProtocol
  let factory: CreationLifecycleFactory
  let repository: AnyDataProviderRepository<AccountItem>
  lazy var service = newService()
  lazy var interactor: AccountCreateInteractor = {
    let value = newInteractor()
    value.presenter = output
    return value
  }()
  var results = [Result<AccountItem, Error>](), completionThreads = [Bool]()
  init() throws {
    mnemonic = try creator.mnemonic(
      fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
    let gate = WalletRecoveryCapabilityGate(
      settings: storage, unresolvedMigrationJournal: { false },
      unresolvedWalletCommitJournal: { false })
    factory = CreationLifecycleFactory(
      real: AccountOperationFactory(keystore: keys, recoveryGate: gate))
    repository = AnyDataProviderRepository(CreationLifecycleAccounts())
  }
  func newService() -> CreateAccountService {
    CreateAccountService(
      accountRepository: repository, accountOperationFactory: factory, settings: settings,
      eventCenter: events)
  }
  func newInteractor() -> AccountCreateInteractor {
    AccountCreateInteractor(
      mnemonicCreator: creator, supportedNetworkTypes: [.sora], defaultNetwork: .sora,
      accountOperationFactory: factory, accountRepository: repository, settings: settings,
      eventCenter: events, cloudStorageService: CreationLifecycleCloud())
  }
  func create() {
    service.createAccount(request: request, mnemonic: mnemonic) { [weak self] value in
      guard let self, let value else { return }
      results.append(value)
      completionThreads.append(Thread.isMainThread)
    }
  }
  func confirmation(additional: Bool) -> BaseAccountConfirmInteractor {
    let value: BaseAccountConfirmInteractor
    if additional {
      value = AddAccountConfirmInteractor(
        request: request, mnemonic: mnemonic, accountOperationFactory: factory,
        accountRepository: repository, operationManager: OperationManager(), settings: settings,
        eventCenter: events)
    } else {
      value = AccountConfirmInteractor(
        request: request, mnemonic: mnemonic, accountOperationFactory: factory,
        accountRepository: repository, settings: settings, operationManager: OperationManager())
    }
    value.presenter = output
    return value
  }
  func skip() { interactor.skipConfirmation(request: request, mnemonic: mnemonic) }
}
private final class CreationLifecycleFactory: AccountOperationFactoryProtocol {
  let real: AccountOperationFactory
  var failure: Error?
  var requests = [AccountCreationRequest](), words = [[String]](), prepared = [PreparedAccount](),
    persisted = [AccountItem](), operations = [BaseOperation<PreparedAccount>]()
  init(real: AccountOperationFactory) { self.real = real }
  func prepareAccountOperation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol)
    -> BaseOperation<PreparedAccount>
  {
    requests.append(request)
    words.append(mnemonic.allWords())
    let operation: BaseOperation<PreparedAccount>
    if let failure {
      operation = ClosureOperation { throw failure }
    } else {
      let derived = real.prepareAccountOperation(request: request, mnemonic: mnemonic)
      derived.main()
      let result = derived.result!
      if case .success(let value) = result { prepared.append(value) }
      operation = ClosureOperation { try result.get() }
    }
    operations.append(operation)
    return operation
  }
  func prepareAccountOperation(request: AccountImportSeedRequest) -> BaseOperation<PreparedAccount>
  {
    XCTFail("Unexpected seed import")
    return ClosureOperation { throw CreationLifecycleFailure.prepare }
  }
  func prepareAccountOperation(request: AccountImportKeystoreRequest) -> BaseOperation<
    PreparedAccount
  > {
    XCTFail("Unexpected keystore import")
    return ClosureOperation { throw CreationLifecycleFailure.prepare }
  }
  func persistPreparedAccount(_ prepared: PreparedAccount) throws {
    persisted.append(prepared.account)
    try real.persistPreparedAccount(prepared)
  }
}
private final class CreationLifecycleSettings: SelectedWalletSettingsProtocol {
  struct Pending {
    let prepared: PreparedAccount
    let persist: () throws -> Void
    let lease: WalletLifecycleLease
    let completion: (Result<AccountItem, Error>) -> Void
  }
  var currentAccount: AccountItem?
  var pending = [Pending]()
  func performInsertAndSelect(
    prepared: PreparedAccount, persistSecrets: @escaping () throws -> Void,
    lifecycleLease: WalletLifecycleLease,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) {
    DispatchQueue.main.async {
      self.pending.append(
        Pending(
          prepared: prepared, persist: persistSecrets, lease: lifecycleLease,
          completion: completionClosure))
    }
  }
  func commit() throws {
    let next = pending.removeFirst()
    try next.persist()
    currentAccount = next.prepared.account
    next.completion(.success(next.prepared.account))
  }
  func fail() {
    let next = pending.removeFirst()
    next.prepared.discard()
    next.completion(.failure(CreationLifecycleFailure.selection))
  }
  func cancelPending() { while !pending.isEmpty { fail() } }
  func performSave(
    value: AccountItem, completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected metadata save") }
  func performSelectAfterRemoval(
    value: AccountItem, lifecycleLease: WalletLifecycleLease,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected removal") }
  func performUpdateName(
    account: AccountItem, displayName: String,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected rename") }
  func performUpdateAssetSettings(
    account: AccountItem, settings: AccountSettings,
    completionClosure: @escaping (Result<AccountItem, Error>) -> Void
  ) { XCTFail("Unexpected assets mutation") }
  func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) {
    completionClosure(.success(currentAccount))
  }
  func save(value: AccountItem) { XCTFail("Unexpected save") }
}
private final class CreationLifecycleMnemonic: NSObject, IRMnemonicCreatorProtocol {
  let real = IRMnemonicCreator(language: .english)
  var strengths = [IRMnemonicStrength]()
  var failure: Error?
  func randomMnemonic(_ strength: IRMnemonicStrength) throws -> IRMnemonicProtocol {
    strengths.append(strength)
    if let failure { throw failure }
    return try real.mnemonic(fromEntropy: Data(repeating: 0, count: 32))
  }
  func mnemonic(fromEntropy entropy: Data) throws -> IRMnemonicProtocol {
    try real.mnemonic(fromEntropy: entropy)
  }
  func mnemonic(fromList mnemonicPhrase: String) throws -> IRMnemonicProtocol {
    try real.mnemonic(fromList: mnemonicPhrase)
  }
}
private final class CreationLifecycleOutput: AccountCreateInteractorOutputProtocol,
  AccountConfirmInteractorOutputProtocol
{
  var wordUpdates = [([String], Bool)]()
  var metadata = [AccountCreationMetadata](), accounts = [AccountItem](), errors = [Error](),
    mnemonicErrors = [Error](), threads = [Bool]()
  func didReceive(metadata: AccountCreationMetadata) { self.metadata.append(metadata) }
  func didReceive(backupDerivationPath: String) {}
  func didReceiveMnemonicGeneration(error: Error) { mnemonicErrors.append(error) }
  func didReceive(words: [String], afterConfirmationFail: Bool) {
    wordUpdates.append((words, afterConfirmationFail))
  }
  func didCompleteConfirmation(for account: AccountItem) {
    accounts.append(account)
    threads.append(Thread.isMainThread)
  }
  func didReceive(error: Error) {
    errors.append(error)
    threads.append(Thread.isMainThread)
  }
}
private final class CreationLifecycleEvents: EventCenterProtocol {
  var events = [EventProtocol](), completions = [() -> Void]()
  var deferCompletion = false
  func notify(with event: EventProtocol) { events.append(event) }
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    events.append(event)
    if deferCompletion { completions.append(completionOnMain) } else { completionOnMain() }
  }
  func finish() {
    let callbacks = completions
    completions.removeAll()
    callbacks.forEach { $0() }
  }
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
  func remove(observer: EventVisitorProtocol) {}
}
private final class CreationLifecycleCloud: CloudStorageServiceProtocol {
  var isUserAuthorized: Bool { true }
  var auth: CloudStorageAccountState = .authorized
  var signInError: Error?, listError: Error?, deleteError: Error?
  var accounts: [OpenBackupAccount] = [], deleted: [OpenBackupAccount] = []
  func signInIfNeeded() async throws -> CloudStorageAccountState {
    if let signInError { throw signInError }
    return auth
  }
  func getBackupAccounts() async throws -> [OpenBackupAccount] {
    if let listError { throw listError }
    return accounts
  }
  func deleteBackup(account: OpenBackupAccount) async throws {
    if let deleteError { throw deleteError }
    deleted.append(account)
  }
  func saveBackup(account: OpenBackupAccount, password: String) async throws {
    XCTFail("Unexpected cloud write")
  }
  func importBackup(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount
  {
    XCTFail("Unexpected cloud import")
    throw CreationLifecycleFailure.selection
  }
  func disconnect() {}
}
private final class CreationLifecycleAccounts: DataProviderRepositoryProtocol {
  typealias Model = AccountItem
  var items: [Model]
  var failure: Error?
  init(items: [Model] = []) { self.items = items }
  func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
    ClosureOperation {
      if let failure = self.failure { throw failure }
      return self.items
    }
  }
  func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  {
    ClosureOperation {
      let ids = try ids()
      return self.items.filter { ids.contains($0.address) }
    }
  }
  func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions)
    -> BaseOperation<Model?>
  {
    ClosureOperation {
      let id = try id()
      return self.items.first { $0.address == id }
    }
  }
  func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { fetchAllOperation(with: options) }
  func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.items.count } }
  func saveOperation(
    _ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { ClosureOperation { XCTFail("Unexpected account mutation") } }
  func saveBatchOperation(
    _ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { saveOperation(updates, deletions) }
  func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> {
    saveOperation(models, { [] })
  }
  func deleteAllOperation() -> BaseOperation<Void> { saveOperation({ [] }, { [] }) }
}
