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

/**
 *  Protocol is designed for fetching and saving files representing runtime
 *  types.
 */

protocol RuntimeFilesOperationFactoryProtocol {
    /**
     *  Constructs an operations wrapper that fetches data of
     *  common runtime types from corresponding file.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that fetches data of the
     *  runtime types from a file which matches concrete chain's id.
     *
     *  - Parameters:
     *      - chainId: Idetifier of a chain for which runtime types data
     *  must be fetched.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  runtime types to the corresponding file.
     *
     *  - Parameters:
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  chain's specific runtime types to the corresponding file.
     *
     *  - Parameters:
     *      - chainId: Identifier of the chain for which runtime types must be stored
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveChainTypesOperation(
        for chainId: ChainModel.Id,
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>
}

/**
 *  Class is designed to provide runtime types file management functions. Instance of the class
 *  contains instance of the `FileRepositoryProtocol` which performs file reading and
 *  writing and directory where files should be stored.
 *
 *  Common types file has `common-types` name. Chain type file hash $(chainId)-types name.
 */

final class RuntimeFilesOperationFactory {
    /// Engine that reads and writes files from filesystem
    let repository: FileRepositoryProtocol

    /// Path to the directory where files are stored
    let directoryPath: String

    /**
     *  Creates instance a new instance for runtime types management.
     *
     *  - Parameters:
     *      - repository: Engine that reads and writes files from filesystem;
     *      - directoryPath: Path to the directory where files are stored.
     */

    init(repository: FileRepositoryProtocol, directoryPath: String) {
        self.repository = repository
        self.directoryPath = directoryPath
    }

    private func fetchFileOperation(for fileName: String) -> CompoundOperationWrapper<Data?> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let readOperation = repository.readOperation(at: filePath)
        readOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(
            targetOperation: readOperation,
            dependencies: [createDirOperation]
        )
    }

    private func saveFileOperation(
        for fileName: String,
        data: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let writeOperation = repository.writeOperation(dataClosure: data, at: filePath)
        writeOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(
            targetOperation: writeOperation,
            dependencies: [createDirOperation]
        )
    }
}

extension RuntimeFilesOperationFactory: RuntimeFilesOperationFactoryProtocol {
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: "common-types")
    }

    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: "\(chainId)-types")
    }

    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        saveFileOperation(for: "common-types", data: closure)
    }

    func saveChainTypesOperation(
        for chainId: ChainModel.Id, data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        saveFileOperation(for: "\(chainId)-types", data: closure)
    }
}
