// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood

protocol FileRepositoryProtocol {
    func createDirectoryIfNeededOperation(at path: String) -> BaseOperation<Void>
    func fileExistsOperation(at path: String) -> BaseOperation<FileExistence>
    func readOperation(at path: String) -> BaseOperation<Data?>
    func writeOperation(dataClosure: @escaping () throws -> Data, at path: String) -> BaseOperation<Void>
    func copyOperation(from fromPath: String, to toPath: String) -> BaseOperation<Void>
    func removeOperation(at path: String) -> BaseOperation<Void>
}

enum FileExistence {
    case notExists
    case directory
    case file
}

/**
 *  Repository implements wrapper around shared file manager to enable operations
 *  usage for files management.
 *
 *  Note: It is important to use native shared file manager because it gives
 *  thread safety from the box.
 */

final class FileRepository: FileRepositoryProtocol {
    func createDirectoryIfNeededOperation(at path: String) -> BaseOperation<Void> {
        ClosureOperation {
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                || !isDirectory.boolValue {
                try FileManager.default
                    .createDirectory(atPath: path, withIntermediateDirectories: true)
            }
        }
    }

    func fileExistsOperation(at path: String) -> BaseOperation<FileExistence> {
        ClosureOperation {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

            if !exists {
                return .notExists
            } else {
                return isDirectory.boolValue ? .directory : .file
            }
        }
    }

    func readOperation(at path: String) -> BaseOperation<Data?> {
        ClosureOperation {
            FileManager.default.contents(atPath: path)
        }
    }

    func writeOperation(dataClosure: @escaping () throws -> Data, at path: String) -> BaseOperation<Void> {
        ClosureOperation {
            let data = try dataClosure()
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    func copyOperation(from fromPath: String, to toPath: String) -> BaseOperation<Void> {
        ClosureOperation {
            try FileManager.default.copyItem(atPath: fromPath, toPath: toPath)
        }
    }

    func removeOperation(at path: String) -> BaseOperation<Void> {
        ClosureOperation {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
    }
}
