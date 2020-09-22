import XCTest
@testable import SoraPassport
import RobinHood

class ProjectDataMapperTests: XCTestCase {
    func testMapperForwardBackward() {
        let project = createRandomProject()

        let facade = CoreDataCacheTestFacade()
        let mapper = ProjectDataMapper(domain: UUID().uuidString)

        let filter = NSPredicate(format: "%K == %@", #keyPath(CDProject.domain), mapper.domain)
        let repository = facade.createCoreDataCache(filter: filter,
                                                    mapper: AnyCoreDataMapper(mapper))
        let operationQueue = OperationQueue()

        do {
            try save(models: [project],
                     to: AnyDataProviderRepository(repository),
                     operationQueue: operationQueue,
                     expectationHandler: self)

            let resultProjects = try fetchAll(from: AnyDataProviderRepository(repository),
                                              operationQueue: operationQueue,
                                              expectationHandler: self)

            XCTAssertEqual([project], resultProjects)
        } catch {
            XCTFail("Unexpected message \(error)")
        }
    }
}
