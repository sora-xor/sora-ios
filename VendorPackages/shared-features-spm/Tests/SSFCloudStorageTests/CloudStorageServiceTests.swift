import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import GoogleSignIn
import SSFModels
import SSFUtils
import XCTest

@testable import SSFCloudStorage

final class CloudStorageServiceTests: XCTestCase {
    private enum CloudStorageServiceTestsError: Error {
        case noSignInProviderExists
    }

    var service: CloudStorageService?
    var signInProvider: GIDSignInMock?
    var delegate: UIViewController?
    var queue: DispatchQueueType?
    var factory: BackupFileFactoryMock?
    var encryptionService: EncryptionServiceMock?
    var googleService: GoogleServiceMock?

    override func setUpWithError() throws {
        try super.setUpWithError()

        let delegate = UIViewController()
        let signInProvider = GIDSignInMock.sharedInstance as? GIDSignInMock
        let queue = DispatchQueueMock()
        let googleService = GoogleServiceMock()
        let factory = BackupFileFactoryMock()
        let encryptionService = EncryptionServiceMock()
        encryptionService.getDecryptedReturnValue = TestData.account.address

        guard let signInProvider else { throw CloudStorageServiceTestsError.noSignInProviderExists }

        self.signInProvider = signInProvider
        self.delegate = delegate
        self.queue = queue
        self.googleService = googleService
        self.encryptionService = encryptionService
        self.factory = factory
        TestData.user.userIDValue = "google-user-id"
        TestData.user.scopesValue = [kGTLRAuthScopeDriveAppdata]
        TestData.user.profileValue.emailValue = "wallet@example.com"
        TestData.user.profileValue.nameValue = "Wallet Owner"

        service = CloudStorageService(
            uiDelegate: delegate,
            signInProvider: signInProvider,
            googleDriveService: googleService,
            queue: queue,
            encryptionService: encryptionService,
            fileFactory: factory
        )
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        service = nil
        signInProvider?._currentUser = nil
        signInProvider?.hasPreviousSignInCallsCount = 0
        signInProvider?.hasPreviousSignInReturnValue = false
        signInProvider?.restorePreviousSignInCallsCount = 0
        signInProvider?.restorePreviousSignInClosure = nil
        signInProvider?.restorePreviousSignInWithoutRefreshCallsCount = 0
        signInProvider?.restorePreviousSignInWithoutRefreshClosure = nil
        signInProvider?.signInCallsCount = 0
        signInProvider?.signInClosure = nil
        signInProvider?.signOutCallsCount = 0
        signInProvider?.signOutClosure = nil
        signInProvider?.disconnectCompletionCallsCount = 0
        signInProvider?.disconnectCompletionClosure = nil
        signInProvider = nil
        delegate = nil
        queue = nil
        googleService = nil
        encryptionService = nil
        factory = nil
    }

    func testUserAuthorized() {
        // arrange
        signInProvider?._currentUser = TestData.user

        // assert
        XCTAssertTrue(service?.isUserAuthorized ?? false)
    }

    func testSignInIfNeeded() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        let state = try await service?.signInIfNeeded()

