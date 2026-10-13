/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

extension DocumentNodeProtocol {
    public func integer(for keyPath: [String]) -> Int? {
        if keyPath.count == 0 {
            return nil
        }

        if keyPath.count == 1 {
            return integer(for: keyPath[0])
        }

        return node(for: keyPath[0])?.integer(for: [String](keyPath[1...]))
    }

    public func string(for keyPath: [String]) -> String? {
        if keyPath.count == 0 {
            return nil
        }

        if keyPath.count == 1 {
            return string(for: keyPath[0])
        }

        return node(for: keyPath[0])?.string(for: [String](keyPath[1...]))
    }

    public func node(for keyPath: [String]) -> DocumentNodeProtocol? {
        if keyPath.count == 0 {
            return nil
        }

        if keyPath.count == 1 {
            return node(for: keyPath[0])
        }

        return node(for: keyPath[0])?.node(for: [String](keyPath[1...]))
    }

    public func list(for keyPath: [String]) -> [DocumentNodeProtocol]? {
        if keyPath.count == 0 {
            return nil
        }

        if keyPath.count == 1 {
            return list(for: keyPath[0])
        }

        return node(for: keyPath[0])?.list(for: [String](keyPath[1...]))
    }

    public func reference(for keyPath: [String]) -> DocumentReferenceProtocol? {
        if keyPath.count == 0 {
            return nil
        }

        if keyPath.count == 1 {
            return reference(for: keyPath[0])
        }

        return node(for: keyPath[0])?.reference(for: [String](keyPath[1...]))
    }
}
