/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto

extension ProjectUnitService: ProjectUnitFundingProtocol {
    func fetchAllProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                          completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.fetch.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchProjects(with: service.serviceEndpoint,
                                 pagination: pagination,
                                 runCompletionIn: queue,
                                 completionBlock: completionBlock)
    }

    func fetchFavoriteProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.favorites.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchProjects(with: service.serviceEndpoint,
                                 pagination: pagination,
                                 runCompletionIn: queue,
                                 completionBlock: completionBlock)
    }

    func fetchVotedProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                            completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.voted.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchProjects(with: service.serviceEndpoint,
                                 pagination: pagination,
                                 runCompletionIn: queue,
                                 completionBlock: completionBlock)
    }

    func fetchFinishedProjects(with pagination: OffsetPagination, runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.finished.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchProjects(with: service.serviceEndpoint,
                                 pagination: pagination,
                                 runCompletionIn: queue,
                                 completionBlock: completionBlock)
    }

    func fetchOpenReferendums(runCompletionIn queue: DispatchQueue,
                              completionBlock: @escaping NetworkReferendumCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.referendumsOpen.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchReferendums(with: service.serviceEndpoint,
                                    runCompletionIn: queue,
                                    completionBlock: completionBlock)
    }

    func fetchVotedReferendums(runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkReferendumCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.referendumsVoted.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchReferendums(with: service.serviceEndpoint,
                                    runCompletionIn: queue,
                                    completionBlock: completionBlock)
    }

    func fetchFinishedReferendums(runCompletionIn queue: DispatchQueue,
                                  completionBlock: @escaping NetworkReferendumCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.referendumsFinished.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        return try fetchReferendums(with: service.serviceEndpoint,
                                    runCompletionIn: queue,
                                    completionBlock: completionBlock)
    }

    func fetchProjectDetails(for projectId: String, runCompletionIn queue: DispatchQueue,
                             completionBlock: @escaping NetworkProjectDetailsCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.projectDetails.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchProjectDetailsOperation(service.serviceEndpoint,
                                                                      projectId: projectId)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchReferendumDetails(for referendumId: String,
                                runCompletionIn queue: DispatchQueue,
                                completionBlock: @escaping NetworkReferendumDetailsCompletionBlock) throws
        -> Operation {
        guard let service = unit.service(for: ProjectServiceType.referendumDetails.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchReferendumDetailsOperation(service.serviceEndpoint,
                                                                         referendumId: referendumId)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func toggleFavorite(projectId: String, runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.toggleFavorite.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.toggleFavoriteOperation(service.serviceEndpoint, projectId: projectId)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func vote(with customerVote: ProjectVote,
              runCompletionIn queue: DispatchQueue,
              completionBlock: @escaping NetworkBoolResultCompletionBlock) throws -> Operation {

        guard let service = unit.service(for: ProjectServiceType.vote.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.voteOperation(service.serviceEndpoint, vote: customerVote)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func vote(with customerVote: ReferendumVote,
              runCompletionIn queue: DispatchQueue,
              completionBlock: @escaping NetworkEmptyCompletionBlock) throws -> Operation {
        let type: ProjectServiceType

        switch customerVote.votingCase {
        case .support:
            type = .referendumSupportVote
        case .unsupport:
            type = .referendumUnsupportVote
        }

        guard let service = unit.service(for: type.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.voteInReferendumOperation(service.serviceEndpoint,
                                                                   vote: customerVote)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchVotes(runCompletionIn queue: DispatchQueue,
                    completionBlock: @escaping NetworkFetchVotesCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.votesCount.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchVotesOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchVotesHistory(with info: OffsetPagination,
                           runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkVotesHistoryCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.votesHistory.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchVotesHistory(service.serviceEndpoint, with: info)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchActivityFeed(with info: OffsetPagination,
                           runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkActivityFeedCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.activityFeed.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchActivityFeedOperation(service.serviceEndpoint,
                                                                    with: info)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    // MARK: Private

    private func fetchProjects(with serviceEndpoint: String, pagination: OffsetPagination,
                               runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping NetworkProjectCompletionBlock) throws -> Operation {
        let operation = operationFactory.fetchProjectsOperation(serviceEndpoint, pagination: pagination)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    private func fetchReferendums(with serviceEndpoint: String,
                                  runCompletionIn queue: DispatchQueue,
                                  completionBlock: @escaping NetworkReferendumCompletionBlock) throws
        -> Operation {
        let operation = operationFactory.fetchReferendumsOperation(serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }
}
