//
//  StringArrayTransformer.swift
//  SoraPassport
//
//  Created by Nikolai Zhukov on 3/27/25.
//  Copyright © 2025 Soramitsu. All rights reserved.
//

import Foundation

final class StringArrayTransformer: ValueTransformer {

    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [String] else { return nil }
        do {
            return try JSONEncoder().encode(array)
        } catch {
            Logger.shared.error("Coding error: \(error)")
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            Logger.shared.error("Decoding error: \(error)")
            return nil
        }
    }
}
