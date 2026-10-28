// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import UIKit
import Lottie
import XCTest
import SoraUIKit
import SoraKeystore
import SoraFoundation
import CoreData
import CryptoKit
import Darwin
import NexusTransferCodec
import SSFUtils
import IrohaCrypto
@testable import SoraPassport

final class AnalyticsPriceAdmissionTests: XCTestCase {
    func testOnlyPositiveRecentQuotesAreUsable() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        func quote(_ price: String, _ timestamp: String) throws -> CoingeckoPriceData {
            let json = "{\"usd\":\(price),\"last_updated_at\":\(timestamp)}"
            return try JSONDecoder().decode(CoingeckoPriceData.self, from: Data(json.utf8))
        }
        XCTAssertTrue(try quote("1.25", "1999990").isUsable(at: now))
        XCTAssertFalse(try quote("0", "1999990").isUsable(at: now))
        XCTAssertFalse(try quote("-1", "1999990").isUsable(at: now))
        XCTAssertFalse(try quote("1", "1999099").isUsable(at: now))
        XCTAssertFalse(try quote("1", "2000061").isUsable(at: now))
        XCTAssertFalse(try quote("1", "null").isUsable(at: now))
    }
}

final class TairaFaucetAppTests: XCTestCase {
    private let receiveAddress = "testuﾛ1PﾍeｸﾊVZeｸYjﾛABRiﾕLｱｦｺjMﾀMAdYqﾊﾊCﾇｿﾓfreﾙ9M8GPH"

    private func account(network: NetworkId = .taira, key: Data? = nil) throws -> NetworkAccount {
        let parsed = try IrohaAddressCodec.parse(receiveAddress, expectedDiscriminant: 369)
        return NetworkAccount(walletId: "faucet-test-wallet", networkId: network, derivationVersion: 1,
            publicKey: try key ?? Data(hex: parsed.publicKeyHex), address: receiveAddress)
    }

    func testNativeFaucetScryptMatchesIndependentKnownAnswer() throws {
        // Python hashlib.scrypt, using the live puzzle's work parameters.
        let derived = try TairaFaucetService.scrypt(Data(repeating: 0, count: 8), Data(0..<32), 8192, 8, 1)
        XCTAssertEqual(derived, try Data(hex: "a68d2ca8fc05956205688b5e8776085c3f73328aad71aaabbbd0a85114369d49"))
    }

    func testFaucetOnlyAcceptsMatchingCurrentTairaAccount() throws {
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        let valid = try account()
        XCTAssertEqual(try TairaFaucetService.validatedPublicKey(account: valid, configuration: configuration), valid.publicKey)
        XCTAssertThrowsError(try TairaFaucetService.validatedPublicKey(account: valid, configuration: .minamoto))
        XCTAssertThrowsError(try TairaFaucetService.validatedPublicKey(account: account(network: .minamoto), configuration: configuration))
        XCTAssertThrowsError(try TairaFaucetService.validatedPublicKey(account: account(key: Data(repeating: 7, count: 32)), configuration: configuration))
    }

    func testPersistedFaucetRequestResumesWithoutAnotherClaim() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let account = try account()
        let hash = String(repeating: "b", count: 64)
        let pending = TairaFaucetService.PendingClaim(network: TairaClient.networkLiteral, account: account.address, transactionHash: hash, amount: "25000")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = SHA256.hash(data: Data((TairaClient.networkLiteral + "\n" + account.address).utf8)).map { String(format: "%02x", $0) }.joined() + ".json"
        let saved = directory.appendingPathComponent(filename)
        try JSONEncoder().encode(pending).write(to: saved)
        let client = TairaFaucetClient(scrypt: { _, _, _, _, _ in
            XCTFail("Recovery must never solve another claim")
            throw CancellationError()
        }, transport: { request, _ in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/pipeline/transactions/status")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, hash)
            return .init(data: Data("{\"hash\":\"\(hash)\",\"scope\":\"global\",\"resolved_from\":\"state\",\"status\":{\"kind\":\"Applied\",\"block_height\":75}}".utf8))
        })
        let service = TairaFaucetService(client: client, directory: directory)
        let before = try await service.hasPending(account: account.address)
        XCTAssertTrue(before)
        let outcome = try await service.request(account: account, configuration: XCTUnwrap(NexusNetworkConfiguration.taira), contextIsCurrent: { true }, progress: { phase in
            guard case .checking = phase else { XCTFail("Recovery must only check the saved hash"); return }
        })
        XCTAssertEqual(outcome.state, .applied(blockHeight: 75))
        let after = try await service.hasPending(account: account.address)
        XCTAssertFalse(after)
        // A damaged journal fails closed instead of silently requesting more.
        try Data("broken".utf8).write(to: saved)
        do { _ = try await service.hasPending(account: account.address); XCTFail("Corrupt journal accepted") }
        catch { XCTAssertTrue(error is TairaFaucetService.Failure) }
    }

    @MainActor
    func testFaucetButtonIsVisibleOnlyOnTairaAndFitsNarrowLayout() throws {
        for configuration in [try XCTUnwrap(NexusNetworkConfiguration.taira), .minamoto] {
            let detail = NexusNetworkDetailViewController(account: try account(network: configuration.networkId),
                configuration: configuration, coordinator: nil, readClient: NexusToriiReadClient(), mutationUnavailableReason: nil)
            detail.loadViewIfNeeded()
            detail.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
            detail.view.layoutIfNeeded()
            func find(_ view: UIView) -> UIButton? {
                if view.accessibilityIdentifier == "taira.faucet.request" { return view as? UIButton }
                return view.subviews.compactMap(find).first
            }
            let button = detail.tableView.tableHeaderView.flatMap(find)
            if configuration.networkId == .taira {
                let button = try XCTUnwrap(button)
                XCTAssertTrue(button.isEnabled)
                XCTAssertGreaterThanOrEqual(button.bounds.height, 48)
                XCTAssertLessThanOrEqual(button.bounds.width, 375)
                let image = UIGraphicsImageRenderer(bounds: detail.view.bounds).image { context in
                    detail.view.layer.render(in: context.cgContext)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "Taira faucet screen"
                attachment.lifetime = .keepAlways
                add(attachment)
            } else { XCTAssertNil(button) }
        }
    }
}

