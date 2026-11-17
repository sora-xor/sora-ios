// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The official Polkaswap token blacklist, `https://whitelist.polkaswap2.io/blacklist.json`: the
/// ids of assets Polkaswap has withdrawn (scam copies, compromised tokens). The wallet does not
/// list them in the portfolio, the asset lists or the swap pickers.
///
/// It is applied where lists are shown, never to the chain store, so the balance of a
/// blacklisted asset is still read. A wallet that holds one keeps it in its full asset list,
/// marked hidden, where it can be opened and sent away: funds never silently disappear.
struct AssetBlacklist: Equatable {
    enum Source: Equatable {
        /// The remote list, fetched in this session.
        case remote
        /// The last remote list that decoded, saved on this device.
        case lastKnownGood
        /// `blacklist.json` in the app bundle.
        case bundled
        /// No list could be read: nothing is hidden.
        case none
    }

    let source: Source
    /// Lower-case asset ids.
    let assetIds: Set<String>

    init(assetIds: [String], source: Source) {
        self.assetIds = Set(assetIds.map { $0.lowercased() })
        self.source = source
    }

    static let empty = AssetBlacklist(assetIds: [], source: .none)

    var count: Int { assetIds.count }

    /// Whether lists leave this asset out. XOR is never hidden: it pays every fee, and the
    /// wallet cannot work without it.
    func hides(assetId: String) -> Bool {
        let id = assetId.lowercased()
        return id != Self.xorId && assetIds.contains(id)
    }

    /// The ids a picker offers: the same ids, in the same order, without blacklisted ones.
    func pickable(_ ids: [String]) -> [String] {
        ids.filter { !hides(assetId: $0) }
    }

    /// Whether the full asset list keeps the row of this asset. A blacklisted asset keeps it
    /// while the wallet holds some, or while its balance could not be read (it may be held);
    /// with a known zero balance it is not listed.
    func keepsRow(assetId: String, balance: Decimal, balanceUnavailable: Bool) -> Bool {
        !hides(assetId: assetId) || balanceUnavailable || balance > 0
    }

    /// The note on the row of a blacklisted asset the wallet holds.
    static var hiddenNote: String { WalletUX.text("Hidden by the Polkaswap blacklist") }

    /// Decodes a blacklist file: a JSON array of asset id strings, as the live list is.
    ///
    /// Anything else is not accepted, so the last good (or bundled) list stays in force: a
    /// response that is not JSON, not an array, or has an element that is not a string (an
    /// unknown format; the whitelist's objects among them), or a non-empty array without a
    /// single asset id. An undecodable answer never means "nothing is blacklisted". Strings
    /// that are not asset ids are skipped: they can never match an asset. An empty array is
    /// the list's own statement that nothing is blacklisted, and is accepted.
    static func decode(_ data: Data, source: Source) -> AssetBlacklist? {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
            return nil
        }
        var ids: [String] = []
        for item in items {
            guard let text = item as? String else {
                return nil
            }
            let id = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if isAssetId(id) {
                ids.append(id)
            }
        }
        guard items.isEmpty || !ids.isEmpty else {
            return nil
        }
        return AssetBlacklist(assetIds: ids, source: source)
    }

    private static let xorId = WalletAssetId.xor.rawValue.lowercased()

    private static func isAssetId(_ value: String) -> Bool {
        value.count == 66 && value.hasPrefix("0x") && value.dropFirst(2).allSatisfy(\.isHexDigit)
    }
}

protocol AssetBlacklistStoring: AnyObject {
    /// The list in force: the one fetched in this session, else the last good remote list,
    /// else the bundled one.
    func current() -> AssetBlacklist
    /// Validates a downloaded list and, if it is usable, saves it as the last good list.
    func acceptRemote(_ data: Data) -> AssetBlacklist?
}

/// Keeps the last remote blacklist that decoded, in Application Support, like the whitelist.
final class AssetBlacklistStore: AssetBlacklistStoring {
    /// Posted (by the store) when an accepted remote list hides other assets than before.
    static let didChange = Notification.Name("AssetBlacklistStore.didChange")

    static let shared = AssetBlacklistStore(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AssetBlacklist", isDirectory: true),
        bundledURL: R.file.blacklistJson()
    )

    private let fileURL: URL
    private let bundledURL: URL?
    private let fileManager: FileManager
    private let notificationCenter: NotificationCenter
    private let logger: LoggerProtocol?
    private let lock = NSLock()
    /// Lists ask on every rebuild, some for every row, so the answer is kept.
    private var cached: AssetBlacklist?

    init(
        directory: URL,
        bundledURL: URL?,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default,
        logger: LoggerProtocol? = Logger.shared
    ) {
        fileURL = directory.appendingPathComponent("blacklist.json")
        self.bundledURL = bundledURL
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        self.logger = logger
    }

    func current() -> AssetBlacklist {
        lock.lock()
        defer { lock.unlock() }
        if let cached {
            return cached
        }
        let (blacklist, isSettled) = readSaved()
        if isSettled {
            cached = blacklist
        }
        return blacklist
    }

    /// The saved list, else the bundled one. Not settled when the saved file exists but cannot
    /// be read yet (before the first unlock): it is read again next time.
    private func readSaved() -> (AssetBlacklist, isSettled: Bool) {
        var isSettled = true
        if let data = try? Data(contentsOf: fileURL) {
            if let saved = AssetBlacklist.decode(data, source: .lastKnownGood) {
                return (saved, true)
            }
        } else if fileManager.fileExists(atPath: fileURL.path) {
            isSettled = false
        }
        if let bundledURL,
           let data = try? Data(contentsOf: bundledURL),
           let bundled = AssetBlacklist.decode(data, source: .bundled) {
            return (bundled, isSettled)
        }
        logger?.warning("Asset blacklist: no usable list; nothing is hidden")
        return (.empty, isSettled)
    }

    func acceptRemote(_ data: Data) -> AssetBlacklist? {
        guard let blacklist = AssetBlacklist.decode(data, source: .remote) else {
            logger?.warning("Asset blacklist: the downloaded list was not usable; keeping the last good list")
            return nil
        }
        lock.lock()
        let previous = cached ?? readSaved().0
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
                logger?.warning("Asset blacklist: could not save the downloaded list")
            }
        }
        cached = blacklist
        lock.unlock()
        if previous.assetIds != blacklist.assetIds {
            notificationCenter.post(name: Self.didChange, object: self)
        }
        return blacklist
    }
}
