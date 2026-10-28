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
