// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import XCTest
@testable import SoraPassport

/// One wallet, networks as labels: names, tags and order come from one
/// directory, and one constant makes SORA Nexus the main network once it is
/// live (`MainNetworkPolicy.preferred`).
final class WalletNetworkDirectoryTests: XCTestCase {
    /// This build: SORA2 and Taira are live, SORA Nexus production is not yet.
    private let today = WalletNetworkDirectory.current
    /// After SORA Nexus production launches.
    private let nexusLive = WalletNetworkDirectory(isLive: { _ in true })
    private let mnemonicWallet: Set<NetworkId> = [.sora2, .minamoto, .taira]

    private func account(_ networkId: NetworkId) -> NetworkAccount {
        NetworkAccount(walletId: "wallet", networkId: networkId, derivationVersion: 1,
                       publicKey: Data(repeating: 1, count: 32), address: "address-\(networkId.rawValue)")
    }

    func testSora2IsTheMainNetworkToday() {
        XCTAssertEqual(MainNetworkPolicy.preferred, .sora2)
        XCTAssertEqual(today.mainNetwork(walletNetworks: mnemonicWallet), .sora2)
        XCTAssertFalse(today.info(.minamoto).isLive)
        XCTAssertTrue(today.info(.taira).isLive)
    }

    func testSoraNexusBecomesMainOnlyOnceItIsLive() {
        // Flipping the constant early cannot move users to a network that
        // is not live in this build.
        XCTAssertEqual(today.mainNetwork(walletNetworks: mnemonicWallet, preferred: .minamoto), .sora2)
        XCTAssertEqual(nexusLive.mainNetwork(walletNetworks: mnemonicWallet, preferred: .minamoto), .minamoto)
    }

    func testMainNetworkFallsBackToSora2() {
        // A testnet is never the main network.
        XCTAssertEqual(nexusLive.mainNetwork(walletNetworks: mnemonicWallet, preferred: .taira), .sora2)
        // A raw-seed wallet has no SORA Nexus account.
        XCTAssertEqual(nexusLive.mainNetwork(walletNetworks: [.sora2], preferred: .minamoto), .sora2)
    }

    func testOrderPutsTheMainNetworkFirstAndTestnetsLast() {
        let networks: [NetworkId] = [.taira, .minamoto, .sora2, .taira]
        XCTAssertEqual(today.ordered(networks, main: .sora2), [.sora2, .minamoto, .taira])
        XCTAssertEqual(nexusLive.ordered(networks, main: .minamoto), [.minamoto, .sora2, .taira])
    }

    func testTagsAndRowLabels() {
        XCTAssertEqual(today.tag(for: .sora2, main: .sora2), .main)
        XCTAssertEqual(today.tag(for: .minamoto, main: .sora2), .comingSoon)
        XCTAssertEqual(today.tag(for: .taira, main: .sora2), .testnet)
        XCTAssertNil(today.rowLabel(for: .sora2, main: .sora2))
        XCTAssertEqual(today.rowLabel(for: .taira, main: .sora2), "Taira")
        XCTAssertEqual(today.rowLabel(for: .minamoto, main: .sora2), "SORA Nexus")

        // With SORA Nexus as the main network, SORA2 rows carry their label.
        XCTAssertEqual(nexusLive.tag(for: .minamoto, main: .minamoto), .main)
        XCTAssertNil(nexusLive.tag(for: .sora2, main: .minamoto))
        XCTAssertNil(nexusLive.rowLabel(for: .minamoto, main: .minamoto))
        XCTAssertEqual(nexusLive.rowLabel(for: .sora2, main: .minamoto), "SORA2")
    }

    func testReceiveOffersEveryAddressMainFirst() {
        let choices = WalletNetworkChoices.make(
            action: .receive,
            accounts: [account(.taira), account(.minamoto), account(.sora2)],
            balances: [.sora2: "120.5", .taira: "50"],
            canSend: { _ in false },
            directory: today
        )
        XCTAssertEqual(choices.map(\.network.id), [.sora2, .minamoto, .taira])
        XCTAssertEqual(choices.map(\.tag), [.main, .comingSoon, .testnet])
        XCTAssertTrue(choices.allSatisfy(\.isAvailable))
        XCTAssertEqual(choices.first?.balance, "120.5")
        // SORA2 and Taira are both live: the wallet asks.
        XCTAssertNil(WalletNetworkChoices.onlyChoice(choices))
    }

    func testReceiveGoesStraightToTheOnlyLiveNetwork() {
        // Taira switched off: SORA Nexus keeps its home row, Receive opens SORA2.
        let choices = WalletNetworkChoices.make(
            action: .receive,
            accounts: [account(.sora2), account(.minamoto)],
            balances: [:],
            canSend: { _ in true },
            directory: today
        )
        XCTAssertEqual(WalletNetworkChoices.onlyChoice(choices)?.network.id, .sora2)
    }

    func testSendSaysWhyANetworkCannotBeUsed() {
        let paused = WalletNetworkChoices.make(
            action: .send,
            accounts: [account(.sora2), account(.minamoto), account(.taira)],
            balances: [:],
            canSend: { $0 == .sora2 },
            directory: today
        )
        XCTAssertEqual(paused.map(\.isAvailable), [true, false, false])
        XCTAssertNotNil(paused[1].unavailableReason)
        XCTAssertNotNil(paused[2].unavailableReason)
        XCTAssertEqual(WalletNetworkChoices.onlyChoice(paused)?.network.id, .sora2)

        let open = WalletNetworkChoices.make(
            action: .send,
            accounts: [account(.sora2), account(.minamoto), account(.taira)],
            balances: [:],
            canSend: { _ in true },
            directory: today
        )
        XCTAssertEqual(open.map(\.isAvailable), [true, false, true])
        XCTAssertNil(WalletNetworkChoices.onlyChoice(open))
    }

    func testSoraNexusLeadsTheChoicesOnceItIsMain() {
        let choices = WalletNetworkChoices.make(
            action: .send,
            accounts: [account(.sora2), account(.minamoto), account(.taira)],
            balances: [:],
            canSend: { _ in true },
            directory: nexusLive,
            preferred: .minamoto
        )
        XCTAssertEqual(choices.map(\.network.id), [.minamoto, .sora2, .taira])
        XCTAssertEqual(choices.map(\.tag), [.main, nil, .testnet])
        XCTAssertTrue(choices.allSatisfy(\.isAvailable))
    }
}