        // assert
        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 1)
        XCTAssertTrue(googleService?.setAuthorizerCalled ?? false)
    }

    func testConfigureCurrentAccountDoesNotRestoreOrPresentSignIn() async {
        signInProvider?._currentUser = TestData.user

        let state = await service?.configureCurrentAccountIfAvailable()

        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(signInProvider?.hasPreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.restorePreviousSignInWithoutRefreshCallsCount, 0)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 1)
    }

    func testConfigureCurrentAccountRestoresIdentityWithoutNetworkOrAuthFlow() async {
        signInProvider?.restorePreviousSignInWithoutRefreshClosure = { [weak self] in
            self?.signInProvider?._currentUser = TestData.user
            return true
        }

        let state = await service?.configureCurrentAccountIfAvailable()

        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(service?.currentAccountIdentity?.email, "wallet@example.com")
        XCTAssertEqual(signInProvider?.hasPreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.restorePreviousSignInWithoutRefreshCallsCount, 1)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 0)
    }

    func testConfigureCurrentAccountWithoutSavedUserIsNoninteractive() async {
        let state = await service?.configureCurrentAccountIfAvailable()

        XCTAssertEqual(state, .notAuthorized)
        XCTAssertEqual(signInProvider?.restorePreviousSignInWithoutRefreshCallsCount, 1)
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 0)
    }

    func testRestorePreviousSignInWhenAvailableDoesNotPresentInteractiveSignIn() async throws {
        // arrange
        signInProvider?.hasPreviousSignInReturnValue = true
        signInProvider?.restorePreviousSignInClosure = { completion in
            completion?(TestData.user, nil)
        }

        // act
        let state = try await service?.restorePreviousSignInIfAvailable()

        // assert
        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(signInProvider?.hasPreviousSignInCallsCount, 1)
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 1)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 1)
    }

    func testRestoredIdentityIsShownButDriveRequiresAppDataScope() async throws {
        TestData.user.scopesValue = []
        signInProvider?._currentUser = TestData.user

        let state = try await service?.restorePreviousSignInIfAvailable()

        XCTAssertEqual(state, .notAuthorized)
        XCTAssertEqual(service?.currentAccountIdentity?.userID, "google-user-id")
        XCTAssertEqual(service?.currentAccountIdentity?.email, "wallet@example.com")
        XCTAssertNil(googleService?.setAuthorizerReceivedArguments)
    }

    func testBoundMobileImportRejectsDifferentGoogleIdentityBeforeDriveQuery() async throws {
        signInProvider?._currentUser = TestData.user
        let restoredState = try await service?.restorePreviousSignInIfAvailable()
        XCTAssertEqual(restoredState, .authorized)
        let queryCount = googleService?.executeQueryCallsCount

        do {
            _ = try await service?.importMobileBackupIfAuthorized(
                account: TestData.emptyAccount,
                password: "password",
                expectedAccountUserID: "different-google-user"
            )
            XCTFail("Expected mismatched Google identity to be rejected")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notAuthorized.localizedDescription
            )
        }
        XCTAssertEqual(googleService?.executeQueryCallsCount, queryCount)
    }

    func testRestorePreviousSignInWithoutSessionReturnsNotAuthorized() async throws {
        // act
        let state = try await service?.restorePreviousSignInIfAvailable()

        // assert
        XCTAssertEqual(state, .notAuthorized)
        XCTAssertEqual(signInProvider?.hasPreviousSignInCallsCount, 1)
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 0)
    }

    func testMobileImportRequiresPreviouslyRestoredSessionWithoutInteractiveSignIn() async {
        do {
            _ = try await service?.importMobileBackupIfAuthorized(
                account: TestData.account,
                password: "1"
            )
            XCTFail("Expected a restored-session requirement")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notAuthorized.localizedDescription
            )
            XCTAssertEqual(signInProvider?.signInCallsCount, 0)
            XCTAssertEqual(googleService?.executeQueryCallsCount, 0)
        }
    }

    func testMobileImportAfterSilentRestoreUsesOnlyExactMobileLookup() async throws {
        signInProvider?.hasPreviousSignInReturnValue = true
        signInProvider?.restorePreviousSignInClosure = { completion in
            completion?(TestData.user, nil)
        }
        googleService?.account = TestData.encryptedAccount

        let restoredState = try await service?.restorePreviousSignInIfAvailable()
        XCTAssertEqual(restoredState, .authorized)
        let account = try await service?.importMobileBackupIfAuthorized(
            account: TestData.account,
            password: "1"
        )

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 2)
        let listQuery = googleService?.executeQueryReceivedInvocations.first
            as? GTLRDriveQuery_FilesList
        XCTAssertEqual(
            listQuery?.q,
            "name = '\(TestData.account.address).json' and trashed = false"
        )
        XCTAssertFalse(
            googleService?.executeQueryReceivedInvocations.contains {
                $0 is GTLRDriveQuery_FilesCreate
            } ?? true
        )
    }

    func testSignInIfNeededRestoresBeforeInteractiveSignIn() async throws {
        // arrange
        signInProvider?.hasPreviousSignInReturnValue = true
        signInProvider?.restorePreviousSignInClosure = { completion in
            completion?(TestData.user, nil)
        }

        // act
        let state = try await service?.signInIfNeeded()

        // assert
        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 1)
        XCTAssertEqual(signInProvider?.signInCallsCount, 0)
    }

    func testSignInIfNeededFallsBackToInteractiveSignInWhenRestoreFails() async throws {
        // arrange
        signInProvider?.hasPreviousSignInReturnValue = true
        signInProvider?.restorePreviousSignInClosure = { completion in
            completion?(nil, CloudStorageServiceError.notAuthorized)
        }
        signInProvider?.signInClosure = { _, _, _, completion in
            completion?(nil, CloudStorageServiceError.notAuthorized)
        }

        // act and assert
        do {
            _ = try await service?.signInIfNeeded()
            XCTFail("Expected interactive sign-in failure")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notAuthorized.localizedDescription
            )
            XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 1)
            XCTAssertEqual(signInProvider?.signInCallsCount, 1)
            XCTAssertEqual(
                signInProvider?.signInReceivedArguments?.forceAccountSelection,
                false
            )
        }
    }

    func testSelectingAnotherAccountPreservesExistingSessionWhenChooserIsCancelled() async {
        signInProvider?._currentUser = TestData.user
        signInProvider?.signInClosure = { _, _, _, completion in
            completion?(nil, NSError(domain: kGIDSignInErrorDomain, code: -5))
        }

        do {
            _ = try await service?.signInSelectingAccount()
            XCTFail("Expected account chooser cancellation")
        } catch {
            XCTAssertEqual((error as NSError).domain, kGIDSignInErrorDomain)
            XCTAssertEqual((error as NSError).code, -5)
        }

        XCTAssertEqual(signInProvider?.signInCallsCount, 1)
        XCTAssertEqual(
            signInProvider?.signInReceivedArguments?.forceAccountSelection,
            true
        )
        XCTAssertEqual(signInProvider?.restorePreviousSignInCallsCount, 0)
        XCTAssertEqual(signInProvider?.signOutCallsCount, 0)
        XCTAssertEqual(signInProvider?.disconnectCompletionCallsCount, 0)
    }

    func testSignInIfNeededWithError() async throws {
        // arrange
        signInProvider?.signInClosure = { [weak self] _, _, _, completion in
            completion?(nil, CloudStorageServiceError.notAuthorized)
        }

        // act
        do {
            let state = try await service?.signInIfNeeded()
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notAuthorized.localizedDescription
            )
            XCTAssertEqual(signInProvider?.signInCallsCount, 1)
            XCTAssertTrue(signInProvider?.signInCalled ?? false)
        }
    }

    func testGetBackupAccounts() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        let accounts = try await service?.getBackupAccounts()

        // assert
        XCTAssertEqual(accounts?.count, 1)
        XCTAssertEqual(accounts?.first?.address, TestData.account.address)

        XCTAssertEqual(googleService?.executeQueryCallsCount, 3)
        XCTAssertTrue(googleService?.executeQueryCalled ?? false)
    }

    func testSaveBackupAccount() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        googleService?.executeQueryReturnValue = (ticket: GoogleServiceTicketMock(), file: nil)
        factory?.createFileReturnValue = try getURL()
        // act
        try await service?.saveBackup(account: TestData.account, password: "1")

        // assert
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 1)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 3)
        XCTAssertEqual(factory?.createFileCallsCount, 1)

        XCTAssertTrue(googleService?.setAuthorizerCalled ?? false)
        XCTAssertTrue(googleService?.executeQueryCalled ?? false)
        XCTAssertTrue(factory?.createFileCalled ?? false)
    }

    func testImportBackupAccount() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        googleService?.account = TestData.encryptedAccount

        // act
        let account = try await service?.importBackup(account: TestData.account, password: "1")

        // assert
        XCTAssertEqual(account?.name, TestData.account.name)
        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(account?.cryptoType, TestData.account.cryptoType)
        XCTAssertEqual(account?.ethDerivationPath, TestData.account.ethDerivationPath)
        XCTAssertEqual(account?.backupAccountType, TestData.account.backupAccountType)
        XCTAssertEqual(account?.json, TestData.account.json)

        let listQuery = googleService?.executeQueryReceivedInvocations.first
            as? GTLRDriveQuery_FilesList
        XCTAssertEqual(
            listQuery?.q,
            "name = '\(TestData.account.address).json' and trashed = false"
        )
        XCTAssertFalse(
            googleService?.executeQueryReceivedInvocations.contains {
                $0 is GTLRDriveQuery_FilesCreate
            } ?? true
        )
    }

    func testImportBackupRejectsDecodedAccountWithDifferentAddress() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        var mismatchedAccount = TestData.encryptedAccount
        mismatchedAccount.address = TestData.emptyAccount.address
        googleService?.account = mismatchedAccount

        // act and assert
        do {
            _ = try await service?.importBackup(account: TestData.account, password: "1")
            XCTFail("Expected an address mismatch to be rejected")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.incorectJson.localizedDescription
            )
        }
    }

    func testImportLegacyBackupWithoutVerifierWithCorrectPassword() async throws {
        let password = "legacy-password"
        let encryptedAccount = try makeLegacyEncryptedAccount(password: password)
        try useRealEncryptionService(account: encryptedAccount)

        let account = try await service?.importBackup(
            account: TestData.account,
            password: password
        )

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(
            account?.encryptedSeed?.substrateSeed,
            TestData.legacySubstrateSeed
        )
    }

    func testImportLegacyBackupWithoutVerifierRejectsWrongPassword() async throws {
        let encryptedAccount = try makeLegacyEncryptedAccount(
            password: "correct-password"
        )
        try useRealEncryptionService(account: encryptedAccount)

        do {
            _ = try await service?.importBackup(
                account: TestData.account,
                password: "wrong-password"
            )
            XCTFail("Expected the legacy backup password to be rejected")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.incorectPassword.localizedDescription
            )
        }
    }

    func testImportLegacyBackupWithoutVerifierRejectsMismatchedAddress() async throws {
        let encryptedAccount = try makeLegacyEncryptedAccount(
            password: "legacy-password",
            address: TestData.emptyAccount.address
        )
        try useRealEncryptionService(account: encryptedAccount)

        do {
            _ = try await service?.importBackup(
                account: TestData.account,
                password: "legacy-password"
            )
            XCTFail("Expected the legacy backup address to be rejected")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.incorectJson.localizedDescription
            )
        }
    }

    func testImportLegacyBackupWithoutVerifierRejectsTamperedCiphertext() async throws {
        var encryptedAccount = try makeLegacyEncryptedAccount(
            password: "legacy-password"
        )
        let encryptedSeed = try XCTUnwrap(
            encryptedAccount.encryptedSeed?.substrateSeed
        )
        encryptedAccount.encryptedSeed?.substrateSeed = tamperLastHexDigit(
            encryptedSeed
        )
        try useRealEncryptionService(account: encryptedAccount)

        do {
            _ = try await service?.importBackup(
                account: TestData.account,
                password: "legacy-password"
            )
            XCTFail("Expected tampered legacy ciphertext to be rejected")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.incorectPassword.localizedDescription
            )
        }
    }

    func testImportBackupRejectsVerifierForDifferentAddress() async throws {
        let password = "current-password"
        var encryptedAccount = try makeLegacyEncryptedAccount(password: password)
        encryptedAccount.keyVerifier = try XCTUnwrap(
            EncryptionService().createEncryptedData(
                with: password,
                message: "different-address"
            )
        ).toHex()
        try useRealEncryptionService(account: encryptedAccount)

        do {
            _ = try await service?.importBackup(
                account: TestData.account,
                password: password
            )
            XCTFail("Expected a mismatched verifier to be rejected")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.incorectPassword.localizedDescription
            )
        }
    }

    func testImportLegacyJSONOnlyBackupWithoutVerifierWithCorrectPassword() async throws {
        let password = "legacy-json-password"
        let json = try makeLegacySubstrateJSON(password: password)
        let encryptedAccount = EcryptedBackupAccount(
            name: TestData.account.name ?? "",
            address: TestData.account.address,
            keyVerifier: nil,
            encryptedMnemonicPhrase: nil,
            encryptedSubstrateDerivationPath: nil,
            encryptedEthDerivationPath: nil,
            cryptoType: TestData.account.cryptoType,
            backupAccountType: [OpenBackupAccount.BackupAccountType.json.rawValue],
            json: OpenBackupAccount.Json(substrateJson: json),
            encryptedSeed: nil
        )
        try useRealEncryptionService(account: encryptedAccount)

        let account = try await service?.importBackup(
            account: TestData.account,
            password: password
        )

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(account?.json?.substrateJson, json)
    }

    func testImportBackupAccountWithError() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        googleService?.account = TestData.encryptedAccount

        // act
        do {
            let account = try await service?.importBackup(
                account: TestData.emptyAccount,
                password: "1"
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notFound.localizedDescription
            )
        }
    }

    func testDeleteBackupAccount() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        try await service?.deleteBackup(account: TestData.account)

        // assert
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 3)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 5)

        XCTAssertTrue(googleService?.setAuthorizerCalled ?? false)
        XCTAssertTrue(googleService?.executeQueryCalled ?? false)
    }

    func testDeleteBackupAccountWithError() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        do {
            try await service?.deleteBackup(account: TestData.emptyAccount)
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                FearlessExtensionError.backupNotFound.localizedDescription
            )
        }
    }

    func testDisconnect() {
        // act
        service?.disconnect()

        // assert
        XCTAssertEqual(signInProvider?.signOutCallsCount, 1)
        XCTAssertEqual(signInProvider?.disconnectCompletionCallsCount, 1)

        XCTAssertTrue(signInProvider?.signOutCalled ?? false)
        XCTAssertTrue(signInProvider?.disconnectCompletionCalled ?? false)
    }
}

