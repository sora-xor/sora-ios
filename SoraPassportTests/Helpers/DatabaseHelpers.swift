import Foundation
import RobinHood
import CoreData
import XCTest
@testable import SoraPassport

func clearDatabase(using service: CoreDataServiceProtocol) throws {
    try service.close()
    try service.drop()
}

func save<T: Identifiable>(models: [T],
                           to repository: AnyDataProviderRepository<T>,
                           operationQueue: OperationQueue,
                           expectationHandler: XCTestCase) throws {

    let expectation = XCTestExpectation()

    let saveOperation = repository.saveOperation({ models }, { [] })

    saveOperation.completionBlock = {
        expectation.fulfill()
    }

    operationQueue.addOperation(saveOperation)

    expectationHandler.wait(for: [expectation], timeout: Constants.expectationDuration)

    guard let result = saveOperation.result else {
        throw DataProviderError.dependencyCancelled
    }

    if case .failure(let error) = result {
        throw error
    }
}

func fetchAll<T: Identifiable>(from repository: AnyDataProviderRepository<T>,
                               operationQueue: OperationQueue,
                               expectationHandler: XCTestCase) throws -> [T] {
    let expectation = XCTestExpectation()

    let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

    fetchOperation.completionBlock = {
        expectation.fulfill()
    }

    operationQueue.addOperation(fetchOperation)

    expectationHandler.wait(for: [expectation], timeout: Constants.expectationDuration)

    guard let result = fetchOperation.result else {
        throw DataProviderError.dependencyCancelled
    }

    switch result {
    case .success(let models):
        return models
    case .failure(let error):
        throw error
    }
}