final class WalletUXTests: XCTestCase {
    func testTairaPendingJournalRetainsAndCannotChangeSigningNetwork() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        let store = try NexusPendingTransactionStore(baseURL: directory)
        let now = Date()
        var pending = NexusPendingTransaction(
            id: UUID(), idempotencyKey: UUID(), walletId: "test-wallet", networkId: .taira,
            chainId: configuration.chainId, signingNetworkId: TairaClient.networkLiteral,
            sender: "testuﾛ1PﾍeｸﾊVZeｸYjﾛABRiﾕLｱｦｺjMﾀMAdYqﾊﾊCﾇｿﾓfreﾙ9M8GPH",
            receiver: "testuﾛ1Pｷﾁﾉﾛｶﾋ2rﾃﾏjﾑtﾒﾛヱﾑ6783ｸwoZPi5ﾑﾇfM5JﾌｼzﾕT5VTX6",
            assetDefinitionID: TairaClient.xorDefinition, amount: try PIQuantity("0.001"),
            fee: try PIQuantity("0.01"), createdAt: now, updatedAt: now, hash: nil,
            state: .signing, terminalBlockHeight: nil, errorClass: nil, historyReconciledAt: nil)
        pending = try await store.put(pending)
        let reloaded = try await store.all()
        XCTAssertEqual(reloaded, [pending])
        XCTAssertTrue(pending.hasCurrentDeploymentIdentity(for: configuration))
        pending.signingNetworkId = nil
        do {
            _ = try await store.put(pending)
            XCTFail("A persisted send must not lose its signing network")
        } catch { XCTAssertTrue(error is NexusToriiError) }
        pending.signingNetworkId = "different-testnet-genesis"
        XCTAssertFalse(pending.hasCurrentDeploymentIdentity(for: configuration))
        do {
            _ = try await store.put(pending)
            XCTFail("A send from another genesis must not enter the current journal")
        } catch { XCTAssertTrue(error is NexusToriiError) }
        let retained = try await store.all()
        XCTAssertEqual(retained, reloaded)
    }

    func testTairaSendQualificationDoesNotEnableProduction() throws {
        let signer = TairaTransactionSigner()
        let reader = TairaToriiConfirmationReader()
        let taira = try XCTUnwrap(NexusNetworkConfiguration.taira)
        XCTAssertTrue(signer.isQualified(for: taira))
        XCTAssertTrue(reader.isQualified(for: taira))
        XCTAssertFalse(signer.isQualified(for: .minamoto))
        XCTAssertFalse(reader.isQualified(for: .minamoto))
        let settings = InMemorySettingsManager()
        settings.nexusEnabled = true
        settings.isTairaEnabled = true
        XCTAssertTrue(settings.nexusSendsEnabled(for: .taira))
        XCTAssertFalse(settings.nexusSendsEnabled(for: .minamoto))
        settings.isTairaEnabled = false
        XCTAssertFalse(settings.nexusSendsEnabled(for: .taira))
        settings.isTairaEnabled = true
        settings.nexusEnabled = false
        XCTAssertFalse(settings.nexusSendsEnabled(for: .taira))
    }

    func testTairaCurrentLiveSubmissionReceiptAndChecksumBinding() throws {
        // Public controlled canary: 0.001 XOR, fee 0.01, applied at block 74.
        let fixture = #"""
        {"content":[{"type":"text","text":"http 200"}],"isError":false,"resultType":"complete","_meta":{"io.modelcontextprotocol/serverInfo":{"name":"iroha-torii-mcp","version":"2.0.0-rc.2.0"}},"structuredContent":{"attempts":3,"elapsed_ms":1489,"hash":"4a48384ad05a8e1669baf4cd0ed83773f006f178e486ad421bcf2abcadd658a1","status":200,"terminal_kind":"Applied","final":{"body":{"hash":"4a48384ad05a8e1669baf4cd0ed83773f006f178e486ad421bcf2abcadd658a1","resolved_from":"state","scope":"global","status":{"block_height":74,"kind":"Applied"}},"content_type":"application/json; charset=utf-8","headers":{"content-type":"application/json; charset=utf-8","vary":"Accept"},"status":200},"submit":{"body":{"payload":{"entrypoint_hash":"hash:4A48384AD05A8E1669BAF4CD0ED83773F006F178E486AD421BCF2ABCADD658A1#EC45","signed_transaction_hash":"hash:4A48384AD05A8E1669BAF4CD0ED83773F006F178E486AD421BCF2ABCADD658A1#EC45","signer":"e7012102B9A460EEDA8A8FE990F963BF58084A9D6E6DAB8C6267454A9DEE9A369BBD3D8B","submitted_at_height":73,"submitted_at_ms":1791874407875},"signature":"67A6412192176609480398C63614A09959B9FA853747FF3EC269519D3E8D6D760C339392AB80DCAA8BE58C263DFA40013DE6531EB19F08B19B37A9419F4526DD"},"content_type":"application/json; charset=utf-8","headers":{"content-type":"application/json; charset=utf-8","x-iroha-entrypoint-hash":"4a48384ad05a8e1669baf4cd0ed83773f006f178e486ad421bcf2abcadd658a1","x-iroha-route-dataspace-id":"0","x-iroha-route-lane-id":"0","x-iroha-routed-by":"local","x-iroha-signed-transaction-hash":"4a48384ad05a8e1669baf4cd0ed83773f006f178e486ad421bcf2abcadd658a1","vary":"Accept"},"status":202}}}
        """#
        let hash = "4a48384ad05a8e1669baf4cd0ed83773f006f178e486ad421bcf2abcadd658a1"
        func parse(_ json: String) throws -> NexusTairaAppliedSubmission {
            try NexusTairaTransactionSubmissionContract.appliedSubmission(
                from: JSONDecoder().decode(NexusJSONValue.self, from: Data(json.utf8)), expectedHash: hash)
        }
        XCTAssertEqual(try parse(fixture).blockHeight, 74)
        XCTAssertEqual(try parse(fixture).hash, hash)
        XCTAssertThrowsError(try parse(fixture.replacingOccurrences(of: "#EC45", with: "#EC44")))
        XCTAssertThrowsError(try parse(fixture.replacingOccurrences(of: "Applied", with: "Approved")))
        XCTAssertThrowsError(try parse(fixture.replacingOccurrences(of: "\"block_height\":74", with: "\"block_height\":0")))
    }

    func testNexusHistoryBrowsingBeyondFormerAccountLimit() throws {
        var cursor = NexusHistoryCursor()
        for pageNumber in 1...25 {
            let ids = (0..<100).map { "\(pageNumber):\($0)" }
            try cursor.accept(NexusCursorHistoryPage(items: [], sourceItemIDs: ids, nextCursor: pageNumber < 25 ? "cursor_\(pageNumber)" : nil))
        }
        XCTAssertNil(cursor.nextCursor)
        XCTAssertFalse(cursor.hasMore)
    }

    func testNexusHistoryCursorRejectsChangedSnapshotWithoutAdvancing() throws {
        var cursor = NexusHistoryCursor()
        try cursor.accept(NexusCursorHistoryPage(items: [], sourceItemIDs: ["first"], nextCursor: "next"))
        XCTAssertThrowsError(try cursor.accept(NexusCursorHistoryPage(items: [], sourceItemIDs: ["second"], nextCursor: "next")))
        XCTAssertEqual(cursor.nextCursor, "next")
        XCTAssertThrowsError(try cursor.accept(NexusCursorHistoryPage(items: [], sourceItemIDs: ["first"], nextCursor: "third")))
        XCTAssertEqual(cursor.nextCursor, "next")
        // Bounded scans can advance through empty pages.
        try cursor.accept(NexusCursorHistoryPage(items: [], sourceItemIDs: [], nextCursor: "third"))
        XCTAssertTrue(cursor.hasMore)
        try cursor.accept(NexusCursorHistoryPage(items: [], sourceItemIDs: ["second"], nextCursor: nil))
        XCTAssertFalse(cursor.hasMore)
    }

    func testNexusRecoveryHistoryRequiresCompleteExactHashProjection() throws {
        let hash = String(repeating: "a", count: 64)
        let request = try NexusTairaMCPToolContract.accountHistoryRequest(
            id: "exact-history", account: "test-account",
            assetDefinitionID: NexusAssetDefinitionIdentity.tairaXorDefinitionID,
            cursor: nil, transactionHash: hash
        )
        let filter = try XCTUnwrap(request.params.nexusTestObject?["arguments"]?.nexusTestObject?["filter"]?.nexusTestString)
        XCTAssertTrue(filter.contains("tx_hash = \"\(hash)\""))
        XCTAssertThrowsError(try NexusTairaMCPToolContract.accountHistoryRequest(
            id: "bad", account: "account", assetDefinitionID: NexusAssetDefinitionIdentity.tairaXorDefinitionID,
            cursor: nil, transactionHash: "invalid"
        ))
    }

    func testTairaCursorMovementProjectionAndLocalRoute() throws {
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        let account = "testuﾛ1NｼXCeｱﾈﾁRｴUﾀPWﾏVｱrﾋhESEbpﾂｾ9Vﾗ5ﾇJｵavsｷ26TMSNN"
        let receiver = "testuﾛ1Q1ﾘﾚxgﾁﾃﾀdRZﾀWｿfXLGﾜﾘPﾐﾉﾉkﾃ7ﾖｶBｹssﾙﾈjｷｹUNYWHP"
        let asset = NexusAssetDefinitionIdentity.tairaXorDefinitionID
        let hash = String(repeating: "a", count: 64)
        var row: [String: NexusJSONValue] = [
            "id": .string("\(hash):\(account):0"), "source": .string("transaction"),
            "type": .string("TRANSFER"), "timestamp_ms": .number("1775260800000"),
            "status": .string("SUCCESS"), "result_ok": .bool(true), "direction": .string("outgoing"),
            "account_id": .string(account), "counterparty_account_id": .string(receiver),
            "asset_id": .string("\(asset)#\(account)"), "asset_definition_id": .string(asset),
            "amount": .string("1.5"), "tx_hash": .string(hash),
            "block_height": .number("42"), "block_index": .number("0"), "movement_index": .number("0"),
        ]
        func projection(_ row: [String: NexusJSONValue]) -> NexusJSONValue {
            .object(["body": .object(["items": .array([.object(row)]), "next_cursor": .string("next_cursor")])])
        }
        let page = try NexusTransferHistoryParser.cursorPage(result: projection(row), configuration: configuration, account: account, assetDefinitionID: asset)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.amount.rawValue, "1.5")
        XCTAssertEqual(page.items.first?.transactionHash, hash)
        XCTAssertEqual(page.nextCursor, "next_cursor")
        row["amount"] = .string("1.0000000001")
        XCTAssertThrowsError(try NexusTransferHistoryParser.cursorPage(result: projection(row), configuration: configuration, account: account, assetDefinitionID: asset))
        row["amount"] = .string("1.5")
        row["account_id"] = .string(receiver)
        XCTAssertThrowsError(try NexusTransferHistoryParser.cursorPage(result: projection(row), configuration: configuration, account: account, assetDefinitionID: asset))
        row["account_id"] = .string(account)
        row["status"] = .string("FAILED")
        row["result_ok"] = .bool(false)
        XCTAssertThrowsError(try NexusTransferHistoryParser.cursorPage(result: projection(row), configuration: configuration, account: account, assetDefinitionID: asset))
        var headers = ["x-iroha-routed-by": "local", "x-iroha-route-lane-id": "0", "x-iroha-route-dataspace-id": "0"]
        XCTAssertNoThrow(try NexusToriiClient.validateFanoutHeaderValues({ headers[$0] }, allowsPublicLocalRoute: true))
        XCTAssertThrowsError(try NexusToriiClient.validateFanoutHeaderValues({ headers[$0] }))
        headers["x-iroha-fanout-routes-attempted"] = "1"
        XCTAssertThrowsError(try NexusToriiClient.validateFanoutHeaderValues({ headers[$0] }, allowsPublicLocalRoute: true))
    }

    func testTairaLiveAnonymousReads() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SORA_LIVE_TAIRA_READS"] == "1", "Opt-in public read-only integration check")
        let configuration = try XCTUnwrap(NexusNetworkConfiguration.taira)
        let client = NexusToriiClient()
        let account = "testuﾛ1NｼXCeｱﾈﾁRｴUﾀPWﾏVｱrﾋhESEbpﾂｾ9Vﾗ5ﾇJｵavsｷ26TMSNN"
        try await client.health(configuration: configuration)
        let definition = try await client.xorAssetDefinition(configuration: configuration)
        XCTAssertEqual(definition.id, NexusAssetDefinitionIdentity.tairaXorDefinitionID)
        let balances = try await client.accountAssets(account: account, configuration: configuration, asset: definition.id, limit: 100, offset: 0)
        XCTAssertNoThrow(try NexusBalanceValidator.xorBalance(in: balances, account: account, configuration: configuration, assetDefinitionID: definition.id))
        let history = try await client.transferHistoryPage(account: account, configuration: configuration, assetDefinitionID: definition.id, cursor: nil)
        XCTAssertLessThanOrEqual(history.items.count, 100)
    }

    func testNexusProductionAddressExistsWithoutLiveTransport() throws {
        let production = NexusNetworkConfiguration.minamoto
        XCTAssertFalse(production.isLive)
        XCTAssertFalse(NexusNetworkConfiguration.transportIsAdmitted(for: production.toriiURL))
        XCTAssertTrue(NexusNetworkConfiguration.admittedWalletNetworkIds.contains(.minamoto))
        XCTAssertTrue(try XCTUnwrap(NexusNetworkConfiguration.taira).isLive)
        let tairaReadOnly = NexusPortfolioPresentationPolicy.networkDetailAccess(
            networkId: .taira, nexusEnabled: true, tairaEnabled: true,
            tairaAdmitted: true, mutationCoordinatorAvailable: false
        )
        XCTAssertTrue(tairaReadOnly.readsAvailable)
        XCTAssertFalse(tairaReadOnly.mutationSurfaceAvailable)
        XCTAssertTrue(NexusPortfolioPresentationPolicy.networkDetailIsAvailable(
            networkId: .minamoto, nexusEnabled: true, tairaEnabled: false, tairaAdmitted: true
        ))
    }

    func testTairaMCPMetadataOnEveryRequestKind() throws {
        let requests = [
            NexusTairaMCPToolContract.initializeRequest(id: "init"),
            try NexusTairaMCPToolContract.discoveryRequest(id: "list", toolsetVersion: String(repeating: "a", count: 64), cursor: nil),
            NexusTairaMCPToolContract.healthRequest(id: "health"),
        ]
        for request in requests {
            let metadata = try XCTUnwrap(request.params.nexusTestObject?["_meta"]?.nexusTestObject)
            XCTAssertEqual(metadata["io.modelcontextprotocol/protocolVersion"], .string("2026-07-28"))
            XCTAssertEqual(metadata["io.modelcontextprotocol/clientCapabilities"], .object([:]))
        }
    }

    @MainActor
    func testAppearanceDefaultNeverMutatesRetainedUpgradePreferences() throws {
        let identifier = "sora-neon-appearance-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: identifier))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let previousTheme = SoramitsuUI.shared.themeMode
        defer {
            defaults.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: directory)
            SoramitsuUI.shared.themeMode = previousTheme
        }
        defaults.set("retained-value", forKey: "retained-setting")
        let retained = defaults.persistentDomain(forName: identifier) ?? [:]
        AppDelegate.applyFreshInstallAppearance(defaults: defaults, identifier: identifier,
            storageDirectories: [directory], keychainIsEmpty: { XCTFail("Retained settings do not need a Keychain read"); return true })
        XCTAssertEqual(NSDictionary(dictionary: defaults.persistentDomain(forName: identifier) ?? [:]), NSDictionary(dictionary: retained))

        defaults.removePersistentDomain(forName: identifier)
        let snapshot = directory.appendingPathComponent("settings-backup.plist")
        try Data("public-fixture".utf8).write(to: snapshot)
        AppDelegate.applyFreshInstallAppearance(defaults: defaults, identifier: identifier,
            storageDirectories: [directory], keychainIsEmpty: { XCTFail("Retained files do not need a Keychain read"); return true })
        XCTAssertTrue((defaults.persistentDomain(forName: identifier) ?? [:]).isEmpty)
        try FileManager.default.removeItem(at: snapshot)

        AppDelegate.applyFreshInstallAppearance(defaults: defaults, identifier: identifier,
            storageDirectories: [directory], keychainIsEmpty: { false })
        XCTAssertTrue((defaults.persistentDomain(forName: identifier) ?? [:]).isEmpty,
            "Retained or unreadable Keychain data must not create a preference marker")
        AppDelegate.applyFreshInstallAppearance(defaults: defaults, identifier: identifier,
            storageDirectories: [directory], keychainIsEmpty: { true })
        XCTAssertTrue(defaults.bool(forKey: "sora.neon.appearance-default-reviewed"))
        XCTAssertEqual(SoramitsuUI.shared.themeMode, .manual(.dark))
    }

    @MainActor
    func testNeonPINKeysDeleteAndClearPreserveFourAndSixDigitInput() throws {
        for count in [4, 6] {
            let controller = PincodeViewController()
            let presenter = NeonPINVisualPresenter(view: controller, count: count)
            controller.presenter = presenter
            controller.loadViewIfNeeded()
            for digit in [1, 2, 0] { controller.numpadView.buttons[digit].sendActions(for: .touchUpInside) }
            XCTAssertEqual(presenter.input, "120")
            controller.numpadView.backspaceButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(presenter.input, "12")
            controller.numpadViewDidClearInput(controller.numpadView)
            XCTAssertEqual(presenter.input, "")
            let dots = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "InputFieldAccessibilityId" })
            XCTAssertEqual(dots.accessibilityValue, R.string.localizable.neonPinCount(0, count, preferredLanguages: .currentLocale))
            for key in controller.numpadView.buttons {
                XCTAssertEqual(key.accessibilityLabel, String(key.tag))
                XCTAssertTrue(key.accessibilityTraits.contains(.button))
            }
        }
    }

    @MainActor
    func testBackupRequiresRevealAndClearsRenderedWordsOnBackground() throws {
        let controller = AccountCreateViewController()
        controller.localizationManager = LocalizationManager.shared
        controller.mode = .view
        controller.presenter = NeonBackupVisualPresenter()
        controller.loadViewIfNeeded()
        controller.set(mnemonic: ["public", "synthetic", "preview", "words"])
        controller.set(backupDerivationPath: "//public-preview")
        let reveal = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-backup-reveal" } as? UIButton)
        func renderedWords() -> [String] {
            descendants(controller.view).compactMap { ($0 as? UILabel)?.text }.filter { ["public", "synthetic", "preview", "words"].contains($0) }
        }
        XCTAssertTrue(renderedWords().isEmpty)
        reveal.sendActions(for: .touchUpInside)
        XCTAssertEqual(Set(renderedWords()), Set(["public", "synthetic", "preview", "words"]))
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(renderedWords().isEmpty)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(renderedWords().isEmpty, "returning never re-reveals a phrase")
        reveal.sendActions(for: .touchUpInside)
        XCTAssertEqual(renderedWords().count, 4, "the grid supports repeated hide/reveal")
        NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        XCTAssertTrue(renderedWords().isEmpty)
    }

    @MainActor
    func testMnemonicGridRemovesOldWordsWhenColumnsAndCountShrink() {
        let grid = MnemonicDisplayView(frame: .zero)
        grid.bind(words: ["old1", "old2", "old3", "old4"], columnsCount: 2)
        grid.bind(words: ["new1", "new2"], columnsCount: 1)
        let text = descendants(grid).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(text.contains("new1")); XCTAssertTrue(text.contains("new2"))
        XCTAssertFalse(text.contains { $0.hasPrefix("old") })
        grid.bind(words: [], columnsCount: 2)
        XCTAssertTrue(descendants(grid).compactMap { ($0 as? UILabel)?.text }.isEmpty)
    }

    @MainActor
    func testRecoveryPhraseAlsoRequiresASeparateRevealAfterThePIN() throws {
        let controller = WalletRecoveryPhraseViewController(entries: [
            .init(address: "public-preview", name: "Preview", words: ["public", "synthetic"], derivationPath: nil)
        ])
        controller.loadViewIfNeeded()
        let words = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-recovery-phrase-words" } as? UILabel)
        let reveal = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-recovery-phrase-reveal" } as? UIButton)
        XCTAssertNil(words.text)
        reveal.sendActions(for: .touchUpInside)
        XCTAssertTrue(words.text?.contains("synthetic") == true)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertNil(words.text)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertNil(words.text)
    }

    @MainActor
    func testRawSeedExportRequiresRevealAndHidesAgainAfterCapture() throws {
        let controller = AccountExportRawSeedViewController()
        controller.presenter = NeonRawSeedVisualPresenter()
        controller.loadViewIfNeeded()
        controller.set(rawSeed: "0xPUBLIC_SYNTHETIC_PREVIEW", derivationPath: "//public")
        let value = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-raw-seed-value" } as? UILabel)
        let reveal = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-raw-seed-reveal" } as? UIButton)
        XCTAssertNil(value.text)
        reveal.sendActions(for: .touchUpInside)
        XCTAssertEqual(value.text, "0xPUBLIC_SYNTHETIC_PREVIEW")
        NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        XCTAssertNil(value.text)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertNil(value.text)
    }

    @MainActor
    func testImportShieldCoversBackgroundWithoutDiscardingTypedMaterial() throws {
        let controller = UIViewController()
        controller.loadViewIfNeeded()
        let field = UITextField()
        field.text = "public-synthetic-import"
        controller.view.addSubview(field)
        let shield = WalletSensitiveScreenShield(controller: controller)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        let cover = try XCTUnwrap(controller.view.subviews.last)
        XCTAssertEqual(cover.accessibilityIdentifier, "wallet-secret-capture-shield")
        XCTAssertEqual(cover.backgroundColor?.cgColor.alpha, 1)
        XCTAssertEqual(field.text, "public-synthetic-import")
        shield.refresh()
        XCTAssertNil(controller.view.subviews.first { $0.accessibilityIdentifier == "wallet-secret-capture-shield" })
        XCTAssertEqual(field.text, "public-synthetic-import")
    }

    @MainActor
    func testNeonBodyFontsAreActuallyRegisteredInTheApp() throws {
        XCTAssertEqual(try XCTUnwrap(UIFont(name: "Inter-Regular", size: 16)).familyName, "Inter")
        XCTAssertNotNil(UIFont(name: "Inter-SemiBold", size: 16))
        XCTAssertNotNil(UIFont(name: "Inter-Bold", size: 16))
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.text = "Body font"
        let renderedFont = try XCTUnwrap(label.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertEqual(renderedFont.fontName, "Inter-Regular")
    }

    /// Store media uses production controllers; only their presentation data is synthetic.
    /// This opt-in path never imports keys, reads a selected wallet, or submits a transaction.
    @MainActor
    func testRecipientEditingClearsOnlyPreviousValueValidationAndClearRestoresSearch() {
        let model = StoreContactsPresentation()
        let controller = ContactsViewController(viewModel: model)
        controller.loadViewIfNeeded()
        let field = controller.field
        XCTAssertEqual(field.textField.placeholder, R.string.localizable.selectAccountAddress1(preferredLanguages: .currentLocale))
        XCTAssertEqual(field.textField.autocapitalizationType, .none)
        XCTAssertEqual(field.textField.autocorrectionType, .no)
        XCTAssertEqual(field.textField.spellCheckingType, .no)
        controller.show(error: "Synthetic same-account error")
        XCTAssertEqual(field.sora.state, .fail)
        field.sora.state = .focused
        XCTAssertEqual(field.sora.state, .fail, "Focus alone must retain a validation result")
        field.textField.text = "abc"
        field.textField.sendActions(for: .editingChanged)
        XCTAssertEqual(model.searches, ["abc"])
        XCTAssertNotEqual(field.sora.state, .fail)
        XCTAssertNil(field.sora.descriptionLabelText)
        XCTAssertTrue(field.descriptionLabel.isHidden)
        XCTAssertFalse(field.titleLabel.isHidden)
        controller.show(error: "Synthetic invalid-address error")
        field.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(model.searches, ["abc", ""])
        XCTAssertEqual(field.textField.text, "")
        XCTAssertTrue(field.titleLabel.isHidden)
        XCTAssertTrue(field.descriptionLabel.isHidden)
        XCTAssertNotEqual(field.sora.state, .fail)
        field.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(model.qrRequests, 1)
    }

    @MainActor
    func testSendRecipientPromptSurvivesEmptyAddressAndShowsPublicRecipient() throws {
        let controller = InputAssetAmountViewController(viewModel: StoreAmountPresentation())
        controller.loadViewIfNeeded()
        let contact = controller.recipientView.contactView
        controller.updateRecipientView(with: "")
        XCTAssertEqual(contact.accountTitle.text, R.string.localizable.selectRecipient(preferredLanguages: .currentLocale))
        let placeholder = try XCTUnwrap(contact.accountImageView.image?.pngData())
        let address = try SS58AddressFactory().address(fromAccountId: Data(repeating: 0x42, count: 32), type: SNAddressType(chain: .sora))
        controller.updateRecipientView(with: address)
        XCTAssertEqual(contact.accountTitle.text, address)
        XCTAssertNotEqual(try XCTUnwrap(contact.accountImageView.image?.pngData()), placeholder)
        controller.updateRecipientView(with: "")
        XCTAssertEqual(contact.accountTitle.text, R.string.localizable.selectRecipient(preferredLanguages: .currentLocale))
        XCTAssertEqual(contact.accountImageView.image?.pngData(), placeholder)
    }

    @MainActor
    func testLaunchScreenStaysDarkBeforeAppAppearancePreferencesLoad() throws {
        let launch = try XCTUnwrap(Bundle.main.loadNibNamed("LaunchScreen", owner: nil)?.compactMap { $0 as? UIView }.first)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let color = try XCTUnwrap(launch.backgroundColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            XCTAssertEqual(color, NeonTokens.dark.canvas, "The system launch screen cannot read the app's saved dark preference")
        }
    }

    @MainActor
    func testFastStartupPlaysTheOriginalSplashBeforeLeaving() async throws {
        let previousTheme = SoramitsuUI.shared.themeMode
        let previousEffects = FxPolicy.reduceEffects
        defer {
            SoramitsuUI.shared.themeMode = previousTheme
            FxPolicy.reduceEffects = previousEffects
        }
        SoramitsuUI.shared.themeMode = .manual(.dark)
        FxPolicy.reduceEffects = false
        let controller = SplashViewController()
        let window = makeSceneHostedWindow(frame: UIScreen.main.bounds)
        let finished = expectation(description: "Original splash finishes after fast startup")
        var completions = 0
        let start = CACurrentMediaTime()
        // Startup may be ready even before UIKit displays its root controller.
        controller.animate(duration: 2) { completions += 1; finished.fulfill() }
        XCTAssertEqual(completions, 0)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let animation = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? LottieAnimationView }.first)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(animation.isAnimationPlaying)
        XCTAssertLessThan(animation.realtimeAnimationProgress, 0.8, "Fast readiness must not skip the ring introduction")
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(controller.view.backgroundColor, NeonTokens.dark.canvas)
        await fulfillment(of: [finished], timeout: 6)
        XCTAssertGreaterThan(CACurrentMediaTime() - start, 2.5)
        XCTAssertEqual(completions, 1)
        controller.animate(duration: 2) { XCTFail("Duplicate readiness must not navigate twice") }
    }

    @MainActor
    func testSlowStartupWaitsAtTheLogoUntilReady() async throws {
        let previousEffects = FxPolicy.reduceEffects
        FxPolicy.reduceEffects = false
        defer { FxPolicy.reduceEffects = previousEffects }
        let controller = SplashViewController()
        let window = makeSceneHostedWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let animation = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? LottieAnimationView }.first)
        try await Task.sleep(nanoseconds: 3_000_000_000)
        XCTAssertEqual(animation.currentProgress, 0.8, accuracy: 0.01)
        XCTAssertFalse(animation.isAnimationPlaying)
        let finished = expectation(description: "Ready startup leaves the held logo")
        let start = CACurrentMediaTime()
        controller.animate(duration: 2) { finished.fulfill() }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertLessThan(CACurrentMediaTime() - start, 1.5, "Slow startup must not replay the introduction")
    }

    @MainActor
    func testStoragePromptCancelsReadinessQueuedDuringSplash() async throws {
        let previousEffects = FxPolicy.reduceEffects
        FxPolicy.reduceEffects = false
        defer { FxPolicy.reduceEffects = previousEffects }
        let controller = SplashViewController()
        let window = makeSceneHostedWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.animate(duration: 2) { XCTFail("Old readiness must not bypass the storage prompt") }
        try await Task.sleep(nanoseconds: 200_000_000)
        var retries = 0
        controller.showStorageSpaceRetry { retries += 1 }
        try await Task.sleep(nanoseconds: 100_000_000)
        let retry = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == "wallet-upgrade-storage-retry"
        })
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(retries, 1)
        let finished = expectation(description: "Only fresh readiness leaves the storage retry")
        controller.animate(duration: 2) { finished.fulfill() }
        await fulfillment(of: [finished], timeout: 2)
    }

    @MainActor
    func testReducedEffectsSplashAndStorageRetryKeepStartupGated() throws {
        let previousEffects = FxPolicy.reduceEffects
        FxPolicy.reduceEffects = true
        defer { FxPolicy.reduceEffects = previousEffects }
        let controller = SplashViewController()
        let window = makeSceneHostedWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.viewDidAppear(false)
        let animation = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? LottieAnimationView }.first)
        XCTAssertFalse(animation.isAnimationPlaying)
        XCTAssertEqual(animation.currentProgress, 0.8, accuracy: 0.01)
        var retries = 0
        controller.showStorageSpaceRetry { retries += 1 }
        let retry = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == "wallet-upgrade-storage-retry"
        })
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(retries, 1)
        var completions = 0
        controller.animate(duration: 2) { completions += 1 }
        XCTAssertEqual(completions, 1)
        XCTAssertFalse(animation.isAnimationPlaying)
    }

    @MainActor
    func testLoadingShimmerFollowsThemeWithoutFlashingLoadedContent() async throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        let owner = SoramitsuLabel()
        owner.frame = CGRect(x: 0, y: 0, width: 220, height: 44)
        owner.sora.text = "Loaded public content"
        let placeholder = owner.sora.loadingPlaceholder
        placeholder.type = .shimmer
        var firstDarkColors: [CGColor] = []
        for theme in [SoramitsuThemeType.dark, .light, .dark] {
            SoramitsuUI.shared.themeMode = .manual(theme)
            try await Task.sleep(nanoseconds: 50_000_000)
            owner.layoutIfNeeded()
            let shimmer = placeholder.shimmerview
            XCTAssertTrue(shimmer.superview === owner)
            let gradient = try XCTUnwrap(shimmer.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
            let colors = try XCTUnwrap(gradient.colors as? [CGColor])
            XCTAssertEqual(colors.count, 3)
            func components(_ color: UIColor) -> [CGFloat] {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
                return [r, g, b, a]
            }
            if theme == .dark {
                let background = components(try XCTUnwrap(shimmer.backgroundColor))
                for color in colors {
                    let foreground = components(UIColor(cgColor: color))
                    for index in 0..<3 {
                        let displayed = foreground[index] * foreground[3] + background[index] * (1 - foreground[3])
                        XCTAssertLessThan(displayed, 0.3, "Dark loading placeholders must stay subdued, not white")
                    }
                }
                if firstDarkColors.isEmpty { firstDarkColors = colors }
                else { XCTAssertEqual(colors, firstDarkColors) }
            } else { XCTAssertNotEqual(colors, firstDarkColors) }
        }
        placeholder.type = .none
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(placeholder.shimmerview.superview)
        XCTAssertEqual(owner.text, "Loaded public content")
        XCTAssertTrue(owner.layer.animationKeys()?.isEmpty ?? true)
        for _ in 0..<3 { placeholder.type = .none }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(placeholder.shimmerview.superview)
        XCTAssertTrue(owner.layer.animationKeys()?.isEmpty ?? true, "Repeated completed loads must not cross-dissolve the owner")
    }

    @MainActor
    func testAmountAccessoryKeepsContrastAndReplacesButtons() async throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            func channel(_ value: CGFloat) -> CGFloat { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
            return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
        }
        let accessory = InputAccessoryView(frame: CGRect(x: 0, y: 0, width: 393, height: 48))
        let delegate = StoreAccessoryDelegate()
        accessory.delegate = delegate
        for theme in [SoramitsuThemeType.dark, .light] {
            SoramitsuUI.shared.themeMode = .manual(theme)
            accessory.variants = [25, 50, 75, 100].map { InputAccessoryVariant(displayValue: "\($0)%", value: Decimal($0) / 100) }
            try await Task.sleep(nanoseconds: 100_000_000)
            accessory.layoutIfNeeded()
            let buttons = accessory.stackView.arrangedSubviews.compactMap { $0 as? SoramitsuButton }
            XCTAssertEqual(buttons.count, 4)
            XCTAssertEqual(accessory.stackView.arrangedSubviews.count, 7)
            let background = luminance(try XCTUnwrap(accessory.backgroundColor))
            for button in buttons {
                let label = try XCTUnwrap(descendants(button).compactMap { $0 as? UILabel }.first { !($0.text ?? "").isEmpty })
                let color = (label.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor) ?? label.textColor!
                let foreground = luminance(color)
                XCTAssertGreaterThanOrEqual((max(foreground, background) + 0.05) / (min(foreground, background) + 0.05), 4.5)
            }
            accessory.variants = [InputAccessoryVariant(displayValue: "10%", value: 0.1), InputAccessoryVariant(displayValue: "100%", value: 1)]
            let replacement = accessory.stackView.arrangedSubviews.compactMap { $0 as? SoramitsuButton }
            XCTAssertEqual(replacement.count, 2)
            XCTAssertEqual(accessory.stackView.arrangedSubviews.count, 3)
            replacement.last?.sendActions(for: .touchUpInside)
            XCTAssertEqual(delegate.values.last, 1)
        }
        XCTAssertEqual(delegate.values.count, 2)
    }

    @MainActor
    func testSwapWordmarkFollowsAppThemeWhileOpen() async throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        SoramitsuUI.shared.themeMode = .manual(.light)
        let model = StoreSwapPresentation()
        let controller = PolkaswapViewController(viewModel: model)
        model.view = controller
        controller.loadViewIfNeeded()
        let view = try XCTUnwrap(controller.navigationItem.titleView as? UIImageView)
        let light = try XCTUnwrap(view.image?.pngData())
        SoramitsuUI.shared.themeMode = .manual(.dark)
        try await Task.sleep(nanoseconds: 100_000_000)
        let dark = try XCTUnwrap(view.image?.pngData())
        XCTAssertNotEqual(dark, light, "Dark appearance needs the high-contrast wordmark variant")
        SoramitsuUI.shared.themeMode = .manual(.light)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(view.image?.pngData(), light, "An open swap screen must follow app appearance changes")
    }

    @MainActor
    func testAssetDetailsNavigationContainerOffersWorkingClose() async throws {
        let previousWindow = UIApplication.shared.keyWindow
        defer { previousWindow?.makeKeyAndVisible() }
        let presenter = UIViewController()
        let window = makeSceneHostedWindow(frame: UIScreen.main.bounds)
        window.rootViewController = presenter; window.makeKeyAndVisible()
        let details = AssetDetailsViewController(viewModel: StoreAssetDetailsPresentation())
        let navigation = SoraNavigationController(rootViewController: details)
        let container = BlurViewController()
        container.modalPresentationStyle = .overFullScreen
        container.add(navigation)
        await withCheckedContinuation { continuation in
            presenter.present(container, animated: false) { continuation.resume() }
        }
        let item = try XCTUnwrap(details.navigationItem.rightBarButtonItem)
        XCTAssertEqual(item.accessibilityLabel, R.string.localizable.commonClose(preferredLanguages: nil))
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertTrue(UIApplication.shared.sendAction(try XCTUnwrap(item.action), to: item.target, from: item, for: nil))
        for _ in 0..<60 {
            if presenter.presentedViewController == nil { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertNil(presenter.presentedViewController)
        window.isHidden = true; window.rootViewController = nil
    }


    @MainActor
    func testCaptureAppStoreScreenshots() async throws {
        guard ProcessInfo.processInfo.environment["SORA_CAPTURE_APP_STORE"] == "1" else {
            throw XCTSkip("Opt-in native App Store screenshots")
        }
        XCTAssertTrue(ProductSurfacePolicy.isAppStoreBuild, "Compile this capture host with F_RELEASE")
        let previousWindow = UIApplication.shared.keyWindow
        let previousTheme = SoramitsuUI.shared.themeMode
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppStoreScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer {
            previousWindow?.makeKeyAndVisible()
            SoramitsuUI.shared.themeMode = previousTheme
            LocalizationManager.shared.selectedLocalization = previousLanguage
        }
        LocalizationManager.shared.selectedLocalization = "en"
        // 428 × 926 points at native @3x: App Store 6.5-inch accepted 1284 × 2778 pixels.
        XCTAssertEqual(UIScreen.main.bounds.size, CGSize(width: 428, height: 926))
        XCTAssertEqual(UIScreen.main.scale, 3)
        let publicKey = Data(repeating: 0x42, count: 32)
        let address = try SS58AddressFactory().address(fromAccountId: publicKey, type: SNAddressType(chain: .sora))
        let encoder = WalletQREncoder(networkType: SNAddressType(chain: .sora), publicKey: publicKey, username: "Public demo wallet")
        let payload = try encoder.encode(receiverInfo: ReceiveInfo(accountId: publicKey.toHex(),
            assetId: WalletAssetId.xor.rawValue, amount: nil, details: ""))
        let operation = WalletQROperationFactory().createCreationOperation(for: payload,
            qrSize: CGSize(width: 300, height: 300))
        operation.start()
        let qrImage = try XCTUnwrap(operation.result).get()
        var records: [[String: Any]] = []
        for name in ["01-assets-dark", "02-receive-dark", "03-swap-dark", "04-pin-dark", "05-settings-dark", "06-settings-light", "07-assets-light", "08-receive-light", "09-swap-light", "10-pin-light"] {
            let light = name.hasSuffix("light")
            SoramitsuUI.shared.themeMode = .manual(light ? .light : .dark)
            AppearanceFactory.applyGlobalAppearance()
            let controller: UIViewController
            if name.contains("assets") {
                controller = UINavigationController(rootViewController: ProductListViewController(viewModel: StoreAssetPresentation()))
            } else if name.contains("receive") {
                controller = UINavigationController(rootViewController: GenerateQRViewController(
                    viewModel: StoreReceivePresentation(address: address, image: qrImage)))
            } else if name.contains("swap") {
                let model = StoreSwapPresentation()
                let swap = PolkaswapViewController(viewModel: model)
                model.view = swap
                controller = UINavigationController(rootViewController: swap)
            } else if name.contains("pin") {
                let pin = PincodeViewController()
                pin.mode = .securedInput
                pin.presenter = NeonPINVisualPresenter(view: pin, count: 6)
                controller = pin
            } else {
                controller = UINavigationController(rootViewController: AppSettingsFactory.createAppSettings().controller)
            }
            let window = makeSceneHostedWindow(frame: UIScreen.main.bounds)
            window.overrideUserInterfaceStyle = light ? .light : .dark
            window.backgroundColor = WalletUX.page
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.loadViewIfNeeded()
            try await Task.sleep(nanoseconds: 700_000_000)
            window.layoutIfNeeded()
            if ProcessInfo.processInfo.environment["SORA_CAPTURE_NATIVE"] == "1" {
                let acknowledgement = output.appendingPathComponent("capture-ack.txt")
                try? FileManager.default.removeItem(at: acknowledgement)
                try Data(name.utf8).write(to: output.appendingPathComponent("capture-request.txt"), options: .atomic)
                var acknowledged = false
                for _ in 0..<150 {
                    if (try? String(contentsOf: acknowledgement, encoding: .utf8)) == name { acknowledged = true; break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                XCTAssertTrue(acknowledged, "Native simulator capture must acknowledge \(name)")
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            format.opaque = true
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertEqual(image.cgImage?.width, 1284)
            XCTAssertEqual(image.cgImage?.height, 2778)
            let file = output.appendingPathComponent(name + ".png")
            try XCTUnwrap(image.pngData()).write(to: file)
            records.append(["file": file.lastPathComponent, "rootController": String(describing: type(of: controller)),
                            "width": 1284, "height": 2778, "language": "en", "theme": light ? "light" : "dark"])
            window.isHidden = true
            window.rootViewController = nil
        }
        let receipt: [String: Any] = ["screenshots": records, "publicSyntheticAddress": address,
            "publicKeyHex": publicKey.toHex(), "fixtureBalances": "All zero; synthetic presentation data, no balance claim about a live account",
            "secretsIncluded": false, "networkOrWalletReadRequired": false,
            "capture": "Native production-controller UIWindow.drawHierarchy at native size; no postprocessing"]
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("capture-receipt.json"))
    }

    @MainActor
    func testCaptureNeonReleaseVisualEvidence() async throws {
        guard ProcessInfo.processInfo.environment["SORA_CAPTURE_RECOVERY_UI"] == "1" else {
            throw XCTSkip("Opt-in production-screen capture")
        }
        let previousWindow = UIApplication.shared.keyWindow
        let previousTheme = SoramitsuUI.shared.themeMode
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeonReleaseVisualEvidence", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer {
            previousWindow?.makeKeyAndVisible()
            SoramitsuUI.shared.themeMode = previousTheme
            LocalizationManager.shared.selectedLocalization = previousLanguage
        }
        for language in ["en", "ja", "ar"] {
            LocalizationManager.shared.selectedLocalization = language
            for theme in [SoramitsuThemeType.light, .dark] {
                SoramitsuUI.shared.themeMode = .manual(theme)
                for large in [false, true] {
                    let window = makeSceneHostedWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
                    window.overrideUserInterfaceStyle = theme == .dark ? .dark : .light
                    for count in [4, 6, 0, -1, -2, -3, -4, -5] {
                        let controller: UIViewController
                        if count == -5 {
                            let account = PortfolioNoticeItem()
                            account.setCapability(.missingKeys)
                            controller = PortfolioNoticeVisualController(item: account)
                        } else if count <= -3 {
                            let seed = AccountExportRawSeedViewController()
                            seed.localizationManager = LocalizationManager.shared
                            seed.presenter = NeonRawSeedVisualPresenter()
                            controller = UINavigationController(rootViewController: seed)
                            seed.loadViewIfNeeded()
                            seed.set(rawSeed: "0x" + String(repeating: "0123456789abcdef", count: 4), derivationPath: "//public-preview")
                        } else if count < 0 {
                            let backup = AccountCreateViewController()
                            backup.localizationManager = LocalizationManager.shared
                            backup.mode = .view
                            backup.presenter = NeonBackupVisualPresenter()
                            controller = UINavigationController(rootViewController: backup)
                            backup.loadViewIfNeeded()
                            backup.set(mnemonic: Array(repeating: "abandon", count: 11) + ["about"])
                            backup.set(backupDerivationPath: "//public-preview")
                        } else if count == 0 {
                            controller = UINavigationController(rootViewController: AppSettingsFactory.createAppSettings().controller)
                        } else {
                            let pin = PincodeViewController()
                            pin.mode = .securedInput
                            pin.presenter = NeonPINVisualPresenter(view: pin, count: count)
                            controller = pin
                        }
                        let host = UIViewController()
                        host.addChild(controller); host.view.addSubview(controller.view); controller.didMove(toParent: host)
                        controller.view.translatesAutoresizingMaskIntoConstraints = false
                        NSLayoutConstraint.activate([
                            controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
                            controller.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
                            controller.view.topAnchor.constraint(equalTo: host.view.topAnchor),
                            controller.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
                        ])
                        host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: large ? .accessibilityExtraExtraExtraLarge : .large), forChild: controller)
                        window.rootViewController = host; window.makeKeyAndVisible()
                        await drainPINCallbacks()
                        if count == -2 {
                            (descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-backup-reveal" } as? UIButton)?.sendActions(for: .touchUpInside)
                        } else if count == -4 {
                            (descendants(controller.view).first { $0.accessibilityIdentifier == "wallet-raw-seed-reveal" } as? UIButton)?.sendActions(for: .touchUpInside)
                        }
                        window.layoutIfNeeded()
                        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                        let name = "\(language)-\(theme == .dark ? "dark" : "light")-\(large ? "AX5" : "normal")-\(count == 0 ? "settings" : (count < 0 ? "backup\(count)" : "pin\(count)")).png"
                        try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(name))
                        if let scroll = ([controller.view!] + descendants(controller.view)).compactMap({ $0 as? UIScrollView }).first {
                            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                            scroll.layoutIfNeeded()
                            let bottom = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                            try XCTUnwrap(bottom.pngData()).write(to: output.appendingPathComponent(name.replacingOccurrences(of: ".png", with: "-bottom.png")))
                        }
                    }
                    window.isHidden = true; window.rootViewController = nil
                }
            }
        }
    }

    /// Opt-in visual evidence from production controllers on the simulator.
    /// Synthetic states exercise layout only; routing is tested separately.
    @MainActor
    func testCaptureRecoveryVisualEvidence() async throws {
        guard ProcessInfo.processInfo.environment["SORA_CAPTURE_RECOVERY_UI"] == "1" else {
            throw XCTSkip("Enable SORA_CAPTURE_RECOVERY_UI for the isolated simulator visual audit")
        }
        let previousWindow = UIApplication.shared.keyWindow
        let previousTheme = SoramitsuUI.shared.themeMode
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        let window = makeSceneHostedWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer {
            window.isHidden = true; window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
            SoramitsuUI.shared.themeMode = previousTheme
            LocalizationManager.shared.selectedLocalization = previousLanguage
        }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecoveryVisualEvidence", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func capture(_ name: String, _ controller: UIViewController, category: UIContentSizeCategory,
                     configure: () -> Void = {}) async throws {
            let host = UIViewController()
            host.view.backgroundColor = WalletUX.page
            host.addChild(controller); host.view.addSubview(controller.view); controller.didMove(toParent: host)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
                controller.view.topAnchor.constraint(equalTo: host.view.topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
            ])
            host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: controller)
            window.rootViewController = host; window.makeKeyAndVisible()
            await drainPINCallbacks()
            configure()
            window.layoutIfNeeded(); controller.view.layoutIfNeeded()
            let scroll = descendants(controller.view).compactMap { $0 as? UIScrollView }
                .first { !($0 is UITextView) }
            for bottom in [false, true] {
                if bottom, let scroll {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                    scroll.layoutIfNeeded()
                }
                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let rendered = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                let data = try XCTUnwrap(rendered.pngData())
                try data.write(to: output.appendingPathComponent(name + (bottom ? "-bottom.png" : "-top.png")))
            }
        }
        for language in ["en", "ja"] {
            LocalizationManager.shared.selectedLocalization = language
            for theme in [SoramitsuThemeType.light, .dark] {
                SoramitsuUI.shared.themeMode = .manual(theme)
                window.overrideUserInterfaceStyle = theme == .dark ? .dark : .light
                for large in [false, true] {
                    let category: UIContentSizeCategory = large ? .accessibilityExtraExtraExtraLarge : .large
                    let prefix = language + (theme == .dark ? "-dark" : "-light") + (large ? "-maximum" : "-normal")
                    for (label, state) in [
                        ("recovery", WalletRecoveryState.recovery(retryable: true, accountsMissingKeys: 1,
                            accountsWithPhrase: 1, retainedPinUsable: true)),
                        ("records", .recovery(retryable: true, accountsMissingKeys: 0,
                            accountsWithPhrase: 0, retainedPinUsable: false, transactionRecordsUnreadable: true)),
                        ("nonretryable", .recovery(retryable: false, accountsMissingKeys: 0,
                            accountsWithPhrase: 0, retainedPinUsable: false))
                    ] {
                        let screen = WalletRecoveryViewController(reason: nil, onRetry: {}, onSetAside: {}, onRestore: { _ in })
                        try await capture(prefix + "-" + label, screen, category: category) { screen.apply(state.options) }
                    }
                    for bound in [false, true] {
                        let welcome = WalletWelcomeBackViewController(keystore: InMemoryKeychain(), settings: InMemorySettingsManager(),
                            onContinueToOnboarding: {}, onWalletsRestored: {}, onRestore: { _ in })
                        try await capture(prefix + (bound ? "-welcome-bound" : "-welcome-unbound"), welcome, category: category) {
                            welcome.apply(WalletRecoveryState.welcomeBack(adoptableWallets: bound ? 1 : 0,
                                walletsWithPhrase: bound ? 1 : 0, retainedPinUsable: bound).options)
                        }
                    }
                    try await capture(prefix + "-legacy", LegacyWalletUpgradeViewController(onConfirm: {}), category: category)
                    let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
                    let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false },
                        unresolvedWalletCommitJournal: { false }, credentialRepairPending: { false })
                    let account = AccountItem(address: "cnPublicSyntheticPreviewAddress", cryptoType: .sr25519,
                        networkType: 69, username: "Public preview", publicKeyData: Data(repeating: 0, count: 32),
                        settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
                    let repair = WalletCredentialRepairViewController(account: account,
                        service: WalletCredentialRepair(keystore: keys, settings: settings, recoveryGate: gate,
                            activeSnapshot: { nil }), currentAccounts: { [account] }, onSuccess: { _ in })
                    try await capture(prefix + "-repair", UINavigationController(rootViewController: repair), category: category)
                    for (label, state) in [("missing", WalletAccountCapability.State.missingKeys),
                                           ("invalid", .invalidKeys), ("watch-only", .watchOnly)] {
                        let item = PortfolioNoticeItem()
                        item.setCapability(state)
                        try await capture(prefix + "-header-" + label, PortfolioNoticeVisualController(item: item), category: category)
                    }
                    do {
                        let onboarding = WelcomeViewController()
                        onboarding.presenter = RecoveryOnboardingVisualPresenter()
                        try await capture(prefix + "-onboarding-return", onboarding, category: category) {
                            self.descendants(onboarding.view).first {
                                $0.accessibilityIdentifier == "wallet-onboarding-earlier-data"
                            }?.isHidden = false
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testRecoveryTextAndVisibleActionsUseTheSameFlags() throws {
        let controller = WalletRecoveryViewController(reason: nil, onRetry: {}, onSetAside: {}, onRestore: { _ in })
        controller.loadViewIfNeeded()
        let buttons = descendants(controller.view).compactMap { $0 as? UIButton }
        func button(_ suffix: String) throws -> UIButton {
            try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-recovery-" + suffix })
        }
        for bits in 0..<64 {
            var options = WalletRecoveryOptions()
            options.canRetry = bits & 1 != 0
            options.canRestoreFromPhrase = bits & 2 != 0
            options.canRestoreFromDrive = bits & 4 != 0
            options.canRestoreExistingKeys = bits & 8 != 0
            options.canSetAsideTransactionRecords = bits & 16 != 0
            options.canSetUpDeviceAgain = bits & 32 != 0
            controller.apply(options)
            XCTAssertEqual(try button("retry").isHidden, !options.canRetry)
            XCTAssertEqual(try button("restore-phrase").isHidden, !options.canRestoreFromPhrase)
            XCTAssertEqual(try button("restore-cloud-backup").isHidden, !options.canRestoreFromDrive)
            XCTAssertEqual(try button("restore-keys").isHidden, !options.canRestoreExistingKeys)
            XCTAssertEqual(try button("set-aside-transaction-records").isHidden, !options.canSetAsideTransactionRecords)
            XCTAssertEqual(try button("set-up-again").isHidden, !options.canSetUpDeviceAgain)
            let text = WalletRecoveryViewController.bodyText(diagnostic: nil, options: options)
            XCTAssertEqual(text.contains(WalletUX.text("Try again to run the wallet checks once more.")), options.canRetry)
            XCTAssertEqual(text.contains(WalletUX.text("Restore with your recovery phrase using the button below.")), options.canRestoreFromPhrase)
            XCTAssertEqual(text.contains(WalletUX.text("You can also restore from your encrypted Google Drive backup.")), options.canRestoreFromDrive)
            XCTAssertEqual(text.contains(WalletUX.text("Set up this iPhone again keeps the earlier files in a separate folder on this iPhone.")), options.canSetUpDeviceAgain)
        }
    }



    @MainActor
    func testAuthenticatedWalletOpeningRetriesLateServicesAndLeavesPIN() async throws {
        let fixture = try makeWalletOpeningWindow()
        let window = fixture.window
        defer { fixture.cleanup() }
        let wallet = UIViewController()
        var attempts = 0
        var refreshes = 0
        var opened = 0
        let opening = WalletOpeningViewController(makeWallet: {
            attempts += 1
            if attempts < 3 { throw WalletOpeningError.assetsNotReady }
            return wallet
        }, refresh: { refreshes += 1 }, makeNodes: { nil }, recheckWallet: { XCTFail("No storage recovery required") }, opened: {
            opened += 1
            window.rootViewController = $0
        }, retryInterval: 0.01, maximumAttempts: 5)
        window.rootViewController = UINavigationController(rootViewController: opening)
        window.makeKeyAndVisible()
        try await waitForWalletOpening { window.rootViewController === wallet }
        XCTAssertTrue(window.rootViewController === wallet)
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(opened, 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(opened, 1, "Successful opening cancels pending retries")
    }

    @MainActor
    func testWalletOpeningStopsWaitingAndOffersRetryAndNodes() async throws {
        let fixture = try makeWalletOpeningWindow()
        let window = fixture.window
        defer { fixture.cleanup() }
        var attempts = 0
        var ready = false
        var nodeRequests = 0
        let wallet = UIViewController()
        let nodes = UIViewController()
        let opening = WalletOpeningViewController(makeWallet: {
            attempts += 1
            if !ready { throw WalletOpeningError.connectionNotReady }
            return wallet
        }, refresh: {}, makeNodes: {
            nodeRequests += 1
            return nodeRequests == 1 ? nil : nodes
        }, recheckWallet: { XCTFail("A node failure is not a storage failure") }, opened: {
            window.rootViewController = $0
        }, retryInterval: 0.01, maximumAttempts: 2)
        let navigation = UINavigationController(rootViewController: opening)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        try await waitForWalletOpening { attempts == 2 }
        XCTAssertEqual(attempts, 2)
        let buttons = descendants(opening.view).compactMap { $0 as? UIButton }
        let retry = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-retry" })
        let changeNode = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-nodes" })
        let status = try XCTUnwrap(descendants(opening.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-opening-status" })
        XCTAssertTrue(retry.isEnabled && !retry.isHidden)
        XCTAssertTrue(changeNode.isEnabled && !changeNode.isHidden)
        XCTAssertTrue(descendants(opening.view).compactMap { $0 as? UIActivityIndicatorView }.allSatisfy { !$0.isAnimating })
        XCTAssertEqual(status.text, WalletUX.text("Wallet services are not ready. Try again or choose another node."))
        retry.sendActions(for: .touchUpInside)
        try await waitForWalletOpening { attempts == 4 }
        XCTAssertEqual(attempts, 4)
        changeNode.sendActions(for: .touchUpInside)
        XCTAssertEqual(status.text, WalletUX.text("Node settings are still loading. Try again."))
        XCTAssertTrue(retry.isEnabled)
        changeNode.sendActions(for: .touchUpInside)
        XCTAssertTrue(navigation.topViewController === nodes)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(attempts, 4, "Do not replace a node picker with a background retry")
        ready = true
        navigation.popViewController(animated: false)
        try await waitForWalletOpening { window.rootViewController === wallet }
        XCTAssertTrue(window.rootViewController === wallet)
        XCTAssertEqual(attempts, 5)
    }

    @MainActor
    func testTairaRemainsReachableWhileSora2ServicesAreUnavailable() async throws {
        let fixture = try makeWalletOpeningWindow()
        let window = fixture.window
        defer { fixture.cleanup() }
        var attempts = 0
        let networks = UIViewController()
        let opening = WalletOpeningViewController(makeWallet: {
            attempts += 1
            throw WalletOpeningError.assetsNotReady
        }, refresh: {}, makeNodes: { nil }, recheckWallet: { XCTFail("No recovery required") },
           opened: { _ in XCTFail("SORA2 services are unavailable") },
           makeNetworks: { networks }, retryInterval: 0.5, maximumAttempts: 3)
        let navigation = UINavigationController(rootViewController: opening)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        try await waitForWalletOpening { attempts == 1 }
        XCTAssertEqual(attempts, 1, "Navigate while the next retry is still scheduled")
        let button = try XCTUnwrap(descendants(opening.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-opening-networks" })
        XCTAssertFalse(button.isHidden)
        button.sendActions(for: .touchUpInside)
        try await waitForWalletOpening { navigation.topViewController === networks }
        XCTAssertTrue(navigation.topViewController === networks)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(attempts, 1, "A scheduled SORA2 retry must not interrupt Taira navigation")
        XCTAssertTrue(navigation.topViewController === networks)
    }

    @MainActor
    func testWalletOpeningAccountNotReadyCannotNavigateToOtherNetworks() async throws {
        let fixture = try makeWalletOpeningWindow()
        let window = fixture.window
        defer { fixture.cleanup() }
        var attempts = 0
        var rechecks = 0
        let opening = WalletOpeningViewController(makeWallet: {
            attempts += 1
            throw WalletOpeningError.accountNotReady
        }, refresh: {}, makeNodes: { XCTFail("An unverified account cannot expose node settings"); return nil },
           recheckWallet: { rechecks += 1 }, opened: { _ in XCTFail("An unverified account cannot open the wallet") },
           makeNetworks: { XCTFail("An unverified account cannot expose other networks"); return UIViewController() },
           retryInterval: 0.01, maximumAttempts: 2)
        let navigation = UINavigationController(rootViewController: opening)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        try await waitForWalletOpening { attempts == 1 }
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(attempts, 1)
        let buttons = descendants(opening.view).compactMap { $0 as? UIButton }
        let networks = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-networks" })
        XCTAssertTrue(networks.isHidden)
        networks.sendActions(for: .touchUpInside)
        XCTAssertTrue(navigation.topViewController === opening)
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-nodes" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-retry" }).isHidden)
        let recheck = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-recheck" })
        XCTAssertFalse(recheck.isHidden)
        recheck.sendActions(for: .touchUpInside)
        XCTAssertEqual(rechecks, 1)
    }

    @MainActor
    func testWalletOpeningNeverBypassesRetainedRecoveryForANodeError() async throws {
        let fixture = try makeWalletOpeningWindow()
        let window = fixture.window
        defer { fixture.cleanup() }
        let settings = InMemorySettingsManager()
        settings.setWalletMigrationRecovery(reason: "Retained fixture")
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        let keys = InMemoryKeychain()
        try keys.addKey(Data([1, 2, 3]), with: "retained-fixture-key")
        let identifiers = try keys.allKeyIdentifiers()
        var attempts = 0
        var rechecks = 0
        let controller = WalletOpeningViewController(makeWallet: {
            attempts += 1
            throw WalletOpeningError.recoveryRequired
        }, refresh: {}, makeNodes: { XCTFail("Recovery cannot expose node settings"); return nil },
           recheckWallet: { rechecks += 1 }, opened: { _ in XCTFail("Recovery cannot open the wallet") },
           makeNetworks: { XCTFail("Recovery cannot expose other networks"); return UIViewController() },
           retryInterval: 0.01, maximumAttempts: 2)
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        try await waitForWalletOpening { attempts == 1 }
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(attempts, 1)
        let buttons = descendants(controller.view).compactMap { $0 as? UIButton }
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-networks" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-nodes" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-retry" }).isHidden)
        let recheck = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-recheck" })
        XCTAssertFalse(recheck.isHidden)
        recheck.sendActions(for: .touchUpInside)
        XCTAssertEqual(rechecks, 1)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
        XCTAssertEqual(try keys.allKeyIdentifiers(), identifiers)
        XCTAssertEqual(try keys.fetchKey(for: "retained-fixture-key"), Data([1, 2, 3]))
    }

    /// AirPlay mirroring or a wired display must never receive the wallet
    /// windows or its life-cycle events: only the interactive application
    /// roles get SceneDelegate, and every other role is left to system
    /// mirroring.
    @MainActor
    func testOnlyTheApplicationSceneHostsTheWallet() {
        let application = AppDelegate.sceneConfiguration(for: .windowApplication)
        XCTAssertTrue(application.delegateClass == SceneDelegate.self)
        XCTAssertEqual(application.role, .windowApplication)

        let externalDisplay = AppDelegate.sceneConfiguration(for: .windowExternalDisplayNonInteractive)
        XCTAssertNil(externalDisplay.delegateClass)
        XCTAssertEqual(externalDisplay.role, .windowExternalDisplayNonInteractive)

        XCTAssertTrue(UISceneSession.Role.windowApplication.isSoraWalletScene)
        XCTAssertFalse(UISceneSession.Role.windowExternalDisplayNonInteractive.isSoraWalletScene)

        // An Assistive Access scene is interactive: it must show the wallet,
        // never a blank screen.
        if #available(iOS 26.0, *) {
            let assistive = AppDelegate.sceneConfiguration(for: .windowAssistiveAccessApplication)
            XCTAssertTrue(assistive.delegateClass == SceneDelegate.self)
            XCTAssertEqual(assistive.role, .windowAssistiveAccessApplication)
            XCTAssertTrue(UISceneSession.Role.windowAssistiveAccessApplication.isSoraWalletScene)
        }

        if let walletScene = UIApplication.shared.soraWindowScene {
            XCTAssertEqual(walletScene.session.role, .windowApplication)
        }
    }

    @MainActor
    func testNodeFailureUsesStatusWithoutBlockingPINOrClaimingAccountCreation() {
        let view = WalletUXNetworkStatusSpy()
        let presenter = NetworkAvailabilityLayerPresenter()
        presenter.view = view
        presenter.didDecideUnreachableNodesAllertPresentation()
        XCTAssertEqual(view.alerts, 0)
        XCTAssertEqual(view.statuses, [WalletUX.text("Network unavailable. Retrying connection…")])
    }

    /// The app uses the UIScene life cycle, so UIKit shows only windows that
    /// belong to a window scene; appearance callbacks never run otherwise.
    @MainActor
    private func makeSceneHostedWindow(frame: CGRect) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: frame)
        }
        window.frame = frame
        return window
    }

    @MainActor
    private func makeWalletOpeningWindow() throws -> (window: UIWindow, cleanup: () -> Void) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(
            scenes.first { $0.activationState == .foregroundActive } ?? scenes.first,
            "Wallet opening requires the test host's connected window scene"
        )
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let animationsWereEnabled = UIView.areAnimationsEnabled
        // Finish navigation synchronously so an earlier test's appearance
        // callbacks cannot start another retry during the next test.
        UIView.setAnimationsEnabled(false)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        return (window, {
            window.isHidden = true
            window.rootViewController = nil
            window.windowScene = nil
            previousWindow?.makeKeyAndVisible()
            UIView.setAnimationsEnabled(animationsWereEnabled)
        })
    }

    @MainActor
    private func waitForWalletOpening(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    func testResumeAuthorizationPreservesRecoveryAndGoogleCompletionAfterTimeout() async throws {
        let previousKeyWindow = UIApplication.shared.keyWindow
        for pin in ["1234", "123456"] {
            let window = makeSceneHostedWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            defer { window.isHidden = true; window.rootViewController = nil; previousKeyWindow?.makeKeyAndVisible() }
            let settings = InMemorySettingsManager()
            settings.biometryEnabled = false
            settings.setWalletMigrationRecovery(reason: "retained missing credentials")
            let marker = WalletMigrationRecoveryMarker.capture(settings)
            let store = InMemoryKeychainManager()
            try store.keychain.addKey(Data(pin.utf8), with: KeystoreTag.pincode.rawValue)
            let recovery = WalletRecoveryViewController(reason: "retained missing credentials", onRetry: {})
            let root = UINavigationController(rootViewController: recovery)
            window.rootViewController = root
            root.loadViewIfNeeded()
            recovery.loadViewIfNeeded()
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            root.view.layoutIfNeeded()
            // Establish an attached fixture before testing whether the lock preserves it.
            // Queued PIN callbacks alone do not complete UIKit appearance transactions.
            try await waitForWalletOpening { recovery.view.window === window }
            guard recovery.view.window === window else {
                XCTFail("Recovery fixture did not attach before the background transition")
                return
            }
            var pinPresenter: AuthorizationPresenter?
            let wireframe = SecurityLayerWireframe(windowProvider: { window }, pinFactory: { delegate in
                let view = PincodeViewController()
                view.mode = .securedInput
                let presenter = AuthorizationPresenter()
                let interactor = LocalAuthInteractor(secretManager: store, settingsManager: settings,
                    biometryAuth: WalletUXNoBiometry(), locale: .current,
                    ownerPINKeystore: store.keychain, accounts: { [] })
                view.presenter = presenter; presenter.view = view; presenter.interactor = interactor
                presenter.wireframe = delegate; interactor.presenter = presenter
                pinPresenter = presenter
                return view
            })
            defer {
                wireframe.authorizationWindow?.isHidden = true
                wireframe.authorizationWindow?.rootViewController = nil
            }
            var date = Date(timeIntervalSince1970: 1_000)
            let lifecycle = SecurityLayerInteractor(applicationHandler: ApplicationHandler(), settings: settings,
                keystore: store.keychain, pincodeDelay: 300, currentDate: { date })
            let presenter = SecurityLayerPresenter()
            presenter.wireframe = wireframe; presenter.interactor = lifecycle; lifecycle.presenter = presenter
            lifecycle.didReceiveWillResignActive(notification: Notification(name: UIApplication.willResignActiveNotification))
            date.addTimeInterval(301)
            lifecycle.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
            lifecycle.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))
            await drainPINCallbacks()
            let lockWindow = try XCTUnwrap(wireframe.authorizationWindow)
            XCTAssertTrue(window.rootViewController === root)
            XCTAssertTrue(recovery.view.window === window)
            XCTAssertFalse(window.isHidden)
            XCTAssertFalse(lockWindow.isHidden)
            XCTAssertGreaterThan(lockWindow.windowLevel.rawValue, window.windowLevel.rawValue)
            XCTAssertEqual(lockWindow.rootViewController?.view.backgroundColor, .systemBackground)
            XCTAssertEqual(lockWindow.rootViewController?.view.alpha, 1)
            XCTAssertTrue(lockWindow.rootViewController?.view.isUserInteractionEnabled == true)
            // A Google completion arrives while the lock is visible. Its result
            // stays attached to the original flow and remains covered by the PIN window.
            let backupPrompt = UIAlertController(title: "Backup password", message: "Synthetic callback", preferredStyle: .alert)
            backupPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            recovery.present(backupPrompt, animated: false)
            XCTAssertTrue(recovery.presentedViewController === backupPrompt)
            wireframe.showAuthorization()
            XCTAssertTrue(wireframe.authorizationWindow === lockWindow, "Repeated foreground notifications cannot replace pending auth")
            let input = try XCTUnwrap(pinPresenter)
            for digit in String(repeating: "0", count: pin.count) { input.padButtonTapped(with: String(digit)) }
            await drainPINCallbacks()
            try await Task.sleep(nanoseconds: 600_000_000)
            XCTAssertTrue(wireframe.authorizationWindow === lockWindow, "An incorrect PIN cannot uncover recovery")
            for digit in pin { input.padButtonTapped(with: String(digit)) }
            try await waitForWalletOpening { wireframe.authorizationWindow == nil }
            XCTAssertNil(wireframe.authorizationWindow)
            XCTAssertTrue(window.rootViewController === root)
            XCTAssertTrue(recovery.presentedViewController === backupPrompt, "Successful PIN must resume the outstanding import result")
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
            XCTAssertEqual(try store.keychain.allKeyIdentifiers(), [KeystoreTag.pincode.rawValue])
            XCTAssertEqual(try store.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data(pin.utf8), "Resume authentication cannot rewrite even a legacy PIN")
            var didDismissPrompt = false
            backupPrompt.dismiss(animated: false) { didDismissPrompt = true }
            try await waitForWalletOpening { didDismissPrompt && recovery.presentedViewController == nil }
            XCTAssertTrue(didDismissPrompt)
            XCTAssertNil(recovery.presentedViewController)
            window.isHidden = true
            window.rootViewController = nil
            try await waitForWalletOpening { recovery.view.window == nil }
            XCTAssertNil(recovery.view.window)
        }
    }

    @MainActor
    func testPINSetupErrorClearsConfirmationAndPresentsFromTheVisibleView() async {
        let presenter = SetupPincodePresenter()
        let view = WalletUXPINViewSpy()
        let wireframe = WalletUXPINWireframeSpy()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.savedPinCode = "123456"
        presenter.inputedPinCode = "123456"
        presenter.padButtonTapped(with: "9")
        XCTAssertEqual(presenter.inputedPinCode, "123456", "A completed PIN must not accept a seventh digit")
        presenter.didReceiveConfigError(WalletOwnerPIN.Failure.authenticationRequired)
        await drainPINCallbacks()
        XCTAssertEqual(presenter.savedPinCode, "")
        XCTAssertEqual(presenter.inputedPinCode, "")
        XCTAssertEqual(view.titles.last, R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized)
        XCTAssertTrue(wireframe.errorView === view)
        XCTAssertTrue(wireframe.fallbackView === view)
        XCTAssertEqual(wireframe.fallbackMessage, WalletUX.text("The PIN update could not be completed. Try again. Your wallet keys are unchanged."))
        XCTAssertEqual(wireframe.mainCount, 0)
    }

    @MainActor
    func testPINPresentersSubmitStoredLengthOnceAndKeepSixDigitUpgrade() async throws {
        for length in [4, 6] {
            let input = InputPincodePresenter()
            let inputView = WalletUXPINViewSpy()
            let inputAuth = WalletUXLocalAuthSpy()
            let inputWireframe = WalletUXPINWireframeSpy()
            input.view = inputView; input.interactor = inputAuth; input.wireframe = inputWireframe
            input.start()
            XCTAssertEqual(inputAuth.countRequests, 1)
            input.padButtonTapped(with: "1")
            XCTAssertTrue(inputAuth.submitted.isEmpty, "Do not guess the length before Keychain responds")
            input.setupPinCodeSymbols(with: 0)
            XCTAssertTrue(inputView.titles.last?.contains("PIN unavailable") == true)
            input.padButtonTapped(with: "1")
            XCTAssertEqual(inputAuth.countRequests, 2)
            XCTAssertTrue(inputAuth.submitted.isEmpty)
            input.setupPinCodeSymbols(with: length)
            for _ in 0 ..< length - 1 { input.padButtonTapped(with: "1") }
            XCTAssertTrue(inputAuth.submitted.isEmpty)
            input.padButtonTapped(with: "1")
            input.padButtonTapped(with: "9")
            XCTAssertEqual(inputAuth.submitted, [String(repeating: "1", count: length)])
            input.didEnterWrongPincode()
            await drainPINCallbacks()
            for _ in 0 ..< length { input.padButtonTapped(with: "2") }
            XCTAssertEqual(inputAuth.submitted.count, 2)
            input.didCompleteAuth()
            await drainPINCallbacks()
            if length == 4 {
                XCTAssertEqual(inputView.updateRequests, 1)
                XCTAssertEqual(inputWireframe.mainCount, 0)
                input.updatePinButtonTapped()
                for _ in 0 ..< 6 { input.padButtonTapped(with: "3") }
                for _ in 0 ..< 6 { input.padButtonTapped(with: "3") }
                XCTAssertEqual(inputAuth.updated, ["333333"])
                XCTAssertEqual(inputWireframe.mainCount, 1)
            } else {
                XCTAssertEqual(inputView.updateRequests, 0)
                XCTAssertEqual(inputWireframe.mainCount, 1)
                XCTAssertTrue(inputAuth.updated.isEmpty)
            }

            let authorization = AuthorizationPresenter()
            let auth = WalletUXLocalAuthSpy()
            let view = WalletUXPINViewSpy()
            let completion = WalletUXAuthorizationSpy()
            authorization.interactor = auth; authorization.view = view; authorization.wireframe = completion
            authorization.start()
            XCTAssertEqual(auth.countRequests, 1)
            authorization.setupPinCodeSymbols(with: 5)
            XCTAssertTrue(view.titles.last?.contains("PIN unavailable") == true)
            authorization.padButtonTapped(with: "1")
            XCTAssertEqual(auth.countRequests, 2)
            XCTAssertTrue(auth.submitted.isEmpty)
            authorization.setupPinCodeSymbols(with: length)
            XCTAssertEqual(view.symbolCounts.last, length)
            for _ in 0 ..< length { authorization.padButtonTapped(with: "4") }
            authorization.padButtonTapped(with: "5")
            XCTAssertEqual(auth.submitted, [String(repeating: "4", count: length)])
            authorization.didCompleteAuth()
            await drainPINCallbacks()
            XCTAssertEqual(completion.results, [true])
            XCTAssertTrue(auth.updated.isEmpty)

            let cooldownInput = InputPincodePresenter()
            let cooldownView = WalletUXPINViewSpy()
            let cooldownAuth = WalletUXLocalAuthSpy()
            cooldownAuth.blockDate = Date().addingTimeInterval(30)
            cooldownInput.view = cooldownView; cooldownInput.interactor = cooldownAuth
            cooldownInput.wireframe = inputWireframe
            cooldownInput.start()
            XCTAssertEqual(cooldownAuth.countRequests, 1, "Load the retained length even when reopening during cooldown")
            XCTAssertEqual(cooldownView.blockedDates.count, 1)
            cooldownInput.setupPinCodeSymbols(with: length)
            cooldownAuth.blockDate = nil
            for _ in 0 ..< length { cooldownInput.padButtonTapped(with: "7") }
            XCTAssertEqual(cooldownAuth.submitted, [String(repeating: "7", count: length)],
                "After cooldown, the first typed digit must not be consumed by a length reload")
        }

        let actualView = PincodeViewController()
        let actualPresenter = InputPincodePresenter()
        let actualAuth = WalletUXLocalAuthSpy()
        actualView.mode = .securedInput; actualView.presenter = actualPresenter
        actualPresenter.view = actualView; actualPresenter.interactor = actualAuth
        actualPresenter.wireframe = WalletUXPINWireframeSpy()
        actualView.loadViewIfNeeded()
        actualPresenter.setupPinCodeSymbols(with: 0)
        actualView.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        actualView.view.layoutIfNeeded()
        let feedback = try XCTUnwrap(descendants(actualView.view).compactMap { $0 as? SoramitsuLabel }
            .first { ($0.text ?? "").hasPrefix("PIN unavailable") })
        XCTAssertEqual(feedback.numberOfLines, 0)
        XCTAssertEqual(feedback.sora.lineBreakMode, .byWordWrapping)
        XCTAssertTrue(feedback.text?.contains("tap a number to retry") == true)
        XCTAssertLessThanOrEqual(feedback.frame.width, actualView.view.bounds.width)
        XCTAssertGreaterThan(feedback.frame.height, feedback.font.lineHeight)
    }

    @MainActor
    func testResumeAuthorizationFailureKeepsOpaqueLockAndAllowsRetry() throws {
        let previousKeyWindow = UIApplication.shared.keyWindow
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let original = UIViewController()
        window.rootViewController = original
        window.makeKeyAndVisible()
        let delegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let previousAppWindow = delegate.window
        delegate.window = window
        let loadingWindow = UIWindow(frame: window.frame)
        loadingWindow.windowLevel = .alert
        let spinnerRoot = UIViewController()
        loadingWindow.rootViewController = spinnerRoot
        loadingWindow.makeKeyAndVisible()
        var attempts = 0
        let wireframe = SecurityLayerWireframe(pinFactory: { _ in attempts += 1; return nil })
        defer {
            wireframe.authorizationWindow?.isHidden = true
            loadingWindow.isHidden = true; loadingWindow.rootViewController = nil
            window.isHidden = true; window.rootViewController = nil
            delegate.window = previousAppWindow
            previousKeyWindow?.makeKeyAndVisible()
        }
        wireframe.showAuthorization()
        let lock = try XCTUnwrap(wireframe.authorizationWindow)
        let retry = try XCTUnwrap(descendants(try XCTUnwrap(lock.rootViewController?.view)).compactMap { $0 as? UIButton }.first)
        XCTAssertEqual(attempts, 1)
        XCTAssertFalse(lock.isHidden)
        XCTAssertEqual(lock.rootViewController?.view.backgroundColor, .systemBackground)
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(attempts, 2)
        wireframe.showAuthorizationCompletion(with: false)
        XCTAssertEqual(attempts, 3)
        XCTAssertTrue(wireframe.authorizationWindow === lock)
        XCTAssertFalse(lock.isHidden)
        XCTAssertTrue(window.rootViewController === original)
        XCTAssertTrue(loadingWindow.rootViewController === spinnerRoot)
        XCTAssertGreaterThan(lock.windowLevel.rawValue, loadingWindow.windowLevel.rawValue)
        XCTAssertEqual((lock.rootViewController?.presentedViewController as? UIAlertController)?.title, WalletUX.text("PIN verification unavailable"))
    }

    @MainActor
    private func drainPINCallbacks() async {
        for _ in 0 ..< 5 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }


    func testStartupRetryReportsCurrentFailureWithoutReplacingRecoveryMarker() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.unexpectedFail)
        settings.setWalletMigrationRecovery(reason: reason)
        let original = WalletMigrationRecoveryMarker.capture(settings)
        let secret = "PRIVATE-wallet-address-path-and-phrase"
        let failures: [(Error, WalletStartupDiagnostic.Cause, Int?)] = [
            (UserStorageMigrationError.backupVerificationFailed(secret), .backupVerification, nil),
            (WalletNetworkMigrationError.legacyIdentityMismatch(secret), .legacyIdentityMismatch, nil),
            (WalletIntegrityError.selectedAccountSecretMissing(address: secret), .missingSecret, nil),
            (KeystoreSystemError(status: -25308), .keychainSystem, -25308),
            (NSError(domain: NSCocoaErrorDomain, code: 134100,
                userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret]), .cocoa, 134100),
            (NSError(domain: secret, code: 7, userInfo: [NSLocalizedDescriptionKey: secret]), .unexpected, nil)
        ]
        for (error, cause, systemCode) in failures {
            var migrated = false
            XCTAssertEqual(WalletStorageStartup.run(settings: settings, accountCommitRecovery: {
                try WalletStartupDiagnostic.check(.databaseInventory) { throw error }
            }, migration: { migrated = true }), .recoveryRequired)
            XCTAssertFalse(migrated)
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), original)
            let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
            XCTAssertEqual(diagnostic.phase, .databaseInventory)
            XCTAssertEqual(diagnostic.cause, cause)
            XCTAssertEqual(diagnostic.systemCode, systemCode)
            XCTAssertFalse(diagnostic.summary.contains(secret))
            XCTAssertFalse(diagnostic.userMessage.isEmpty)
            XCTAssertFalse(diagnostic.userMessage.contains(secret))
            XCTAssertFalse(try String(decoding: JSONEncoder().encode(diagnostic), as: UTF8.self).contains(secret))
        }
        settings.setWalletMigrationRecovery(reason: "A newer integrity failure")
        XCTAssertNil(WalletStartupDiagnostic.current(settings), "A new marker must not display the previous attempt's diagnostic")

        let fresh = InMemorySettingsManager()
        XCTAssertEqual(WalletStorageStartup.run(settings: fresh, migration: {
            throw KeystoreSystemError(status: -34018)
        }), .recoveryRequired)
        XCTAssertEqual(WalletStartupDiagnostic.current(fresh)?.phase, .databaseMigration)
        XCTAssertEqual(WalletStartupDiagnostic.current(fresh)?.systemCode, -34018)
        XCTAssertEqual(fresh.walletMigrationRecoveryReason, reason)
    }

    @MainActor
    func testRecoveryDetailsIncludeLatestSafeDiagnosticAndRejectInvalidStoredCodes() throws {
        // Seed only local synthetic data. Reading an arbitrary pre-existing
        // host/universal clipboard item can wait for an external data provider.
        UIPasteboard.general.setItems([["public.utf8-plain-text": "Synthetic prior clipboard"]], options: [.localOnly: true])
        defer { UIPasteboard.general.setItems([], options: [.localOnly: true]) }
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.unexpectedFail)
        settings.setWalletMigrationRecovery(reason: reason)
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        WalletStartupDiagnostic.record(KeystoreSystemError(status: -25308),
            phase: .networkBootstrap, settings: settings)
        let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
        let controller = WalletRecoveryViewController(reason: reason, diagnostic: diagnostic)
        controller.loadViewIfNeeded()
        let copy = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-copy-details" })
        copy.sendActions(for: .touchUpInside)
        let details = try XCTUnwrap(UIPasteboard.general.string)
        let trigger = WalletUX.format("Original recovery trigger: %@", "unexpected_failure")
        XCTAssertTrue(details.contains(trigger))
        XCTAssertTrue(details.contains("Latest verification: network_bootstrap / keychain_system (-25308)"))
        XCTAssertTrue(details.contains(WalletUX.text("Recovery report format: 2")))
        XCTAssertTrue(details.contains(WalletUX.format("Protected data when copied: %@",
            UIApplication.shared.isProtectedDataAvailable ? WalletUX.text("Available") : WalletUX.text("Unavailable"))))
        XCTAssertTrue(details.contains("iOS: "))
        XCTAssertTrue(details.contains(WalletUX.format("Current failure: %@", diagnostic.userMessage)))
        let latestRange = try XCTUnwrap(details.range(of: "Latest verification:"))
        let originalRange = try XCTUnwrap(details.range(of: trigger))
        XCTAssertLessThan(latestRange.lowerBound, originalRange.lowerBound)
        let visibleDiagnostic = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-diagnostic" })
        XCTAssertEqual(visibleDiagnostic.text, diagnostic.summary)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)

        let privateHistoricalText = "PRIVATE-ACCOUNT-ADDRESS-PHRASE-PATH"
        let historicalController = WalletRecoveryViewController(reason: privateHistoricalText, diagnostic: diagnostic)
        historicalController.loadViewIfNeeded()
        let historicalCopy = try XCTUnwrap(descendants(historicalController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-copy-details" })
        historicalCopy.sendActions(for: .touchUpInside)
        let historicalDetails = try XCTUnwrap(UIPasteboard.general.string)
        XCTAssertFalse(historicalDetails.contains(privateHistoricalText))
        XCTAssertTrue(historicalDetails.contains(diagnostic.summary))
        XCTAssertTrue(historicalDetails.contains(WalletUX.text("Original recovery trigger: legacy record (details unavailable)")))

        let oldController = WalletRecoveryViewController(reason: reason, onRetry: {})
        oldController.loadViewIfNeeded()
        let oldDiagnostic = try XCTUnwrap(descendants(oldController.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-diagnostic" })
        XCTAssertTrue(try XCTUnwrap(oldDiagnostic.text).contains(WalletUX.text("No detailed check was recorded by the previous build.")))

        var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any])
        stored["cause"] = "PRIVATE-ACCOUNT"
        let malformed = try JSONSerialization.data(withJSONObject: stored)
        settings.set(value: String(decoding: malformed, as: UTF8.self), for: "walletStartupDiagnostic")
        XCTAssertNil(WalletStartupDiagnostic.current(settings))
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
    }

    @MainActor
    func testWalletRecoveryRetryRunsOnceWithoutClearingRecoveryState() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.invalidIdentifierFormat)
        settings.setWalletMigrationRecovery(reason: reason)
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        var retries = 0
        let controller = WalletRecoveryViewController(reason: reason, onRetry: {
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
            retries += 1
        })
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        controller.view.layoutIfNeeded()
        let retry = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" })
        XCTAssertEqual(retry.title(for: .normal), WalletUX.text("Try again"))
        XCTAssertTrue(retry.isEnabled)
        XCTAssertFalse(retry.isHidden)
        XCTAssertFalse(retry.frame.isEmpty)
        retry.sendActions(for: .touchUpInside)
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(retries, 1)
        XCTAssertFalse(retry.isEnabled)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
        let passiveController = WalletRecoveryViewController(reason: reason)
        passiveController.loadViewIfNeeded()
        XCTAssertTrue(try XCTUnwrap(descendants(passiveController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-keys" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-cloud-backup" }).isHidden)

        WalletStartupDiagnostic.record(UserStorageMigrationError.missingWalletSecret("fixture"),
            phase: .databaseMigration, settings: settings)
        let missingKeysController = WalletRecoveryViewController(reason: reason,
            diagnostic: WalletStartupDiagnostic.current(settings), onRetry: {})
        missingKeysController.loadViewIfNeeded()
        // Restore actions follow facts (accounts whose keys are missing), not
        // the recorded cause.
        missingKeysController.apply(WalletRecoveryState.recovery(retryable: true, accountsMissingKeys: 1,
            accountsWithPhrase: 0, retainedPinUsable: false).options)
        let restore = try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-keys" })
        XCTAssertFalse(restore.isHidden)
        XCTAssertTrue(restore.isEnabled)
        let restoreCloud = try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-cloud-backup" })
        XCTAssertFalse(restoreCloud.isHidden)
        XCTAssertTrue(restoreCloud.isEnabled)
        XCTAssertEqual(restoreCloud.title(for: .normal), WalletUX.text("Restore from Google Drive backup"))
        XCTAssertEqual(WalletCloudBackupRecoveryError.title(for: WalletCloudBackupRecoveryError.notFound),
            "Backup not found")
        XCTAssertTrue(WalletCloudBackupRecoveryError.userMessage(for: WalletCloudBackupRecoveryError.notFound)
            .contains("again to choose another Google account"))
        XCTAssertEqual(WalletCloudBackupRecoveryError.title(for: WalletCloudBackupRecoveryError.authorizationCanceled),
            "Google sign-in canceled")
        XCTAssertTrue(WalletCloudBackupRecoveryError.userMessage(for: WalletCloudBackupRecoveryError.authorizationCanceled)
            .contains("No wallet keys were changed"))
        XCTAssertEqual(WalletCloudBackupRecoveryError.title(for: WalletCloudBackupRecoveryError.incorrectPassword),
            "Wallet keys not restored")
        XCTAssertTrue(try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-cloud-status" }).isHidden)
        let missingKeysRetry = try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" })
        missingKeysRetry.sendActions(for: .touchUpInside)
        XCTAssertFalse(restore.isEnabled)
        XCTAssertFalse(restoreCloud.isEnabled)
        let missingKeysWithoutRetry = WalletRecoveryViewController(reason: reason,
            diagnostic: WalletStartupDiagnostic.current(settings))
        missingKeysWithoutRetry.loadViewIfNeeded()
        missingKeysWithoutRetry.apply(WalletRecoveryState.recovery(retryable: true, accountsMissingKeys: 1,
            accountsWithPhrase: 0, retainedPinUsable: false).options)
        XCTAssertTrue(try XCTUnwrap(descendants(missingKeysWithoutRetry.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-keys" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(descendants(missingKeysWithoutRetry.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-cloud-backup" }).isHidden)
    }

    @MainActor
    func testStorageRetryRemainsAvailableAfterRepeatedLowSpace() throws {
        let window = SoraWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let presenter = SplashPresenter(window: window)
        let controller = SplashViewController()
        controller.presenter = presenter
        presenter.view = controller
        var retries = 0
        for expected in 1 ... 2 {
            controller.showStorageSpaceRetry { retries += 1 }
            controller.view.layoutIfNeeded()
            let retry = try XCTUnwrap(descendants(controller.view)
                .compactMap { $0 as? UIButton }
                .first { $0.accessibilityIdentifier == "wallet-upgrade-storage-retry" })
            XCTAssertTrue(retry.isEnabled)
            XCTAssertFalse(retry.frame.isEmpty)
            retry.sendActions(for: .touchUpInside)
            XCTAssertEqual(retries, expected)
            XCTAssertFalse(retry.isEnabled)
        }
    }

    @MainActor
    func testEditableSoraTextRetainsDynamicTypeAfterChanges() throws {
        let parent = UIViewController()
        let child = UIViewController()
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let field = SoramitsuTextField()
        let textView = SoramitsuTextView()
        let unchanged = SoramitsuTextField()
        [field, textView, unchanged].forEach { child.view.addSubview($0) }
        field.sora.dynamicTextStyle = .body
        textView.sora.dynamicTextStyle = .body
        let base = FontType.textM.font
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
            if #available(iOS 17.0, *) {
                child.traitOverrides.preferredContentSizeCategory = category
                child.updateTraitsIfNeeded()
                child.view.updateTraitsIfNeeded()
                [field, textView, unchanged].forEach { $0.updateTraitsIfNeeded() }
            } else {
                parent.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: child)
            }
            parent.view.layoutIfNeeded()
            child.view.layoutIfNeeded()
            XCTAssertEqual(field.traitCollection.preferredContentSizeCategory, category)
            XCTAssertEqual(textView.traitCollection.preferredContentSizeCategory, category)
            for input in ["First", "Edited again"] {
                field.sora.text = input
                textView.sora.text = input
                unchanged.sora.text = input
                let expected = UIFontMetrics(forTextStyle: .body).scaledFont(for: base,
                    compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
                let fieldFont = try XCTUnwrap(field.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                let viewFont = try XCTUnwrap(textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(fieldFont.pointSize, expected, accuracy: 0.1)
                XCTAssertEqual(viewFont.pointSize, expected, accuracy: 0.1)
                let originalFont = try XCTUnwrap(unchanged.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(originalFont.pointSize, base.pointSize, accuracy: 0.1)
            }
        }
    }

    @MainActor
    func testRecoveryChoicesExposeSelectionAndRequireAllAcknowledgements() throws {
        let controller = AccountWarningViewController(warningType: .passphrase)
        var completions = 0
        controller.completion = { completions += 1 }
        controller.loadViewIfNeeded()
        let choices = descendants(controller.view).compactMap { $0 as? CheckView }
        XCTAssertEqual(choices.count, 3)
        controller.completeTapped()
        XCTAssertEqual(completions, 0)
        for choice in choices {
            XCTAssertTrue(choice.isAccessibilityElement)
            XCTAssertFalse(choice.accessibilityLabel?.isEmpty ?? true)
            XCTAssertFalse(choice.accessibilityTraits.contains(.selected))
            XCTAssertTrue(choice.accessibilityActivate())
            XCTAssertTrue(choice.accessibilityTraits.contains(.selected))
        }
        controller.completeTapped()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(try XCTUnwrap(choices.first).accessibilityActivate())
        controller.completeTapped()
        XCTAssertEqual(completions, 1)
    }

    func testPristineCurrentSQLiteCanRelaunchWithOrdinarySidecars() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: UserStorageParams.modelVersion.rawValue,
            withExtension: "omo", subdirectory: UserStorageParams.modelDirectory)
            ?? Bundle.main.url(forResource: UserStorageParams.modelVersion.rawValue,
                withExtension: "mom", subdirectory: UserStorageParams.modelDirectory))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let database = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
            at: storeURL, options: nil)
        defer { try? coordinator.remove(database) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + "-shm"))
        let originalStore = try Data(contentsOf: storeURL)
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let migrator = UserStorageMigrator(targetVersion: UserStorageParams.modelVersion, storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory, keystore: keychain, settings: settings,
            fileManager: .default, recoveryGate: gate, loadWalletNetworkSnapshot: { nil })
        for _ in 0 ..< 2 {
            try migrator.performMigration()
            XCTAssertFalse(settings.hasRetainedWalletSettings())
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("WalletMigrationSafety").path))
            XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
        }
        // A retained PIN alone is the reinstall signature (iOS keeps Keychain
        // items when the app is deleted): no recovery, nothing written.
        try keychain.addKey(Data([1]), with: KeystoreTag.pincode.rawValue)
        XCTAssertNoThrow(try migrator.performMigration())
        XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
        XCTAssertEqual(try keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data([1]))
        // A retained wallet setting beside the empty store is still a lost inventory.
        settings.set(value: true, for: SettingsKey.hasMigrated.rawValue)
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected retained-wallet admission: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
    }

    func testFirstLaunchKeepsPristineNamespaceAndReachesOnboarding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeWalletNetworkStore(baseURL: directory)
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
            securityLayerInteractor: WalletUXSecurityLayerStub(),
            networkAvailabilityLayerInteractor: nil, legacyUpgradeSelectedAccount: { nil },
            legacyUpgradeSnapshotLoader: { try store.load() }, legacyUpgradeUnresolvedCommitLoader: { [] })
        let presenter = WalletUXRootPresenterSpy()
        root.presenter = presenter
        for _ in 0 ..< 2 {
            try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
                store: store, keystore: keychain, settings: settings)
            XCTAssertNil(try store.load())
            XCTAssertFalse(settings.hasRetainedWalletSettings())
            root.decideModuleSynchroniously()
        }
        XCTAssertEqual(presenter.decisions, [.onboarding, .onboarding])
    }

    func testEmptyBootstrapPreservesRetainedEvidenceAndRecovery() throws {
        for kind in ["pin", "watch-only", "version", "identity"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try makeWalletNetworkStore(baseURL: directory)
            let settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()
            switch kind {
            case "pin": try keychain.addKey(Data([1, 2, 3]), with: KeystoreTag.pincode.rawValue)
            case "watch-only": settings.set(value: true, for: "wallet.watchOnly.retained")
            case "version": settings.set(value: 3, for: SettingsKey.walletNetworkStoreVersion.rawValue)
            default: settings.set(value: "retained-id", for: SettingsKey.decentralizedId.rawValue)
            }
            let keysBefore = Set(settings.allKeys())
            let identifiersBefore = try keychain.allKeyIdentifiers()
            try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
                store: store, keystore: keychain, settings: settings)
            XCTAssertEqual(Set(settings.allKeys()), keysBefore)
            XCTAssertEqual(try keychain.allKeyIdentifiers(), identifiersBefore)
            XCTAssertNil(try store.load())
            let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
                securityLayerInteractor: WalletUXSecurityLayerStub(),
                networkAvailabilityLayerInteractor: nil, legacyUpgradeSelectedAccount: { nil },
                legacyUpgradeSnapshotLoader: { try store.load() }, legacyUpgradeUnresolvedCommitLoader: { [] })
            let presenter = WalletUXRootPresenterSpy()
            root.presenter = presenter
            root.decideModuleSynchroniously()
            // A PIN alone is not a wallet. This isolated Root check has not
            // run startup's stale-metadata preservation for the other cases.
            XCTAssertEqual(presenter.decisions, kind == "pin" ? [.onboarding] : [.broken], kind)
            XCTAssertEqual(try keychain.allKeyIdentifiers(), identifiersBefore, kind)
            XCTAssertEqual(settings.walletMigrationRecoveryRequired, kind != "pin", kind)
        }
    }

    func testEmptyBootstrapRejectsCorruptSnapshotWithoutChangingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeWalletNetworkStore(baseURL: directory)
        let pointer = directory.appendingPathComponent("SORA/WalletNetworks/active.json")
        let retained = Data("interrupted-pointer".utf8)
        try retained.write(to: pointer)
        XCTAssertThrowsError(try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
            store: store, keystore: InMemoryKeychain(), settings: InMemorySettingsManager()))
        XCTAssertEqual(try Data(contentsOf: pointer), retained)
    }

    private func makeWalletNetworkStore(baseURL: URL) throws -> WalletNetworkStore {
        let gate = WalletRecoveryCapabilityGate(settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        return try WalletNetworkStore(baseURL: baseURL, recoveryGate: gate)
    }

    @MainActor
    func testChartKeepsItsDescriptionAndExpandsForNarrowScreens() {
        let chart = PolkamarktLineChartView(frame: .zero)
        chart.caption = "Yes probability history"
        chart.context = "From 30% yesterday to 65% today. Vertical scale: 0% to 100%. Snapshots run from oldest to newest at equal spacing."
        chart.values = [0.3, 0.5, 0.65]
        XCTAssertTrue(chart.isAccessibilityElement)
        XCTAssertTrue(chart.accessibilityLabel?.contains(chart.context) == true)
        let wide = chart.sizeThatFits(CGSize(width: 600, height: 1000))
        let narrow = chart.sizeThatFits(CGSize(width: 320, height: 1000))
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertGreaterThan(narrow.height, 180)
    }

    func testTotalRetainsExactPrecisionAndRejectsInvalidAmounts() throws {
        for (amount, fee, expected) in [
            ("12.5", "0.01", "12.51"),
            ("0.000000001", "0.000000009", "0.000000010"),
            ("999999999999999999999999999999999999999999.99", "0.01", "1000000000000000000000000000000000000000000.00")
        ] {
            XCTAssertEqual(WalletUX.total(amount: try PIQuantity(amount), fee: try PIQuantity(fee)), expected)
        }
        XCTAssertNil(WalletUX.total(amount: try PIQuantity("-1"), fee: try PIQuantity("0.01")))
        XCTAssertNil(WalletUX.total(amount: try PIQuantity("1"), fee: try PIQuantity("-0.01")))
    }

    func testLocalizationUsesSelectedLanguageThenEnglishFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, content) in [
            ("en", "\"Greeting\" = \"Hello\";\n\"Fallback\" = \"English fallback\";\n\"Blank\" = \"English instead\";"),
            ("ja", "\"Greeting\" = \"こんにちは\";\n\"Blank\" = \"\";")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try content.write(to: directory.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }
        let bundle = try XCTUnwrap(Bundle(url: root))
        XCTAssertEqual(WalletUX.text("Greeting", language: "ja", bundle: bundle), "こんにちは")
        XCTAssertEqual(WalletUX.text("Fallback", language: "ja", bundle: bundle), "English fallback")
        XCTAssertEqual(WalletUX.text("Blank", language: "ja", bundle: bundle), "English instead")
        XCTAssertEqual(WalletUX.text("Greeting", language: "missing", bundle: bundle), "Hello")
    }

    func testGeneratedStringsChooseAValueBeforeFallingBackToEnglish() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let info = ["CFBundleDevelopmentRegion": "en", "CFBundleIdentifier": "org.sora.tests.localization"]
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: root.appendingPathComponent("Info.plist"))

        for (language, strings, plural) in [
            ("en", "\"greeting.key\" = \"Hello\";\n\"blank.key\" = \"English value\";\n\"formatted.key\" = \"Welcome %@\";",
             "%d items"),
            ("ja", "\"greeting.key\" = \"こんにちは\";\n\"blank.key\" = \"\";", "%d 項目")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try strings.write(to: directory.appendingPathComponent("Localizable.strings"),
                              atomically: true, encoding: .utf8)
            let pluralEntry: [String: Any] = [
                "count.key": [
                    "NSStringLocalizedFormatKey": "%#@items@",
                    "items": [
                        "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                        "NSStringFormatValueTypeKey": "d",
                        "one": plural,
                        "other": plural
                    ]
                ]
            ]
            let pluralData = try PropertyListSerialization.data(fromPropertyList: pluralEntry,
                                                                format: .xml, options: 0)
            try pluralData.write(to: directory.appendingPathComponent("Localizable.stringsdict"))
        }

        let fixture = try XCTUnwrap(Bundle(url: root))
        func value(_ key: String) throws -> (Locale, String) {
            let (locale, selectedBundle) = try XCTUnwrap(
                R.localeBundle(tableName: "Localizable", key: key,
                               preferredLanguages: ["ja"], in: fixture)
            )
            return (locale, selectedBundle.localizedString(forKey: key, value: nil, table: "Localizable"))
        }

        XCTAssertEqual(try value("greeting.key").1, "こんにちは")
        XCTAssertEqual(try value("blank.key").1, "English value")
        let englishFormat = try value("formatted.key")
        XCTAssertEqual(String(format: englishFormat.1, locale: englishFormat.0, "Sora"), "Welcome Sora")
        let japanesePlural = try value("count.key")
        XCTAssertEqual(String(format: japanesePlural.1, locale: japanesePlural.0, 2), "2 項目")
        XCTAssertNil(R.localeBundle(tableName: "Localizable", key: "absent.key",
                                   preferredLanguages: ["ja"], in: fixture))
    }

    func testGeneratedStringsFallbackInTheShippedCatalogs() {
        XCTAssertEqual(R.string.localizable.commonFarms(preferredLanguages: ["de-DE"]), "Farms")
        // The Nexus line still ships its tester locales (the 3.9.x App Store
        // line removed them): Middle Egyptian has an empty value here, which
        // falls back to English, and Old Akkadian has its own.
        XCTAssertEqual(R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: ["egy-Egyp"]), "m")
        XCTAssertEqual(R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: ["akk"]), "d")
        XCTAssertEqual(R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: ["ja"]), "分")
        XCTAssertEqual(R.string.localizable.approveTheIrohaConnectConnectionFor(
            "Sora", preferredLanguages: ["ja"]), "Approve the IrohaConnect connection for Sora")
        XCTAssertTrue(R.string.localizable.favoriteUsers(favorite: 2,
                                                         preferredLanguages: ["ja"]).contains("お気に入り"))
        XCTAssertEqual(R.string.localizable.referendumDateSecondPlurals(
            preferredLanguages: ["ja"]), "")
    }

    func testLegacyLocalizableErrorsUseEnglishWhenSelectedValueIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, strings) in [
            ("en", "\"selected.key\" = \"English selected\";\n\"missing.key\" = \"English fallback\";\n\"empty.key\" = \"English instead\";"),
            ("ja", "\"selected.key\" = \"日本語\";\n\"empty.key\" = \"\";")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try strings.write(to: directory.appendingPathComponent("Localizable.strings"),
                              atomically: true, encoding: .utf8)
        }
        let bundle = try XCTUnwrap(Bundle(url: root))
        func localize(_ key: String) -> String {
            L10n.getFormat(for: key, localization: "ja", bundle: bundle)
        }

        XCTAssertEqual(localize("selected.key"), "日本語")
        XCTAssertEqual(localize("missing.key"), "English fallback")
        XCTAssertEqual(localize("empty.key"), "English instead")
        XCTAssertEqual(localize("unshipped.key"), "")

        let activeFallbacks = [
            "amount.error.asset": "Sorry, we couldn't find asset information you want to send. Please, try again later.",
            "amount.error.balance": "Sorry, balance checking request failed. Please, try again later.",
            "amount.error.transfer": "Sorry, we couldn't contact transfer provider. Please, try again later.",
            "invoice_scan.error.camera_restricted_previously": "Unfortunately, you denied access to camera previously. Would you like to allow access now?",
            "invoice_scan.error.camera_title": "Camera Access",
            "invoice_scan.error.extract_fail": "Can't extract receiver's data",
            "invoice_scan.error.gallery_restricted_previously": "Unfortunately, you denied access to photos previously. Would you like to allow access now?",
            "invoice_scan.error.gallery_title": "Photos Access",
            "invoice_scan.error.match": "You can't send to yourself",
            "invoice_scan.error.no_internet": "Please, check internet connection",
            "invoice_scan.error.user_not_found": "Can't find a user from QR"
        ]
        for (key, expected) in activeFallbacks {
            XCTAssertEqual(localize(key), expected, key)
        }

        XCTAssertEqual(TransferPresenterError.missingAsset
            .toErrorContent(for: Locale(identifier: "ja")).title, "エラー")
        XCTAssertEqual(TransferPresenterError.missingAsset
            .toErrorContent(for: Locale(identifier: "ja")).message,
                       activeFallbacks["amount.error.asset"])
        XCTAssertEqual(L10n.InvoiceScan.Error.extractFail,
                       activeFallbacks["invoice_scan.error.extract_fail"])
    }

    @MainActor
    func testWalletSecondaryTextMeetsContrastInBothThemes() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        for mode in [SoramitsuThemeMode.manual(.light), .manual(.dark)] {
            SoramitsuUI.shared.themeMode = mode
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(WalletUX.secondary, WalletUX.page), 4.5)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(WalletUX.secondary, WalletUX.surface), 4.5)
        }
    }

    @MainActor
    func testBusySendCannotStartAnotherReview() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextView }.first).text = "recipient"
        try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextField }.first).text = "1"
        var reviews = 0
        view.onReview = { _, _ in reviews += 1; view.setBusy(true) }
        let primary = try XCTUnwrap(button("Review send", in: view.view))
        primary.sendActions(for: .touchUpInside)
        primary.sendActions(for: .touchUpInside)
        XCTAssertEqual(reviews, 1)
    }

    @MainActor
    func testEditingReviewPreservesDraftAndRequiresAnotherQuote() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        let recipient = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextView }.first)
        let amount = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextField }.first)
        recipient.text = "test-recipient-address"
        amount.text = "12.5"
        let quantity = try PIQuantity("12.5")
        let request = NexusTransferRequest(walletId: "test-wallet", networkId: .taira,
            sender: "test-sender", receiver: recipient.text, amount: quantity)
        let quote = NexusTransferFeeQuote(networkId: .taira, authority: "test-sender", receiver: recipient.text,
            assetDefinitionId: "test-asset", amount: quantity, fee: try PIQuantity("0.01"), quoteIdentity: "test-quote", validUntilBlock: 100)
        let prepared = NexusPreparedTransfer(request: request, canonicalReceiver: recipient.text,
            assetDefinitionID: "test-asset", availableBalance: try PIQuantity("100"), quote: quote)
        XCTAssertFalse(prepared.submissionMayHaveStarted)
        view.showReview(prepared)
        XCTAssertTrue(descendants(view.view).compactMap { ($0 as? UILabel)?.text }.contains("12.51 XOR"))
        let edit = try XCTUnwrap(button("Edit details", in: view.view))
        edit.sendActions(for: .touchUpInside)
        XCTAssertEqual(recipient.text, "test-recipient-address")
        XCTAssertEqual(amount.text, "12.5")
        var reviewedDraft: (String, String)?
        view.onReview = { reviewedDraft = ($0, $1) }
        view.onConfirm = { _ in XCTFail("Editing must invalidate the prepared quote") }
        try XCTUnwrap(button("Review send", in: view.view)).sendActions(for: .touchUpInside)
        XCTAssertEqual(reviewedDraft?.0, "test-recipient-address")
        XCTAssertEqual(reviewedDraft?.1, "12.5")

        view.showReview(prepared)
        view.setBusy(true)
        view.showUnsentError(WalletUX.sendError(NexusToriiError.quoteExpired))
        reviewedDraft = nil
        try XCTUnwrap(button("Review send", in: view.view)).sendActions(for: .touchUpInside)
        XCTAssertEqual(reviewedDraft?.0, "test-recipient-address")
        XCTAssertEqual(reviewedDraft?.1, "12.5")

        view.showReview(prepared)
        var submissions = 0
        view.onConfirm = { _ in submissions += 1; view.setBusy(true) }
        let confirm = try XCTUnwrap(button("Confirm and send", in: view.view))
        confirm.sendActions(for: .touchUpInside)
        confirm.sendActions(for: .touchUpInside)
        XCTAssertEqual(submissions, 1, "A busy confirmation must not submit twice")
        prepared.markTransportStarted()
        XCTAssertTrue(prepared.submissionMayHaveStarted)
    }

    func testAmbiguousSendNeverLooksCompletedOrInvitesResubmission() {
        XCTAssertNotEqual(WalletUX.status(.submissionUnknown), WalletUX.status(.committed))
        XCTAssertTrue(WalletUX.statusDetail(.submissionUnknown).contains("do not send it again"))
        XCTAssertTrue(WalletUX.sendError(NexusToriiError.ambiguousSubmission).contains("Activity"))
        XCTAssertNotEqual(WalletUX.status(.committedPendingReconciliation), WalletUX.status(.committed))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.ambiguousSubmission))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.confirmationAlreadySubmitted))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.transactionHashMismatch))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.httpStatus(500)))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.server))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.invalidResponse))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.insufficientBalance))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.quoteExpired))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.httpStatus(500), submissionMayHaveStarted: false),
                       "A failed read before transport must restore the draft")
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.quoteExpired, submissionMayHaveStarted: true),
                      "The transport boundary takes precedence over an error classification")
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.confirmationAlreadySubmitted, submissionMayHaveStarted: false))
    }

    @MainActor
    func testUncertainSubmissionOnlyOffersActivity() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        view.onConfirm = { _ in XCTFail("An uncertain submission must not be sent again") }
        view.onReview = { _, _ in XCTFail("An uncertain submission must not be reviewed again") }
        view.showUncertainSubmission(WalletUX.sendError(NexusToriiError.ambiguousSubmission))
        let primary = try XCTUnwrap(button("Review send", in: view.view))
        let edit = try XCTUnwrap(button("Edit details", in: view.view))
        XCTAssertTrue(primary.isHidden)
        XCTAssertTrue(edit.isHidden)
        XCTAssertFalse(try XCTUnwrap(button("View Activity", in: view.view)).isHidden)
        primary.sendActions(for: .touchUpInside)
        edit.sendActions(for: .touchUpInside)
        XCTAssertTrue(primary.isHidden)
    }

    func testDurableAncestorSynchronizationStopsAtContainerBeforeSandboxDeniedParent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let container = root.appendingPathComponent("AppHome", isDirectory: true)
        let shallow = container.appendingPathComponent("Documents/CoreData", isDirectory: true)
        let deep = container.appendingPathComponent("Library/Application Support/SORA/WalletNetworks", isDirectory: true)
        try FileManager.default.createDirectory(at: shallow, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let alias = root.appendingPathComponent("AppHomeAlias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: container)
        let homeDescriptor = Darwin.open(container.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(homeDescriptor, 0)
        defer { _ = Darwin.close(homeDescriptor) }
        var homeIdentity = stat()
        XCTAssertEqual(Darwin.fstat(homeDescriptor, &homeIdentity), 0)
        let cases: [(URL, URL, Int)] = [
            (container, container, 0),
            (shallow, container, 2),
            (deep, container, 4),
            (alias.appendingPathComponent("Documents/CoreData"), container, 2),
            (shallow, alias, 2)
        ]
        for (start, boundary, expectedOpens) in cases {
            let descriptor = Darwin.open(start.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            XCTAssertGreaterThanOrEqual(descriptor, 0)
            defer { _ = Darwin.close(descriptor) }
            var opens = 0
            var outsideContainerAttempted = false
            try DurableFileWriter.synchronizeAncestorDirectoryEntries(from: descriptor,
                maximumDepth: 4, containerURL: boundary, openParent: { current in
                    var identity = stat()
                    guard Darwin.fstat(current, &identity) == 0 else { return -1 }
                    if identity.st_dev == homeIdentity.st_dev && identity.st_ino == homeIdentity.st_ino {
                        outsideContainerAttempted = true
                        errno = EACCES
                        return -1
                    }
                    opens += 1
                    return Darwin.openat(current, "..", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                })
            XCTAssertEqual(opens, expectedOpens)
            XCTAssertFalse(outsideContainerAttempted,
                "The app container must be recognized before openat attempts its forbidden parent")
        }
        let descriptor = Darwin.open(shallow.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { _ = Darwin.close(descriptor) }
        var attempted = 0
        XCTAssertThrowsError(try DurableFileWriter.synchronizeAncestorDirectoryEntries(from: descriptor,
            maximumDepth: 4, containerURL: container, openParent: { _ in
                attempted += 1
                errno = EACCES
                return -1
            })) { error in
                guard case DurableFileWriter.Failure.fileSystemFailure = error else {
                    return XCTFail("An in-container durability failure must remain a failure")
                }
            }
        XCTAssertEqual(attempted, 1)
    }

    @MainActor
    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
    @MainActor
    private func button(_ title: String, in view: UIView) -> UIButton? {
        descendants(view).compactMap { $0 as? UIButton }.first {
            ($0.configuration?.title ?? $0.title(for: .normal)) == WalletUX.text(title)
        }
    }
}

/// Uses the production self-sizing portfolio notice cell for opt-in visual QA.
final class PortfolioNoticeVisualController: UITableViewController {
    let item: PortfolioNoticeItem
    init(item: PortfolioNoticeItem) { self.item = item; super.init(style: .plain) }
    required init?(coder: NSCoder) { nil }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = WalletUX.page
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 360
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = PortfolioNoticeCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.set(item: item, context: nil)
        return cell
    }
}

private final class WalletUXSecurityLayerStub: SecurityLayerInteractorInputProtocol {
    func setup() {}
}

private final class WalletUXRootPresenterSpy: RootInteractorOutputProtocol {
    enum Decision: Equatable { case onboarding, legacyWalletUpgrade, localAuthentication, broken, pincodeSetup, welcomeBack }
    var decisions: [Decision] = []
    func didDecideOnboarding() { decisions.append(.onboarding) }
    func didDecideLegacyWalletUpgrade() { decisions.append(.legacyWalletUpgrade) }
    func didDecideLocalAuthentication() { decisions.append(.localAuthentication) }
    func didDecideBroken() { decisions.append(.broken) }
    func didDecidePincodeSetup() { decisions.append(.pincodeSetup) }
    func didDecideWelcomeBack() { decisions.append(.welcomeBack) }
}

private final class WalletUXNoBiometry: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }
    func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }
}

private final class WalletUXPINViewSpy: UIViewController, PinSetupViewProtocol {
    var controller: UIViewController { self }
    var symbolCounts: [Int] = []
    var updateRequests = 0
    var titles: [String] = []
    var blockedDates: [Date] = []
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) { completionBlock(false) }
    func didChangeAccessoryState(enabled: Bool) {}
    func didReceiveWrongPincode() {}
    func updatePinCodeSymbolsCount(with count: Int) { symbolCounts.append(count) }
    func showUpdatePinRequestView() { updateRequests += 1 }
    func blockUserInputUntil(date: Date) { blockedDates.append(date) }
    func showLastChanceAlert() {}
    func updateInputedCircles(with count: Int) {}
    func setupDeleteButton(isHidden: Bool) {}
    func setupTitleLabel(text: String) { titles.append(text) }
    func resetTitleColor() {}
    func animateWrongInputError(with completion: @escaping (Bool) -> Void) { completion(true) }
    func askBiometryPermission() {}
}

private final class WalletUXLocalAuthSpy: LocalAuthInteractorInputProtocol {
    var allowManualBiometryAuth: Bool { false }
    var countRequests = 0
    var submitted: [String] = []
    var updated: [String] = []
    var blockDate: Date?
    func startAuth(completion: (() -> Void)?) {}
    func process(pin: String) { submitted.append(pin) }
    func getPinCodeCount() { countRequests += 1 }
    func getInputBlockDate() -> Date? { blockDate }
    func updatePin(pin: String, completion: (() -> Void)?) { updated.append(pin); completion?() }
}

private final class WalletUXPINWireframeSpy: PinSetupWireframeProtocol {
    weak var errorView: UIViewController?
    weak var fallbackView: UIViewController?
    var fallbackMessage: String?
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        errorView = view?.controller
        return false
    }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {
        fallbackView = view?.controller
        fallbackMessage = message
    }
    var mainCount = 0
    func dismiss(from view: PinSetupViewProtocol?) {}
    func showMain(from view: PinSetupViewProtocol?) { mainCount += 1 }
    func showSignup(from view: PinSetupViewProtocol?) {}
    func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void) { completionBlock() }
}

private final class WalletUXAuthorizationSpy: ScreenAuthorizationWireframeProtocol {
    var results: [Bool] = []
    func showAuthorizationCompletion(with result: Bool) { results.append(result) }
}

private final class WalletUXNetworkStatusSpy: ApplicationStatusPresentable {
    var alerts = 0
    var statuses: [String] = []
    func presentAlert(alert: UIAlertController, animated: Bool) { alerts += 1 }
    func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool) { statuses.append(title) }
    func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool) {}
}

// Test-only projections leave the production JSON decoder's access control intact.
extension NexusJSONValue {
    var nexusTestObject: [String: NexusJSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }
    var nexusTestArray: [NexusJSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }
    var nexusTestString: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

/// SORA Neon foundation (design spec §2–§7): fonts, palettes, components and
/// theme plumbing.
final class SoraNeonDesignTests: XCTestCase {

    /// "Reduce effects" is the app's own preference, and only these tests
    /// write it. A run that is killed while a test holds it at `true` leaves
    /// it set on that simulator: tests that need the default effect tier
    /// then skipped themselves on every later run, and the installed app
    /// stayed in the MINIMAL tier. It is cleared before and after every test
    /// here, through the policy so that every observer follows.
    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated { resetReduceEffects() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { resetReduceEffects() }
        super.tearDown()
    }

    func testBundledSoraFontLoads() {
        // Before 3.9.0 the font name was built from enum case names
        // ("headline-one") and every style fell back to the system font.
        XCTAssertEqual(FontType.headline1.postScriptName, "Sora-Bold")
        XCTAssertEqual(FontType.headline1.font.fontName, "Sora-Bold")
        XCTAssertEqual(FontType.buttonM.font.fontName, "Sora-SemiBold")
        XCTAssertEqual(FontType.headline4.font.fontName, "Sora-SemiBold")
        XCTAssertEqual(FontType.pinDigit.font.fontName, "Sora-Regular")
        XCTAssertEqual(FontType.textM.postScriptName, "Inter-Regular")
        XCTAssertEqual(FontType.textM.font.familyName, "Inter")
        XCTAssertTrue(FontType.mono.font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        // Fonts are cached.
        XCTAssertTrue(FontType.textS.font === FontType.textS.font)
    }

    func testNeonPalettesKeepTextReadable() {
        for theme in [SoramitsuThemeType.light, .dark] {
            let palette = theme.palette
            func check(_ foreground: SoramitsuColor, _ background: SoramitsuColor, line: UInt = #line) {
                let ratio = WalletUX.contrast(palette.color(foreground), palette.color(background))
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(theme) \(foreground) on \(background)", line: line)
            }
            check(.fgPrimary, .bgPage)
            check(.fgPrimary, .bgSurface)
            check(.fgSecondary, .bgPage)
            check(.fgSecondary, .bgSurface)
            check(.fgTertiary, .bgSurface)
            check(.fgPrimary, .bgSurfaceVariant)
            // Dark containers used to be light pastels behind light text (1.09:1).
            check(.fgPrimary, .statusWarningContainer)
            check(.statusWarning, .statusWarningContainer)
            check(.fgPrimary, .statusSuccessContainer)
            check(.statusSuccess, .statusSuccessContainer)
            check(.fgPrimary, .statusErrorContainer)
            check(.statusError, .statusErrorContainer)
            check(.statusInfo, .statusInfoContainer)
            check(.accentPrimary, .accentPrimaryContainer)
            check(.accentTertiary, .accentTertiaryContainer)
            // Ink on neon in dark, white on accent in light.
            check(.fgInverted, .accentPrimary)
            check(.fgInverted, .additionalPolkaswap)
            // The Polkaswap brand fill is 4.33:1 as text on its light
            // container; labels there use the text token.
            check(.additionalPolkaswapText, .additionalPolkaswapContainer)
            check(.additionalPolkaswapText, .bgSurface)
        }
    }

    @MainActor
    func testButtonKeepsCallerBackgroundAndDrawsNeonCTA() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        SoramitsuUI.shared.themeMode = .manual(.light)
        let custom = SoramitsuButton()
        custom.sora.backgroundColor = .bgSurface
        let clear = SoramitsuButton()
        clear.sora.backgroundColor = .custom(uiColor: .clear)
        let cta = SoramitsuButton()
        let icon = SoramitsuButton()
        icon.sora.backgroundColor = .bgSurface
        icon.sora.tintColor = .accentTertiary
        icon.sora.rightImage = UIImage(systemName: "arrow.right")
        for theme in [SoramitsuThemeType.dark, .light] {
            SoramitsuUI.shared.themeMode = .manual(theme)
            // A chosen image tint survives theme changes.
            XCTAssertEqual(icon.rightImageView.tintColor, theme.palette.color(.accentTertiary))
            // A theme change used to reset a chosen background to the type colour.
            XCTAssertEqual(custom.backgroundColor, theme.palette.color(.bgSurface))
            XCTAssertEqual(clear.backgroundColor, .clear)
            XCTAssertFalse(clear.layer.sublayers?.contains { $0 is CAGradientLayer } ?? false)
            // The primary CTA is a gradient fill with an ink (dark) or white (light) label.
            XCTAssertEqual(cta.backgroundColor, .clear)
            XCTAssertTrue(cta.layer.sublayers?.contains { $0 is CAGradientLayer } ?? false)
        }
        cta.sora.isEnabled = false
        XCTAssertEqual(cta.backgroundColor, NeonTokens.light.ctaDisabled)
        XCTAssertFalse(cta.layer.sublayers?.contains { $0 is CAGradientLayer } ?? false)
        custom.sora.isEnabled = false
        custom.sora.isEnabled = true
        XCTAssertEqual(custom.backgroundColor, SoramitsuThemeType.light.palette.color(.bgSurface))
    }

    @MainActor
    func testWindowsFollowTheInAppTheme() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        let window = UIWindow.makeSoraSceneWindow()
        defer { window.isHidden = true }
        let detached = UIWindow(frame: .zero)
        for (mode, style) in [(SoramitsuThemeMode.manual(.dark), UIUserInterfaceStyle.dark),
                              (.manual(.light), .light), (.system, .unspecified)] {
            SoramitsuUI.shared.themeMode = mode
            XCTAssertEqual(SoramitsuUI.shared.userInterfaceStyle, style)
            SoramitsuUI.shared.applyInterfaceStyle(to: detached)
            XCTAssertEqual(detached.overrideUserInterfaceStyle, style)
            if window.windowScene != nil {
                // Windows in the scene are updated by the theme change itself.
                XCTAssertEqual(window.overrideUserInterfaceStyle, style)
            }
        }
    }

    @MainActor
    func testLegacyCardsAreOpaqueWithOneHairline() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        SoramitsuUI.shared.themeMode = .manual(.dark)
        let card = SoramitsuView()
        card.sora.backgroundColor = .bgSurface
        card.sora.cornerRadius = .max
        let row = SoramitsuView()
        row.sora.backgroundColor = .bgSurface
        row.sora.cornerRadius = .max
        card.addSubview(row)
        card.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        row.bounds = CGRect(x: 0, y: 0, width: 300, height: 60)
        XCTAssertEqual(card.backgroundColor, SoramitsuThemeType.dark.palette.color(.bgSurface))
        XCTAssertGreaterThanOrEqual(card.layer.borderWidth, 1)
        XCTAssertEqual(card.layer.cornerRadius, 24)
        XCTAssertEqual(row.layer.borderWidth, 0, "a card inside a card gets no second outline")
        let outlined = SoramitsuView()
        outlined.sora.backgroundColor = .bgSurface
        outlined.sora.cornerRadius = .max
        outlined.sora.borderWidth = 2
        XCTAssertEqual(outlined.layer.borderWidth, 2, "a caller's border wins")
        card.sora.backgroundColor = .bgPage
        XCTAssertEqual(card.layer.borderWidth, 0, "not a card any more")
    }

    @MainActor
    func testRecoveryAndUpgradeScreensUseTheAppTheme() throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        for theme in [SoramitsuThemeType.dark, .light] {
            SoramitsuUI.shared.themeMode = .manual(theme)
            let canvas = NeonTokens.tokens(for: theme).canvas
            let recovery = WalletRecoveryViewController(reason: "retained missing credentials", onRetry: {})
            recovery.loadViewIfNeeded()
            XCTAssertEqual(recovery.view.backgroundColor, canvas)
            let retry = try XCTUnwrap(descendants(recovery.view).compactMap { $0 as? WalletNeonButton }
                .first { $0.accessibilityIdentifier == "wallet-recovery-retry" })
            XCTAssertEqual(retry.neonStyle, .safe)
            XCTAssertFalse(descendants(recovery.view).contains { $0.backgroundColor == .systemBackground })

            let upgrade = LegacyWalletUpgradeViewController(onConfirm: {})
            upgrade.loadViewIfNeeded()
            XCTAssertEqual(upgrade.view.backgroundColor, canvas)
            let upgradeButton = try XCTUnwrap(descendants(upgrade.view).compactMap { $0 as? UIButton }.first {
                $0.accessibilityIdentifier == RetainedMigrationEvidenceHarness.continueUpgradeAccessibilityIdentifier
            })
            XCTAssertEqual(upgradeButton.title(for: .normal), WalletUX.text("Upgrade wallet"))

            let welcome = WalletWelcomeBackViewController(onContinueToOnboarding: {}, onWalletsRestored: {})
            welcome.loadViewIfNeeded()
            XCTAssertEqual(welcome.view.backgroundColor, canvas)
        }
    }

    // MARK: - Review fixes for the foundation

    /// Text bar buttons ("Add node", "Edit", "Skip", "Create pool") were red
    /// (`#EE2233` / `accentPrimary`), which is 3.3:1 on a light bar and
    /// reads as an error. The bar appearance now styles them in one place.
    @MainActor
    func testBarTextButtonsUseColoursThatAreReadableOnBars() throws {
        // Worst-case bars of spec §3: the bar tint over white content (dark
        // theme) or black content (light theme).
        let worstBar: [SoramitsuThemeType: UIColor] = [.dark: UIColor(hex: "#3B3B41"), .light: UIColor(hex: "#C2C2C6")]
        for theme in [SoramitsuThemeType.dark, .light] {
            let tokens = NeonTokens.tokens(for: theme)
            let bar = try XCTUnwrap(worstBar[theme])
            let (standard, scrollEdge) = NeonChrome.navigationBarAppearances(tokens: tokens)
            for appearance in [standard, scrollEdge] {
                for button in [appearance.buttonAppearance, appearance.doneButtonAppearance] {
                    let color = try XCTUnwrap(button.normal.titleTextAttributes[.foregroundColor] as? UIColor)
                    XCTAssertGreaterThanOrEqual(WalletUX.contrast(color, bar), 4.5, "\(theme)")
                    XCTAssertEqual(color, NeonChrome.barButtonTitleColor(tokens: tokens))
                    let font = try XCTUnwrap(button.normal.titleTextAttributes[.font] as? UIFont)
                    XCTAssertEqual(font.fontName, FontType.textBoldS.font.fontName)
                }
                // Back titles stay hidden in every state.
                for state in [appearance.backButtonAppearance.normal, appearance.backButtonAppearance.highlighted,
                              appearance.backButtonAppearance.focused, appearance.backButtonAppearance.disabled] {
                    XCTAssertEqual(state.titleTextAttributes[.foregroundColor] as? UIColor, UIColor.clear)
                }
            }
        }

        // A screen no longer gives its bar button a colour of its own.
        let nodes = NodesViewController()
        nodes.presenter = NeonNodesPresenterStub()
        nodes.loadViewIfNeeded()
        nodes.setup(with: [])
        let addNode = try XCTUnwrap(nodes.navigationItem.rightBarButtonItem)
        XCTAssertNil(addNode.titleTextAttributes(for: .normal)?[.foregroundColor])
    }

    /// Opened from More, the node list is the root of a modal. Its only
    /// ways out were pull-down gestures; it now also has a Close button.
    @MainActor
    func testModalNodeListHasAVisibleCloseButton() throws {
        let host = UIViewController()
        let window = UIWindow.makeSoraSceneWindow()
        window.rootViewController = host
        window.isHidden = false
        defer {
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }
        let modal = NodesViewController()
        modal.presenter = NeonNodesPresenterStub()
        let navigation = UINavigationController(rootViewController: modal)
        host.present(navigation, animated: false)
        modal.loadViewIfNeeded()
        modal.setup(with: [])
        let close = try XCTUnwrap(modal.navigationItem.leftBarButtonItem)
        XCTAssertEqual(close.accessibilityLabel, R.string.localizable.commonClose(preferredLanguages: nil))
        XCTAssertNotNil(modal.navigationItem.rightBarButtonItem, "Add node stays")

        // Pushed (as from the PIN screen) it keeps the Back arrow instead.
        let pushed = NodesViewController()
        pushed.presenter = NeonNodesPresenterStub()
        navigation.pushViewController(pushed, animated: false)
        pushed.loadViewIfNeeded()
        pushed.setup(with: [])
        XCTAssertNil(pushed.navigationItem.leftBarButtonItem)
    }

    /// The glow is opt-in for the one screen-level CTA, is never drawn in a
    /// table or collection cell, and becomes a ring under "Reduce effects".
    /// Before, every filled primary button glowed, also in lists.
    @MainActor
    func testButtonGlowIsOptInNeverInListsAndARingInTheMinimalTier() throws {
        try requireDefaultEffectTier()
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        SoramitsuUI.shared.themeMode = .manual(.dark)
        func glows(_ view: UIView) -> Int { view.layer.sublayers?.filter { $0.shadowOpacity > 0 }.count ?? 0 }
        func rings(_ view: UIView) -> Int { view.layer.sublayers?.filter { $0 is NeonRingLayer }.count ?? 0 }

        let plain = SoramitsuButton()
        XCTAssertEqual(glows(plain), 0, "off unless the screen asks for it")
        XCTAssertTrue(plain.layer.sublayers?.contains { $0 is CAGradientLayer } ?? false,
                      "the neon fill does not depend on the glow")

        let cta = SoramitsuButton()
        cta.sora.glows = true
        XCTAssertEqual(glows(cta), 1)
        XCTAssertFalse(cta.clipsToBounds, "a clipped button would hide its glow")

        // Whether a button sits in a cell is known once it is in a window.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let inCell = SoramitsuButton()
        inCell.sora.glows = true
        cell.contentView.addSubview(inCell)
        window.addSubview(cell)
        XCTAssertEqual(glows(inCell), 0, "never in a table cell")
        let item = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        let inItem = SoramitsuButton()
        inItem.sora.glows = true
        item.contentView.addSubview(inItem)
        window.addSubview(item)
        XCTAssertEqual(glows(inItem), 0, "never in a collection cell")

        // The Safe Mode and onboarding buttons follow the same rules.
        let host = UIViewController()
        let scene = UIWindow.makeSoraSceneWindow()
        scene.rootViewController = host
        scene.isHidden = false
        defer { scene.isHidden = true; scene.rootViewController = nil }
        let neon = WalletNeonButton(style: .primary)
        neon.frame = CGRect(x: 20, y: 80, width: 240, height: 56)
        host.view.addSubview(neon)
        let neonCell = UITableViewCell(style: .default, reuseIdentifier: nil)
        neonCell.frame = CGRect(x: 0, y: 200, width: 300, height: 60)
        let neonInCell = WalletNeonButton(style: .primary)
        neonInCell.frame = CGRect(x: 20, y: 2, width: 240, height: 56)
        neonCell.contentView.addSubview(neonInCell)
        host.view.addSubview(neonCell)
        settle()
        XCTAssertGreaterThan(neon.layer.shadowOpacity, 0)
        XCTAssertEqual(neonInCell.layer.shadowOpacity, 0, "never in a table cell")

        // MINIMAL tier: a 1.5 pt ring in the glow colour, no blur.
        setReduceEffects(true)
        settle()
        XCTAssertEqual(FxPolicy.current.tier, .minimal)
        XCTAssertEqual(glows(cta), 0)
        XCTAssertEqual(rings(cta), 1)
        XCTAssertEqual(glows(inCell), 0)
        XCTAssertEqual(rings(inCell), 0)
        XCTAssertEqual(neon.layer.shadowOpacity, 0)
        XCTAssertEqual(rings(neon), 1)
        XCTAssertEqual(rings(neonInCell), 0)
        let ring = try XCTUnwrap(cta.layer.sublayers?.compactMap { $0 as? NeonRingLayer }.first)
        XCTAssertEqual(ring.borderWidth, 1.5)
        XCTAssertEqual(ring.borderColor, NeonTokens.dark.glowPrimary.color.withAlphaComponent(0.8).cgColor)

        setReduceEffects(false)
        settle()
        XCTAssertEqual(glows(cta), 1)
        XCTAssertEqual(rings(cta), 0)
        XCTAssertGreaterThan(neon.layer.shadowOpacity, 0)
        XCTAssertEqual(rings(neon), 0)
    }

    /// An accessibility or power change used to re-apply the whole palette,
    /// rebuilding every label. It now sends one effects-only update, and
    /// nothing when the resulting policy did not change.
    @MainActor
    func testEffectChangesSendOneEffectsUpdate() throws {
        try requireDefaultEffectTier()
        let spy = NeonStyleSpy()
        SoramitsuUI.updates.addObserver(spy)
        defer { SoramitsuUI.updates.removeObserver(spy) }

        setReduceEffects(true)
        XCTAssertEqual(spy.received.map(\.rawValue), [UpdateOptions.effects.rawValue])
        XCTAssertFalse(UpdateOptions.effects.contains(.palette))

        // The same policy again (several system notifications arrive for one
        // change): nothing is posted.
        let quiet = expectation(forNotification: .neonFxChanged, object: nil)
        quiet.isInverted = true
        FxPolicy.reduceEffects = true
        wait(for: [quiet], timeout: 0.3)
        XCTAssertEqual(spy.received.count, 1)

        setReduceEffects(false)
        XCTAssertEqual(spy.received.map(\.rawValue), [UpdateOptions.effects.rawValue, UpdateOptions.effects.rawValue])
    }

    /// A caller's attributed title kept its own colour on the neon fill:
    /// white on the dark swap gradient (3.6:1). It now takes the label
    /// colour of the fill and of the disabled state.
    @MainActor
    func testAttributedButtonTitlesFollowTheFillAndTheDisabledState() throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        func titleColor(_ button: SoramitsuButton) -> UIColor? {
            let label = descendants(button).compactMap { $0 as? UILabel }.first { ($0.attributedText?.length ?? 0) > 0 }
            return label?.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        }
        SoramitsuUI.shared.themeMode = .manual(.light)
        let swap = SoramitsuButton()
        swap.sora.backgroundColor = .additionalPolkaswap
        swap.sora.attributedText = SoramitsuTextItem(text: "Start staking", fontData: FontType.buttonM,
                                                     textColor: .custom(uiColor: .white), alignment: .center)
        let remove = SoramitsuButton()
        remove.sora.backgroundColor = .additionalPolkaswapContainer
        remove.sora.attributedText = SoramitsuTextItem(text: "Remove", fontData: FontType.buttonM,
                                                       textColor: .additionalPolkaswapText, alignment: .center)
        for theme in [SoramitsuThemeType.dark, .light] {
            SoramitsuUI.shared.themeMode = .manual(theme)
            let tokens = NeonTokens.tokens(for: theme)
            XCTAssertEqual(titleColor(swap), tokens.onAccent, "ink on neon in dark, white in light")
            swap.sora.isEnabled = false
            XCTAssertEqual(titleColor(swap), tokens.textDisabled)
            swap.sora.isEnabled = true
            XCTAssertEqual(titleColor(swap), tokens.onAccent)
            // Off the neon fill the caller's colour is kept.
            XCTAssertEqual(titleColor(remove), tokens.polkaswapText)
        }
    }

    /// The custom bar draws its notch and active-item pill only before
    /// Liquid Glass, and the whole swap disc (glow and fill included) can
    /// move to the system bar if the custom bar cannot be installed.
    @MainActor
    func testTabBarChromeAndSwapDisc() throws {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 83)
        XCTAssertEqual(TabBar(frame: frame).drawsLegacyChrome, !NeonChrome.usesLiquidGlass)
        // The bar's own drawing: plain layers, not the layers of UIKit's views.
        func pill(_ bar: TabBar) -> CALayer? {
            bar.layer.sublayers?.first { !($0 is CAShapeLayer) && $0.cornerRadius == 1.5 && $0.delegate == nil }
        }
        func chromeShapes(_ bar: TabBar) -> Int {
            bar.layer.sublayers?.filter { $0 is CAShapeLayer && $0.delegate == nil }.count ?? 0
        }
        func items() -> [UITabBarItem] {
            (0 ..< 5).map { UITabBarItem(title: "Tab \($0)", image: UIImage(systemName: "circle.fill"), tag: $0) }
        }

        // iOS 26+: nothing is painted over the system Liquid Glass bar.
        let glass = TabBar(frame: frame, drawsLegacyChrome: false)
        glass.items = items()
        glass.selectedItem = glass.items?.first
        glass.draw(glass.bounds)
        glass.layoutIfNeeded()
        XCTAssertEqual(chromeShapes(glass), 0)
        XCTAssertNil(pill(glass))

        // iOS 16–25: notch, hairline and a 16 × 3 pill over the selected item.
        let legacy = TabBar(frame: frame, drawsLegacyChrome: true)
        legacy.items = items()
        legacy.selectedItem = legacy.items?.first
        legacy.draw(legacy.bounds)
        legacy.layoutIfNeeded()
        XCTAssertEqual(chromeShapes(legacy), 2, "the notched fill and its top hairline")
        let indicator = try XCTUnwrap(pill(legacy))
        let itemViews = legacy.subviews
            .filter { $0 is UIControl && $0 !== legacy.coverButton && $0 !== legacy.middleButton }
            .sorted { $0.frame.minX < $1.frame.minX }
        if itemViews.count == 5 {
            XCTAssertFalse(indicator.isHidden)
            XCTAssertEqual(indicator.frame.size, CGSize(width: 16, height: 3))
            XCTAssertEqual(indicator.frame.midX, itemViews[0].frame.midX, accuracy: 0.5)
            XCTAssertGreaterThanOrEqual(indicator.frame.minY, 0)
            legacy.selectedItem = legacy.items?[3]
            legacy.updateSelectionIndicator(animated: false)
            XCTAssertEqual(indicator.frame.midX, itemViews[3].frame.midX, accuracy: 0.5)
            // The centre item is the swap disc, not a tab.
            legacy.selectedItem = legacy.items?[2]
            legacy.updateSelectionIndicator(animated: false)
            XCTAssertTrue(indicator.isHidden)
        } else {
            // On a Liquid Glass runtime the item views are not the bar's own
            // subviews: the pill stays hidden instead of guessing a place.
            XCTAssertTrue(indicator.isHidden)
        }

        // The swap-in itself (key-value coding on `_tabBar`) works on this
        // system. If a future iOS renames that storage this fails here
        // first; the app then keeps the system bar and moves the disc onto it.
        let controller = MainTabBarViewController()
        controller.loadViewIfNeeded()
        XCTAssertTrue(controller.tabBar is TabBar)
        XCTAssertEqual((controller.tabBar as? TabBar)?.drawsLegacyChrome, !NeonChrome.usesLiquidGlass)

        // Fallback: the disc moves as a whole.
        let system = UITabBar(frame: frame)
        glass.installSwapDisc(in: system)
        for view in [glass.coverButton, glass.middleButton, glass.middleButtonTitleLabel] as [UIView] {
            XCTAssertTrue(view.superview === system)
        }
        XCTAssertEqual(system.subviews.filter { $0 is GlowHostView }.count, 1)
        XCTAssertEqual(system.subviews.filter { $0 is NeonGradientView }.count, 1)
        XCTAssertFalse(glass.subviews.contains { $0 is GlowHostView || $0 is NeonGradientView })
        system.layoutIfNeeded()
        XCTAssertEqual(glass.middleButton.frame.midX, system.bounds.midX, accuracy: 0.5)
        let fill = try XCTUnwrap(system.subviews.first { $0 is NeonGradientView })
        XCTAssertEqual(fill.frame, glass.middleButton.frame)
    }

    /// On a small screen or at a large text size the 1.x upgrade screen
    /// centred its content on the visible frame, so the content followed the
    /// scroll offset and its last actions could never be scrolled into view;
    /// the low-storage panel did not scroll at all.
    @MainActor
    func testSafeModePanelsScrollToTheirLastAction() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        defer { window.isHidden = true; window.rootViewController = nil }

        func assertReachable(_ view: UIView, in scroll: UIScrollView, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
            scroll.superview?.layoutIfNeeded()
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height, "content is taller than the screen",
                                 file: file, line: line)
            // Scroll to the end, as a user would, and lay out again.
            for _ in 0 ..< 3 {
                scroll.contentOffset = CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height))
                scroll.superview?.setNeedsLayout()
                scroll.superview?.layoutIfNeeded()
                scroll.layoutIfNeeded()
            }
            let visible = scroll.convert(scroll.bounds, to: nil).insetBy(dx: -1, dy: -1)
            XCTAssertTrue(visible.contains(view.convert(view.bounds, to: nil)), message, file: file, line: line)
        }

        let upgrade = LegacyWalletUpgradeViewController(onConfirm: {})
        window.rootViewController = upgrade
        window.isHidden = false
        upgrade.view.layoutIfNeeded()
        let upgradeScroll = try XCTUnwrap(descendants(upgrade.view).compactMap { $0 as? UIScrollView }.first)
        let details = try XCTUnwrap(descendants(upgradeScroll).compactMap { $0 as? UIButton }.last)
        XCTAssertEqual(details.title(for: .normal), WalletUX.text("What happens during the upgrade?"))
        assertReachable(details, in: upgradeScroll, "the last action can be scrolled into view")
        let confirm = try XCTUnwrap(descendants(upgradeScroll).compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == RetainedMigrationEvidenceHarness.continueUpgradeAccessibilityIdentifier
        })
        XCTAssertTrue(CGRect(origin: .zero, size: upgradeScroll.contentSize)
            .contains(confirm.convert(confirm.bounds, to: upgradeScroll)), "Upgrade wallet is inside the scrollable content")
        // And the top is still there after scrolling back.
        upgradeScroll.contentOffset = .zero
        upgrade.view.setNeedsLayout()
        upgrade.view.layoutIfNeeded()
        let title = try XCTUnwrap(descendants(upgradeScroll).compactMap { $0 as? UILabel }
            .first { $0.text == WalletUX.text("Upgrade your wallet") })
        XCTAssertTrue(upgradeScroll.convert(upgradeScroll.bounds, to: nil).insetBy(dx: -1, dy: -1)
            .contains(title.convert(title.bounds, to: nil)))

        let splashWindow = SoraWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        let presenter = SplashPresenter(window: splashWindow)
        let splash = SplashViewController()
        splash.presenter = presenter
        presenter.view = splash
        window.rootViewController = splash
        splash.showStorageSpaceRetry {}
        splash.view.layoutIfNeeded()
        let retry = try XCTUnwrap(descendants(splash.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-upgrade-storage-retry" })
        let panelScroll = try XCTUnwrap(sequence(first: retry as UIView, next: \.superview)
            .compactMap { $0 as? UIScrollView }.first, "the low-storage panel scrolls")
        assertReachable(retry, in: panelScroll, "Check again can be scrolled into view")

        // Content that fits is centred, not pinned to the top.
        let tall = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        defer { tall.isHidden = true; tall.rootViewController = nil }
        let roomy = LegacyWalletUpgradeViewController(onConfirm: {})
        tall.rootViewController = roomy
        tall.isHidden = false
        roomy.view.layoutIfNeeded()
        let roomyScroll = try XCTUnwrap(descendants(roomy.view).compactMap { $0 as? UIScrollView }.first)
        let stack = try XCTUnwrap(roomyScroll.subviews.compactMap { $0 as? UIStackView }.first)
        XCTAssertEqual(roomyScroll.contentSize.height, roomyScroll.bounds.height, accuracy: 0.5)
        XCTAssertEqual(stack.frame.midY, roomyScroll.bounds.height / 2, accuracy: 1)
    }

    /// The amount card on Send and Swap was a Soramitsu view with a
    /// configuration of its own, while the field drew the input chrome
    /// (fill, border, focus glow) on the same layer. A style update reaches
    /// the two in no defined order. When the card's came second it put back
    /// its palette fill, cleared the border colour and removed the focus
    /// glow until the field was focused again. One writer draws it now, from
    /// the first display on.
    @MainActor
    func testAmountCardChromeSurvivesStyleUpdatesInAnyOrder() throws {
        try requireDefaultEffectTier()
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        SoramitsuUI.shared.themeMode = .manual(.dark)

        let host = UIViewController()
        let window = UIWindow.makeSoraSceneWindow()
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let field = InputAssetField()
        host.view.addSubview(field)
        let width = field.widthAnchor.constraint(equalToConstant: 320)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 120),
            field.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            width
        ])
        host.view.layoutIfNeeded()
        let card = try XCTUnwrap(field.subviews.first)
        XCTAssertEqual(card.frame, field.bounds)
        XCTAssertGreaterThan(card.bounds.height, 0)
        XCTAssertFalse(field.clipsToBounds, "the card fills the control: a clipping control leaves only the glow's corners")

        func assertChrome(_ tokens: NeonTokens, focused: Bool, glow: Bool, _ message: String,
                          file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(card.backgroundColor, tokens.inputFill, message, file: file, line: line)
            XCTAssertEqual(card.layer.borderColor, (focused ? tokens.cyan : tokens.borderInput).cgColor, message,
                           file: file, line: line)
            XCTAssertEqual(card.layer.borderWidth, focused ? 1.5 : 1, message, file: file, line: line)
            XCTAssertEqual(card.layer.cornerRadius, 24, message, file: file, line: line)
            XCTAssertFalse(card.clipsToBounds, "a clipped card would hide its glow", file: file, line: line)
            if glow {
                XCTAssertEqual(card.layer.shadowOpacity, tokens.glowFocus.rest, message, file: file, line: line)
                XCTAssertEqual(card.layer.shadowColor, tokens.glowFocus.color.cgColor, message, file: file, line: line)
                // An explicit path the size of the card (spec §10.3).
                let path = card.layer.shadowPath?.boundingBoxOfPath ?? .zero
                XCTAssertEqual(path.width, card.bounds.width, accuracy: 0.5, message, file: file, line: line)
                XCTAssertEqual(path.height, card.bounds.height, accuracy: 0.5, message, file: file, line: line)
            } else {
                XCTAssertEqual(card.layer.shadowOpacity, 0, message, file: file, line: line)
            }
        }
        /// The style keeps its observers in a hash table and notifies them in
        /// no defined order. This replays the worst one: the field first,
        /// then the card, if the card has a configuration of its own.
        func notifyFieldThenCard(_ options: UpdateOptions) {
            field.sora.styleDidChange(options: options)
            (card as? SoramitsuView)?.sora.styleDidChange(options: options)
        }
        let dark = NeonTokens.dark
        let light = NeonTokens.light

        // Before the first focus: the input chrome, not a bare palette card.
        assertChrome(dark, focused: false, glow: false, "at rest, never focused")

        field.sora.state = .focused
        assertChrome(dark, focused: true, glow: true, "focused")

        // The reported case: Low Power Mode off, Reduce Motion toggled.
        notifyFieldThenCard(.effects)
        assertChrome(dark, focused: true, glow: true, "after an effects update")
        notifyFieldThenCard(.palette)
        assertChrome(dark, focused: true, glow: true, "after a palette update")

        // The same through the real notifications, in whatever order.
        setReduceEffects(true)
        settle()
        assertChrome(dark, focused: true, glow: false, "MINIMAL tier: border only")
        setReduceEffects(false)
        settle()
        assertChrome(dark, focused: true, glow: true, "back in the FULL tier, without focusing again")
        SoramitsuUI.shared.themeMode = .manual(.light)
        assertChrome(light, focused: true, glow: false, "light: no focus glow")
        notifyFieldThenCard(.palette)
        assertChrome(light, focused: true, glow: false, "light, after a palette update")
        SoramitsuUI.shared.themeMode = .manual(.dark)
        assertChrome(dark, focused: true, glow: true, "dark again")

        // The glow follows the card when its size changes.
        width.constant = 280
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        settle()
        XCTAssertEqual(card.bounds.width, 280)
        assertChrome(dark, focused: true, glow: true, "after a size change")

        field.sora.state = .default
        assertChrome(dark, focused: false, glow: false, "at rest again")
        notifyFieldThenCard(.effects)
        notifyFieldThenCard(.palette)
        assertChrome(dark, focused: false, glow: false, "at rest, after style updates")
    }

    /// The focus glow of a field was cut by the field itself: `InputField`
    /// showed a strip of it under the field, the amount card only its four
    /// corners. It is now drawn whole or not at all: never around a secret,
    /// never in a list cell, and not where an ancestor would cut it. The
    /// focused border is always there.
    @MainActor
    func testFocusGlowIsDrawnWholeOrNotAtAll() throws {
        try requireDefaultEffectTier()
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        SoramitsuUI.shared.themeMode = .manual(.dark)
        let tokens = NeonTokens.dark

        let host = UIViewController()
        let window = UIWindow.makeSoraSceneWindow()
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let width = host.view.bounds.width
        XCTAssertGreaterThan(width, 300)

        func place(_ view: UIView, in container: UIView, top: CGFloat, inset: CGFloat) {
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: container.topAnchor, constant: top),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset)
            ])
        }
        func box(at y: CGFloat, height: CGFloat, inset: CGFloat, clips: Bool) -> UIView {
            let view = UIView(frame: CGRect(x: inset, y: y, width: width - 2 * inset, height: height))
            view.clipsToBounds = clips
            host.view.addSubview(view)
            return view
        }
        /// The focused border is there with or without the glow.
        func assertGlow(_ field: UIView, _ expected: Bool, _ message: String,
                        file: StaticString = #filePath, line: UInt = #line) {
            guard let chrome = field.subviews.first else { return XCTFail("no chrome view", file: file, line: line) }
            XCTAssertEqual(chrome.layer.borderColor, tokens.cyan.cgColor, message, file: file, line: line)
            XCTAssertEqual(chrome.layer.borderWidth, 1.5, message, file: file, line: line)
            guard expected else {
                return XCTAssertEqual(chrome.layer.shadowOpacity, 0, message, file: file, line: line)
            }
            XCTAssertEqual(chrome.layer.shadowOpacity, tokens.glowFocus.rest, message, file: file, line: line)
            XCTAssertEqual(chrome.layer.shadowColor, tokens.glowFocus.color.cgColor, message, file: file, line: line)
            let path = chrome.layer.shadowPath?.boundingBoxOfPath ?? .zero
            XCTAssertGreaterThan(chrome.bounds.height, 0, message, file: file, line: line)
            XCTAssertEqual(path.width, chrome.bounds.width, accuracy: 0.5, message, file: file, line: line)
            XCTAssertEqual(path.height, chrome.bounds.height, accuracy: 0.5, message, file: file, line: line)
            // Nothing between the field and the window cuts it.
            let reach = chrome.layer.shadowRadius * 2
            XCTAssertEqual(reach, 12, message, file: file, line: line)
            var ancestor = chrome.superview
            while let current = ancestor {
                if current.clipsToBounds {
                    let glow = chrome.convert(chrome.bounds.insetBy(dx: -reach, dy: -reach), to: current)
                    XCTAssertTrue(current.bounds.insetBy(dx: -0.5, dy: -0.5).contains(glow),
                                  "\(message): cut by \(type(of: current))", file: file, line: line)
                }
                ancestor = current.superview
            }
        }

        // On a screen, 24 pt from the edges: the whole glow.
        let name = InputField()
        place(name, in: host.view, top: 80, inset: 24)
        // A password and the field the recovery phrase is typed into: none.
        let password = InputField()
        password.textField.isSecureTextEntry = true
        place(password, in: host.view, top: 170, inset: 24)
        let phrase = InputTextView()
        place(phrase, in: host.view, top: 260, inset: 24)
        // In a list cell: none.
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 350, width: width, height: 100)
        host.view.addSubview(cell)
        let inCell = InputField()
        place(inCell, in: cell.contentView, top: 20, inset: 24)
        // In a container that clips at the edges of the field: none.
        let tight = box(at: 470, height: 60, inset: 24, clips: true)
        let inTight = InputField()
        place(inTight, in: tight, top: 0, inset: 0)
        // In a clipping container that leaves the glow its 12 pt: whole.
        let roomy = box(at: 550, height: 84, inset: 12, clips: true)
        let inRoomy = InputField()
        place(inRoomy, in: roomy, top: 12, inset: 12)
        // The swap cards reach the edges of their host view.
        let cards = InputAssetsView()
        place(cards, in: host.view, top: 650, inset: 16)
        host.view.layoutIfNeeded()

        for field in [name, password, inCell, inTight, inRoomy] {
            XCTAssertFalse(field.clipsToBounds, "a clipping field cuts its own glow")
            field.sora.state = .focused
        }
        phrase.sora.state = .focused
        XCTAssertFalse(cards.clipsToBounds)
        XCTAssertFalse(cards.firstAsset.clipsToBounds)
        cards.firstAsset.sora.state = .focused

        assertGlow(name, true, "on a screen")
        assertGlow(password, false, "a password never glows")
        assertGlow(phrase, false, "the phrase field never glows")
        assertGlow(inCell, false, "never in a list cell")
        assertGlow(inTight, false, "no room: border only")
        assertGlow(inRoomy, true, "12 pt of room")
        assertGlow(cards.firstAsset, true, "swap card")

        // The surroundings can change while a field is focused.
        tight.clipsToBounds = false
        inTight.setNeedsLayout()
        host.view.layoutIfNeeded()
        assertGlow(inTight, true, "the container stopped clipping")
        tight.clipsToBounds = true
        inTight.setNeedsLayout()
        host.view.layoutIfNeeded()
        assertGlow(inTight, false, "the container clips again")

        // A style update keeps each answer.
        setReduceEffects(true)
        settle()
        assertGlow(name, false, "MINIMAL tier")
        setReduceEffects(false)
        settle()
        assertGlow(name, true, "FULL tier again")
        assertGlow(password, false, "a password, after an effects update")
        assertGlow(phrase, false, "the phrase field, after an effects update")
        assertGlow(inCell, false, "in a cell, after an effects update")
        assertGlow(inTight, false, "no room, after an effects update")

        name.sora.state = .default
        XCTAssertEqual(name.subviews.first?.layer.shadowOpacity, 0)
        XCTAssertEqual(name.subviews.first?.layer.borderColor, tokens.borderInput.cgColor)
    }

    /// Links in the Welcome terms were red and told apart by colour only.
    @MainActor
    func testWelcomeTermsLinksAreCyanAndUnderlined() throws {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        let welcome = WelcomeViewController()
        for theme in [SoramitsuThemeType.dark, .light] {
            SoramitsuUI.shared.themeMode = .manual(theme)
            let tokens = NeonTokens.tokens(for: theme)
            welcome.decorate(label: welcome.termsLabel)
            let attributes = try XCTUnwrap(welcome.termsLabel.linkAttributes)
            XCTAssertEqual(attributes[.foregroundColor] as? UIColor, tokens.link)
            XCTAssertEqual(attributes[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(tokens.link, tokens.surface), 4.5)
            let text = try XCTUnwrap(welcome.termsLabel.attributedText)
            XCTAssertEqual(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, tokens.textSecondary)
        }
    }

    /// Sets the app's "Reduce effects" preference and waits until the
    /// change has reached every observer. Nothing is posted, and nothing is
    /// waited for, when the resulting tier is the same (with Reduce
    /// Transparency on it is MINIMAL either way).
    @MainActor
    private func setReduceEffects(_ value: Bool) {
        guard FxPolicy.reduceEffects != value else { return }
        let tier = FxPolicy.current.tier
        // The policy posts on the next main-queue turn, so the expectation
        // below is in place before the notification.
        FxPolicy.reduceEffects = value
        guard FxPolicy.current.tier != tier else { return }
        let changed = expectation(forNotification: .neonFxChanged, object: nil)
        wait(for: [changed], timeout: 2)
    }

    /// Back to "never set", whatever an earlier test or a killed run left.
    @MainActor
    private func resetReduceEffects() {
        setReduceEffects(false)
        UserDefaults.standard.removeObject(forKey: FxPolicy.reduceEffectsKey)
    }

    /// Skips only for system settings a test cannot change. The app's own
    /// preference is cleared in `setUp`; if it ever is not, this fails
    /// instead of skipping.
    @MainActor
    private func requireDefaultEffectTier() throws {
        let power = ProcessInfo.processInfo
        try XCTSkipIf(UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled
                        || power.isLowPowerModeEnabled || power.thermalState == .serious
                        || power.thermalState == .critical,
                      "needs the default system settings (no Reduce Transparency, Increase Contrast, Low Power Mode or thermal pressure)")
        XCTAssertNil(UserDefaults.standard.object(forKey: FxPolicy.reduceEffectsKey),
                     "the app's own Reduce effects preference is cleared before every test")
        XCTAssertEqual(FxPolicy.current.tier, .full)
        XCTAssertTrue(FxPolicy.current.glows)
    }

    /// Lets pending button configuration updates and layout run.
    @MainActor
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}

private final class NeonNodesPresenterStub: NodesPresenterProtocol {
    func setup() {}
}

private final class NeonStyleSpy: NSObject, SoramitsuObserver {
    private(set) var received: [UpdateOptions] = []
    func styleDidChange(options: UpdateOptions) { received.append(options) }
}

private final class RecoveryOnboardingVisualPresenter: OnboardingMainPresenterProtocol {
    func setup() {}
    func viewWillAppear() {}
    func activateSignup() {}
    func activateAccountRestore() {}
    func activateCloudStorageConnection() {}
}

private final class NeonPINVisualPresenter: PinSetupPresenterProtocol {
    weak var view: PincodeViewController?
    let count: Int
    var input = ""
    init(view: PincodeViewController, count: Int) { self.view = view; self.count = count }
    func start() { view?.updatePinCodeSymbolsCount(with: count); view?.didChangeAccessoryState(enabled: true) }
    func cancel() { }
    func activateBiometricAuth() { }
    func submit(pin: String) { }
    func deleteButtonTapped() {
        if !input.isEmpty { input.removeLast() }
        update()
    }
    func padButtonTapped(with symbol: String) {
        guard input.count < count else { return }
        input += symbol; update()
    }
    func updatePinButtonTapped() { }
    private func update() {
        view?.updateInputedCircles(with: input.count)
        view?.setupDeleteButton(isHidden: input.isEmpty)
    }
}

private final class NeonBackupVisualPresenter: AccountCreatePresenterProtocol {
    func setup() { }
    func activateInfo() { }
    func proceed() { }
    func share() { }
    func restoredApp() { }
    func skip() { }
    func backupToGoogle() { }
}

private final class NeonRawSeedVisualPresenter: AccountExportRawSeedPresenterProtocol {
    func exportRawSeed() { }
    func copyRawSeed() { }
    func exportJSON() { }
}

// Test-only data adapters. All layout, typography, controls, and QR generation are production code.
private final class StoreAssetPresentation: Produtable {
    var searchBarPlaceholder: String { R.string.localizable.assetListSearchPlaceholder(preferredLanguages: ["en"]) }
    var searchText = ""
    var mode: WalletViewMode = .view
    var isActiveSearch = false
    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: ((Bool) -> Void)?
    func viewDidLoad() {
        setupNavigationBar?(mode)
        let assets = [("XOR", "SORA", "0x0200000000000000000000000000000000000000000000000000000000000000"),
                      ("VAL", "SORA Validator Token", "0x0200040000000000000000000000000000000000000000000000000000000000"),
                      ("PSWAP", "Polkaswap", "0x0200050000000000000000000000000000000000000000000000000000000000")]
        setupItems?(assets.map { symbol, name, id in
            let info = AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: name, visible: true)
            var model = AssetViewModel(identifier: id, title: name, subtitle: "0 " + symbol,
                fiatText: "", icon: R.image.wallet.emptyToken(), mode: .view)
            model.priceLoadFinished = true
            return AssetListItem(assetInfo: info, assetViewModel: model, balance: 0)
        })
    }
}

private final class StoreReceivePresentation: GenerateQRViewModelProtocol {
    var setupSwicherView: ((SwitcherViewModel) -> Void)?
    var setupReceiveView: ((ReceiveQRViewModel) -> Void)?
    var setupRequestView: ((InputSendInfoViewModel) -> Void)?
    var updateContent: ((GenerateQRMode) -> Void)?
    var showShareContent: (([Any]) -> Void)?
    var closeHadler: (() -> Void)?
    let address: String
    let image: UIImage
    init(address: String, image: UIImage) { self.address = address; self.image = image }
    func viewDidLoad() {
        setupSwicherView?(SwitcherViewModel(buttonViewModels: [
            SwitcherButtonViewModel(title: "Receive", isSelected: true),
            SwitcherButtonViewModel(title: "Request", isSelected: false)]))
        setupReceiveView?(ReceiveQRViewModel(name: "Public demo wallet", address: address, qrImage: image))
        updateContent?(.receive)
    }
}

private final class StoreSwapPresentation: LiquidityViewModelProtocol {
    weak var view: PolkaswapViewController?
    var title: String? { nil }
    var imageName: String? { "Wallet/polkaswapLogo" }
    var firstFieldEmptyStateFullFiatText: String? { R.string.localizable.swapWantFrom(preferredLanguages: ["en"]) }
    var secondFieldEmptyStateFullFiatText: String? { R.string.localizable.swapWantTo(preferredLanguages: ["en"]) }
    var isSwap: Bool { true }
    var actionButtonImage: UIImage? { R.image.wallet.swapButton() }
    var inputedFirstAmount: Decimal = 0
    var inputedSecondAmount: Decimal = 0
    var middleButtonActionHandler: (() -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var focusedField: FocusedField = .one
    func viewDidLoad() {
        view?.update(slippageTolerance: PolkaswapSlippage.defaultValue.displayValue)
        view?.updateMiddleButton(isEnabled: false)
        view?.setupButton(isEnabled: false)
    }
    func choiсeBaseAssetButtonTapped() {}
    func choiсeTargetAssetButtonTapped() {}
    func changeSlippageTolerance() {}
    func reviewButtonTapped() {}
    func recalculate(field: FocusedField) {}
    func didSelect(variant: Decimal) {}
}

private final class StoreAssetDetailsPresentation: AssetDetailsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    func viewDidLoad() { setupItems?([]) }
}

private final class StoreAccessoryDelegate: InputAccessoryViewDelegate {
    var values: [Decimal] = []
    func didSelect(variant: Decimal) { values.append(variant) }
}

private final class StoreContactsPresentation: ContactsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var searches: [String] = []
    var qrRequests = 0
    func viewDidLoad() { setupItems?([]) }
    func search(_ pattern: String) { searches.append(pattern) }
    func openQR() { qrRequests += 1 }
}

private final class StoreAmountPresentation: InputAssetAmountViewModelProtocol {
    var inputedFirstAmount: Decimal = 0
    func viewDidLoad() {}
    func choiceBaseAssetButtonTapped() {}
    func reviewButtonTapped() {}
    func selectAddress() {}
    func didSelect(variant: Decimal) {}
}