extension CloudStorageServiceTests {
    enum TestData {
        static let user = GIDGoogleUserMock()

        static let substrateJson = """
        {\"address\":\"cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ\",\"encoded\":\"AAUbK8HDAE7Mw26rox6dktexv9pG5MRk\\/WtCJFtV2+kAgAAAAQAAAAgAAACivZKIFh9rMwauWG97MJ0ONwPg6eOpXNygK6X9RQfKMPvETRAfpHbRJp42LKEeWDNczqKaxltMj3yeMUi9kOYIz1sXMt7g7PC7aHUvSsF2G8nzV+XrNpC7nc8s+ty1OmVeKJWsSACfNj3OW9gxesmAtpfSrWx2ppSviKwvU1SKNYPfq+rxFCG+sXx4lggOFouAmT5iaPTL9fck\\/1vI\",\"encoding\":{\"content\":[\"pkcs8\",\"sr25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"meta\":{\"genesisHash\":\"0xded5a658e6ff2c82ce640caf8910ea2bb700aad5511ec7c3014cc7c256f5d956\",\"name\":\"chop\",\"whenCreated\":1706609064}}
        """

        static let substrateSeed = """
        0ffea7239c86f2c57976bb2ae65f0fe183ad40b5450edd2c0f2610aab80e9ae70080000001000000080000009f92ff8b19a2fc6eb7b68b746d9c6b6a21710d82b13704e62a7b90e402b8cd879b4f859f7da243bcc9f9674435e08fcd1a3562e500b99d3e40508bdd34e54819e3b79153097995f687ad3180852a3b1f05a657919ec8dcf2f0f0ed88693e0a263aa7ec0ff1106763e842
        """

