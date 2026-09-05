import XCTest

@testable import SSFIndexers

final class IndexersRepositoryAssemblyDefaultTest: XCTestCase {
    func testRepositoryAssembly() throws {
        let _ = try IndexersRepositoryAssemblyDefault().createRepository()
    }
}
