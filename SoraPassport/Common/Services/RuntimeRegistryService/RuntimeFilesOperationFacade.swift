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

protocol RuntimeFilesOperationFacadeProtocol {
    func fetchDefaultOperation(for chain: Chain) -> CompoundOperationWrapper<Data?>
    func fetchNetworkOperation(for chain: Chain) -> CompoundOperationWrapper<Data?>

    func saveDefaultOperation(for chain: Chain,
                              data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>

    func saveNetworkOperation(for chain: Chain,
                              data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>
}

enum RuntimeFilesOperationFacadeError: Error {
    case missingBundleFile
}

final class RuntimeFilesOperationFacade {
    let repository: FileRepositoryProtocol
    let directoryPath: String

    init(repository: FileRepositoryProtocol, directoryPath: String) {
        self.repository = repository
        self.directoryPath = directoryPath
    }

    private func fetchFileOperation(for localPath: String) -> CompoundOperationWrapper<Data?> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let fileName = (localPath as NSString).lastPathComponent
        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let fileExistsOperation = repository.fileExistsOperation(at: filePath)
        fileExistsOperation.addDependency(createDirOperation)

        let copyOperation = repository.copyOperation(from: localPath, to: filePath)
        copyOperation.configurationBlock = {
            do {
                let exists = try fileExistsOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                if exists == .file {
                    copyOperation.result = .success(())
                }

            } catch {
                copyOperation.result = .failure(error)
            }
        }

        copyOperation.addDependency(fileExistsOperation)

        let readOperation = repository.readOperation(at: filePath)
        readOperation.configurationBlock = {
            do {
                try copyOperation.extractResultData()
            } catch {
                readOperation.result = .failure(error)
            }
        }
        readOperation.addDependency(copyOperation)

        let dependencies = [createDirOperation, fileExistsOperation, copyOperation]

        return CompoundOperationWrapper(targetOperation: readOperation,
                                        dependencies: dependencies)

    }

    private func saveFileOperation(for localPath: String,
                                   data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let fileName = (localPath as NSString).lastPathComponent
        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let writeOperation = repository.writeOperation(dataClosure: data, at: filePath)
        writeOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(targetOperation: writeOperation,
                                        dependencies: [createDirOperation])
    }
}

extension RuntimeFilesOperationFacade: RuntimeFilesOperationFacadeProtocol {
    func fetchDefaultOperation(for chain: Chain) -> CompoundOperationWrapper<Data?> {
        guard let localFilePath = chain.preparedDefaultTypeDefPath() else {
            return CompoundOperationWrapper
                .createWithError(RuntimeRegistryServiceError.unexpectedCoderFetchingFailure)
        }

        return fetchFileOperation(for: localFilePath)
    }

    func fetchNetworkOperation(for chain: Chain) -> CompoundOperationWrapper<Data?> {
        guard let localFilePath = chain.preparedNetworkTypeDefPath() else {
            return CompoundOperationWrapper
                .createWithError(RuntimeRegistryServiceError.unexpectedCoderFetchingFailure)
        }

        return fetchFileOperation(for: localFilePath)
    }

    func saveDefaultOperation(for chain: Chain,
                              data closure: @escaping () throws -> Data)
    -> CompoundOperationWrapper<Void> {
        guard let localFilePath = chain.preparedDefaultTypeDefPath() else {
            return CompoundOperationWrapper
                .createWithError(RuntimeRegistryServiceError.unexpectedCoderFetchingFailure)
        }

        return saveFileOperation(for: localFilePath, data: closure)
    }

    func saveNetworkOperation(for chain: Chain,
                              data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        guard let localFilePath = chain.preparedNetworkTypeDefPath() else {
            return CompoundOperationWrapper
                .createWithError(RuntimeRegistryServiceError.unexpectedCoderFetchingFailure)
        }

        return saveFileOperation(for: localFilePath, data: closure)
    }
}
