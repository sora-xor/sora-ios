// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// A chart colour. Colour follows the entity, never its rank.
enum PortfolioSlot: Hashable {
    case slot(Int)
    case other
}

/// One group of the allocation fan and its legend chip.
struct PortfolioFanSegment: Equatable {
    /// The group key, or `PortfolioAllocation.otherKey`.
    let key: String
    let slot: PortfolioSlot
    /// Rays out of `PortfolioAllocation.rayCount`; the segments always add up to it.
    let rays: Int
    let value: Decimal
    /// Share of the counted total, 0...1.
    let share: Decimal
    /// Keys folded into Other (empty for an ordinary segment).
    let members: [String]

    var isOther: Bool { slot == .other }
}

enum PortfolioAllocation {
    static let rayCount = 100
    static let slotCount = 5
    static let otherKey = "portfolio.other"

    /// Token lens seed, so a first launch looks the same on every device.
    static let tokenSeed: [String: Int] = [
        "0x0200000000000000000000000000000000000000000000000000000000000000": 0, // XOR
        "0x0200040000000000000000000000000000000000000000000000000000000000": 1, // VAL
        "0x0200050000000000000000000000000000000000000000000000000000000000": 2, // PSWAP
        "0x0200080000000000000000000000000000000000000000000000000000000000": 3, // XSTUSD
        "0x0200070000000000000000000000000000000000000000000000000000000000": 4  // ETH
    ]

    static let networkSeed: [String: Int] = [
        PortfolioNetwork.sora2.rawValue: 0,
        PortfolioNetwork.minamoto.rawValue: 1
    ]

    static func seed(for lens: PortfolioLens) -> [String: Int] {
        switch lens {
        case .tokens: return tokenSeed
        case .networks: return networkSeed
        case .wallets: return [:]
        }
    }

    /// Largest-remainder apportionment of `total` units over non-negative values.
    /// The result always adds up to `total` unless every value is zero.
    static func apportion(_ values: [Decimal], total: Int = rayCount) -> [Int] {
        let clean = values.map { max($0, 0) }
        let sum = clean.reduce(Decimal(0), +)
        guard sum > 0, total > 0 else { return clean.map { _ in 0 } }

        var floors: [Int] = []
        var fractions: [(index: Int, fraction: Decimal)] = []
        for (index, value) in clean.enumerated() {
            let quota = value * Decimal(total) / sum
            let floor = rounded(quota, mode: .down)
            floors.append(NSDecimalNumber(decimal: floor).intValue)
            fractions.append((index, quota - floor))
        }

        var left = total - floors.reduce(0, +)
        let order = fractions.sorted { lhs, rhs in
            if lhs.fraction != rhs.fraction { return lhs.fraction > rhs.fraction }
            if clean[lhs.index] != clean[rhs.index] { return clean[lhs.index] > clean[rhs.index] }
            return lhs.index < rhs.index
        }
        for item in order where left > 0 {
            floors[item.index] += 1
            left -= 1
        }
        return floors
    }

    /// Keeps each top entity's slot while it stays in the top five. A newcomer takes a free slot,
    /// preferring one nobody has held; entities outside the top keep their slot reserved until a
    /// newcomer needs it, so colours stay put as long as possible. Returns the updated map.
    static func assignSlots(topKeys: [String], previous: [String: Int]) -> [String: Int] {
        let top = Array(topKeys.prefix(slotCount))
        let topSet = Set(top)
        var assigned: [String: Int] = [:]
        var used = Set<Int>()
        for key in top {
            if let slot = previous[key], (0..<slotCount).contains(slot), !used.contains(slot) {
                assigned[key] = slot
                used.insert(slot)
            }
        }

        var reserved: [Int: String] = [:]
        for (key, slot) in previous.sorted(by: { $0.key < $1.key })
        where !topSet.contains(key) && (0..<slotCount).contains(slot) && !used.contains(slot) && reserved[slot] == nil {
            reserved[slot] = key
        }

        for key in top where assigned[key] == nil {
            let free = (0..<slotCount).filter { !used.contains($0) }
            guard let slot = free.first(where: { reserved[$0] == nil }) ?? free.first else { continue }
            reserved[slot] = nil
            assigned[key] = slot
            used.insert(slot)
        }

        for (slot, key) in reserved { assigned[key] = slot }
        return assigned
    }

    /// The fan for groups sorted largest first. At most five groups keep a slot; the rest fold
    /// into Other, which is always the last segment.
    static func fan(values: [(key: String, value: Decimal)], previousSlots: [String: Int])
        -> (segments: [PortfolioFanSegment], slots: [String: Int]) {
        let counted = values.filter { $0.value > 0 }
        guard !counted.isEmpty else { return ([], previousSlots) }

        let head = Array(counted.prefix(slotCount))
        let tail = Array(counted.dropFirst(slotCount))
        let slots = assignSlots(topKeys: head.map(\.key), previous: previousSlots)

        var entries: [(key: String, value: Decimal, slot: PortfolioSlot, members: [String])] = head.map {
            ($0.key, $0.value, slots[$0.key].map { PortfolioSlot.slot($0) } ?? .other, [])
        }
        if !tail.isEmpty {
            entries.append((otherKey, tail.reduce(Decimal(0)) { $0 + $1.value }, .other, tail.map(\.key)))
        }

        let total = entries.reduce(Decimal(0)) { $0 + $1.value }
        let rays = apportion(entries.map(\.value))
        let segments = entries.enumerated().map { index, entry in
            PortfolioFanSegment(key: entry.key, slot: entry.slot, rays: rays[index], value: entry.value,
                                share: total > 0 ? entry.value / total : 0, members: entry.members)
        }
        return (segments, slots)
    }

    /// Legend text for a share: whole percent, "<1" for a sliver.
    static func percentText(rays: Int, share: Decimal) -> String {
        if rays == 0 && share > 0 { return "<1%" }
        return "\(rays)%"
    }

    static func rounded(_ value: Decimal, scale: Int = 0, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, mode)
        return output
    }
}