        static let legacySubstrateSeed =
            "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"

        static let account = OpenBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            passphrase: "carpet shiver bacon dirt sadness hammer isolate window hope lounge humble kitten",
            cryptoType: "SR25519",
            substrateDerivationPath: nil,
            ethDerivationPath: nil,
            backupAccountType: [.passphrase, .json, .seed],
            json: OpenBackupAccount
                .Json(substrateJson: substrateJson),
            encryptedSeed: OpenBackupAccount.Seed()
        )

        static let encryptedAccount = EcryptedBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            keyVerifier: "6b07b1cb82cb6f35db50385a3326f85554487de6cedcb4476cd0eca3b14cb04d00800000010000000800000061e9dee22479b55961bba585d2db532b7d5726dd5d6a4c9abab356fd20820eef884ead766256a06e1506a92503fb01a0ee4b889b6a77eafbf6bef710168b467797d69b44135f37ea8716339e5af9ef70b88933b24da89c7a81",
            encryptedMnemonicPhrase: nil,
            encryptedSubstrateDerivationPath: "5944fbdce78478ef92858817b176fe0b5b884e9c8652de8e10061f0680f83c3100800000010000000800000012e34d41a1843fe84e627672c688150b2ab19c12e7d6b77dab91457f3e8f06a1ca66218604f14691",
            encryptedEthDerivationPath: nil,
            cryptoType: "SR25519",
            backupAccountType: [
                "passphrase",
                "json",
                "seed",
            ],
            json: OpenBackupAccount
                .Json(substrateJson: substrateJson),
            encryptedSeed: OpenBackupAccount
                .Seed(substrateSeed: substrateSeed)
        )

        static let emptyAccount = OpenBackupAccount(address: "")
    }

    func getURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(TestData.encryptedAccount.address)")
            .appendingPathExtension("json")
        let data = try JSONEncoder().encode(TestData.encryptedAccount)
        try data.write(to: url)
        return url
    }

    private func makeLegacyEncryptedAccount(
        password: String,
        address: String = TestData.account.address
    ) throws -> EcryptedBackupAccount {
        let encryptedSeed = try XCTUnwrap(
            EncryptionService().createEncryptedData(
                with: password,
                message: TestData.legacySubstrateSeed
            )
        )

        return EcryptedBackupAccount(
            name: TestData.account.name ?? "",
            address: address,
            keyVerifier: nil,
            encryptedMnemonicPhrase: nil,
            encryptedSubstrateDerivationPath: nil,
            encryptedEthDerivationPath: nil,
            cryptoType: TestData.account.cryptoType,
            backupAccountType: [OpenBackupAccount.BackupAccountType.seed.rawValue],
            json: nil,
            encryptedSeed: OpenBackupAccount.Seed(
                substrateSeed: encryptedSeed.toHex()
            )
        )
    }

    private func makeLegacySubstrateJSON(password: String) throws -> String {
        let keystoreData = KeystoreData(
            address: TestData.account.address,
            secretKeyData: Data(repeating: 7, count: 64),
            publicKeyData: Data(repeating: 9, count: 32),
            cryptoType: SSFModels.CryptoType.sr25519
        )
        let definition = try KeystoreBuilder().build(
            from: keystoreData,
            password: password,
            isEthereum: false
        )
        let data = try JSONEncoder().encode(definition)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func useRealEncryptionService(
        account: EcryptedBackupAccount
    ) throws {
        let signInProvider = try XCTUnwrap(signInProvider)
        let googleService = try XCTUnwrap(googleService)
        let queue = try XCTUnwrap(queue)
        let factory = try XCTUnwrap(factory)

        signInProvider._currentUser = TestData.user
        googleService.account = account
        service = CloudStorageService(
            uiDelegate: delegate,
            signInProvider: signInProvider,
            googleDriveService: googleService,
            queue: queue,
            encryptionService: EncryptionService(),
            fileFactory: factory
        )
    }

    private func tamperLastHexDigit(_ value: String) -> String {
        guard let last = value.last else {
            return value
        }

        return String(value.dropLast()) + (last == "0" ? "1" : "0")
    }
}
