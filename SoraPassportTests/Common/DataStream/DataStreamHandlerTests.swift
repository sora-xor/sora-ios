import XCTest
@testable import SoraPassport
import Cuckoo

class DataStreamHandlerTests: XCTestCase {
    func testDataStreamSuccessfullyHandled() throws {
        let testData = try Data(contentsOf: Bundle(for: DataStreamHandlerTests.self)
            .url(forResource: "testStream", withExtension: "json")!)

        let jsonDecoder = JSONDecoder()
        let jsonEncoder = JSONEncoder()

        let items = try jsonDecoder.decode([DataStreamOneOfEvent].self, from: testData)

        for item in items {
            let itemData = try jsonEncoder.encode(item)

            let processor = MockDataStreamProcessing()

            let expectation = XCTestExpectation()

            stub(processor) { stub in
                when(stub).process(event: any()).then { event in
                    XCTAssertEqual(item, event)
                    expectation.fulfill()
                }
            }

            let handler = DataStreamHandler(streamProcessors: [processor])

            handler.didReceive(remoteEvent: itemData)

            wait(for: [expectation], timeout: Constants.networkRequestTimeout)
        }
    }
}
