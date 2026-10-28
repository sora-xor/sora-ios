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

/// The asset whitelist decides which on-chain assets the wallet lists and gives them their
/// vetted name, symbol and icon. Anyone can register an asset on SORA with any name and
/// symbol, so an unlisted asset is never shown (fail closed), as in App Store 3.8.6.
struct AssetWhitelist {
    enum Source: Equatable {
        /// `https://whitelist.polkaswap2.io/whitelist.json`, fetched in this session.
        case remote
        /// The last remote list that decoded, saved on this device.
        case lastKnownGood
        /// `whitelist.json` in the app bundle. It can be older than the live list, so it
        /// also admits the protocol's predefined assets (see `isPredefinedAsset`).
        case bundled
        /// Nothing usable could be read. Only predefined assets are listed.
        case none
    }

    let source: Source
    private let entries: [String: Whitelist]

    init(entries: [Whitelist], source: Source) {
        var byId: [String: Whitelist] = [:]
        for entry in entries {
            byId[entry.assetId.lowercased()] = entry
        }
        self.entries = byId
        self.source = source
    }

    static let empty = AssetWhitelist(entries: [], source: .none)

    var count: Int { entries.count }

    func entry(for assetId: String) -> Whitelist? {
        entries[assetId.lowercased()]
    }

    /// Whether the wallet lists this asset. An asset in the list always is. The stale
    /// bundled list (and an unreadable one) also admits predefined assets, so a first launch
    /// without the network still shows XST, TBCD and KUSD; their ids are fixed by the
    /// runtime and cannot be registered by anyone, so their on-chain names are genuine.
    func admits(assetId: String) -> Bool {
        if entry(for: assetId) != nil {
            return true
        }
        switch source {
        case .remote, .lastKnownGood:
            return false
        case .bundled, .none:
            return Self.isPredefinedAsset(assetId)
        }
    }

    /// `0x02`, a 16-bit code, then 29 zero bytes: `PredefinedAssetId` in the SORA runtime
    /// (XOR 0x020000…, VAL 0x020004…, XST 0x020009…, KUSD 0x02000c…). Assets registered
    /// by accounts get hash-derived ids that start with 0x00.
    static func isPredefinedAsset(_ assetId: String) -> Bool {
        let hex = assetId.lowercased()
        guard hex.count == 66, hex.hasPrefix("0x02") else {
            return false
        }
        let code = hex.dropFirst(4).prefix(4)
        let rest = hex.dropFirst(8)
        return code.allSatisfy(\.isHexDigit) && rest.allSatisfy { $0 == "0" }
    }

    /// Decodes a whitelist file. Entries that do not decode are skipped; the list is
    /// accepted only if it is non-empty and contains XOR, so an empty or truncated response
    /// never hides the whole wallet.
    static func decode(_ data: Data, source: Source) -> AssetWhitelist? {
        guard let items = try? JSONDecoder().decode([LossyEntry].self, from: data) else {
            return nil
        }
        let entries = items.compactMap(\.value).filter { isAssetId($0.assetId) }
        let whitelist = AssetWhitelist(entries: entries, source: source)
        guard whitelist.entry(for: WalletAssetId.xor.rawValue) != nil else {
            return nil
        }
        return whitelist
    }

    private static func isAssetId(_ value: String) -> Bool {
        value.count == 66 && value.lowercased().hasPrefix("0x") && value.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    private struct LossyEntry: Decodable {
        let value: Whitelist?

        init(from decoder: Decoder) throws {
            value = try? Whitelist(from: decoder)
        }
    }
}

protocol AssetWhitelistStoring: AnyObject {
    /// The list to use when no fresh remote list is at hand: the last good remote list,
    /// else the bundled one.
    func current() -> AssetWhitelist
    /// Validates a downloaded list and, if it is usable, saves it as the last good list.
    func acceptRemote(_ data: Data) -> AssetWhitelist?
}

/// Keeps the last remote whitelist that decoded, in Application Support.
final class AssetWhitelistStore: AssetWhitelistStoring {
    static let shared = AssetWhitelistStore(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AssetWhitelist", isDirectory: true),
        bundledURL: R.file.whitelistJson()
    )

    private let fileURL: URL
    private let bundledURL: URL?
    private let fileManager: FileManager
    private let logger: LoggerProtocol?
    private let lock = NSLock()

    init(
        directory: URL,
        bundledURL: URL?,
        fileManager: FileManager = .default,
        logger: LoggerProtocol? = Logger.shared
    ) {
        fileURL = directory.appendingPathComponent("whitelist.json")
        self.bundledURL = bundledURL
        self.fileManager = fileManager
        self.logger = logger
    }

    func current() -> AssetWhitelist {
        lock.lock()
        defer { lock.unlock() }
        if let data = try? Data(contentsOf: fileURL),
           let saved = AssetWhitelist.decode(data, source: .lastKnownGood) {
            return saved
        }
        if let bundledURL,
           let data = try? Data(contentsOf: bundledURL),
           let bundled = AssetWhitelist.decode(data, source: .bundled) {
            return bundled
        }
        logger?.warning("Asset whitelist: no usable list; only predefined assets are listed")
        return .empty
    }

    func acceptRemote(_ data: Data) -> AssetWhitelist? {
        guard let whitelist = AssetWhitelist.decode(data, source: .remote) else {
            logger?.warning("Asset whitelist: the downloaded list was not usable; keeping the last good list")
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        if (try? Data(contentsOf: fileURL)) != data {
            do {
                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                // Public data; readable after the first unlock so a background launch can
                // still use it.
                try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch {
                logger?.warning("Asset whitelist: could not save the downloaded list")
            }
        }
        return whitelist
    }
}
