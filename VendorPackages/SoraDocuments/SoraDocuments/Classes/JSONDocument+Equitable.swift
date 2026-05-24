/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

extension JSONDocumentNode: Equatable {
    public static func == (lhs: JSONDocumentNode, rhs: JSONDocumentNode) -> Bool {
        let lhsKeys = lhs.allKeys()
        let rhsKeys = rhs.allKeys()

        if lhsKeys != rhsKeys {
            return false
        }

        for key in lhsKeys {
            if !compareIntegerValues(for: key, lhs: lhs, rhs: rhs) {
                return false
            }

            if !compareStringValues(for: key, lhs: lhs, rhs: rhs) {
                return false
            }

            if !compareReferences(for: key, lhs: lhs, rhs: rhs) {
                return false
            }

            if !compareLists(for: key, lhs: lhs, rhs: rhs) {
                return false
            }

            if !compareNodes(for: key, lhs: lhs, rhs: rhs) {
                return false
            }
        }

        return true
    }

    private static func compareIntegerValues(for key: String, lhs: JSONDocumentNode, rhs: JSONDocumentNode) -> Bool {
        return lhs.integer(for: key) == rhs.integer(for: key)
    }

    private static func compareStringValues(for key: String, lhs: JSONDocumentNode, rhs: JSONDocumentNode) -> Bool {
        return lhs.string(for: key) == rhs.string(for: key)
    }

    private static func compareReferences(for key: String, lhs: JSONDocumentNode, rhs: JSONDocumentNode) -> Bool {
        let optLhsRef = lhs.reference(for: key)
        let optRhsRef = rhs.reference(for: key)

        if let lhsRef = optLhsRef, let rhsRef = optRhsRef {
            return lhsRef.referenceName == rhsRef.referenceName
        } else {
            return optLhsRef == nil && optRhsRef == nil
        }
    }

    private static func compareLists(for key: String, lhs: JSONDocumentNode, rhs: JSONDocumentNode) -> Bool {
        let optLhsList = lhs.list(for: key) as? [JSONDocumentNode]
        let optRhsList = rhs.list(for: key) as? [JSONDocumentNode]

        return optLhsList == optRhsList
    }

    private static func compareNodes(for key: String, lhs: JSONDocumentNode, rhs: JSONDocumentNode) -> Bool {
        let optLhsNode = lhs.node(for: key) as? JSONDocumentNode
        let optRhsNode = rhs.node(for: key) as? JSONDocumentNode

        return optLhsNode == optRhsNode
    }
}
