import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import GoogleSignIn
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

        guard let signInProvider else { throw CloudStorageServiceTestsError.noSignInProviderExists }

        self.signInProvider = signInProvider
        self.delegate = delegate
        self.queue = queue
        self.googleService = googleService
        self.encryptionService = encryptionService
        self.factory = factory

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
        signInProvider?.signInCallsCount = 0
        signInProvider?.signInClosure = nil
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
        static let user = GIDGoogleUser()

        static let substrateJson = """
        {\"address\":\"cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ\",\"encoded\":\"AAUbK8HDAE7Mw26rox6dktexv9pG5MRk\\/WtCJFtV2+kAgAAAAQAAAAgAAACivZKIFh9rMwauWG97MJ0ONwPg6eOpXNygK6X9RQfKMPvETRAfpHbRJp42LKEeWDNczqKaxltMj3yeMUi9kOYIz1sXMt7g7PC7aHUvSsF2G8nzV+XrNpC7nc8s+ty1OmVeKJWsSACfNj3OW9gxesmAtpfSrWx2ppSviKwvU1SKNYPfq+rxFCG+sXx4lggOFouAmT5iaPTL9fck\\/1vI\",\"encoding\":{\"content\":[\"pkcs8\",\"sr25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"meta\":{\"genesisHash\":\"0xded5a658e6ff2c82ce640caf8910ea2bb700aad5511ec7c3014cc7c256f5d956\",\"name\":\"chop\",\"whenCreated\":1706609064}}
        """

        static let substrateSeed = """
        0ffea7239c86f2c57976bb2ae65f0fe183ad40b5450edd2c0f2610aab80e9ae70080000001000000080000009f92ff8b19a2fc6eb7b68b746d9c6b6a21710d82b13704e62a7b90e402b8cd879b4f859f7da243bcc9f9674435e08fcd1a3562e500b99d3e40508bdd34e54819e3b79153097995f687ad3180852a3b1f05a657919ec8dcf2f0f0ed88693e0a263aa7ec0ff1106763e842
        """

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
}
