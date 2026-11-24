import XCTest
import SoraKeystore
@testable import SoraPassport
import SoraFoundation
import SSFUtils

final class InvitationObserverLifecycleTests: XCTestCase {
    private final class Observer: InvitationLinkObserver {
        var oldCodes: [String?] = []
        var onUpdate: (() -> Void)?
        func didUpdateInvitationLink(from oldLink: InvitationDeepLink?) {
            oldCodes.append(oldLink?.code)
            onUpdate?()
        }
    }

    private func service() -> InvitationLinkService { InvitationLinkService(settings: InMemorySettingsManager()) }

    func testRemovingOneObserverLeavesTheOtherSubscribed() {
        let service = service(); let first = Observer(); let second = Observer()
        service.add(observer: first); service.add(observer: second)
        service.remove(observer: first)
        service.save(code: "Abc123")
        XCTAssertTrue(first.oldCodes.isEmpty)
        XCTAssertEqual(second.oldCodes.count, 1)
    }

    func testRemovingAnUnregisteredObserverDoesNotUnsubscribeAnyone() {
        let service = service(); let observer = Observer()
        service.add(observer: observer)
        service.remove(observer: Observer())
        service.save(code: "Abc123")
        XCTAssertEqual(observer.oldCodes.count, 1)
    }

    func testDuplicateRegistrationIsIgnoredAndObserversAreWeak() {
        let service = service(); let observer = Observer()
        service.add(observer: observer); service.add(observer: observer)
        weak var released: Observer?
        autoreleasepool { let transient = Observer(); released = transient; service.add(observer: transient) }
        XCTAssertNil(released)
        service.save(code: "Abc123")
        XCTAssertEqual(observer.oldCodes.count, 1)
    }

    func testAnObserverCanRemoveItselfDuringNotification() {
        let service = service(); let first = Observer(); let second = Observer()
        first.onUpdate = { [weak first] in if let first { service.remove(observer: first) } }
        service.add(observer: first); service.add(observer: second)
        service.save(code: "first"); service.save(code: "second")
        XCTAssertEqual(first.oldCodes.count, 1)
        XCTAssertEqual(second.oldCodes, [nil, "first"])
    }

    func testUpdatesCarryThePreviousLinkAndClearResetsThatHistory() {
        let service = service(); let observer = Observer()
        service.add(observer: observer)
        service.save(code: "first"); service.save(code: "second")
        service.clear()
        XCTAssertNil(service.link)
        service.save(code: "third")
        XCTAssertEqual(observer.oldCodes, [nil, "first", nil])
    }

    func testAllEnvironmentsAcceptOnlyCompleteOneToSixteenCharacterCodes() throws {
        for prefix in ["", "/dev", "/test", "/stage"] {
            for code in ["a", "Abc123", "1234567890abcdef"] {
                let service = service()
                XCTAssertTrue(service.handle(url: try XCTUnwrap(URL(string: "https://example.invalid\(prefix)/join/\(code)?source=wallet"))))
                XCTAssertEqual(service.link?.code, code)
            }
        }
    }

    func testMalformedPathsNeverReplaceAnExistingInvitation() throws {
        let service = service(); service.save(code: "retained")
        let observer = Observer(); service.add(observer: observer)
        for path in ["/join/", "/join/12345678901234567", "/join/abc-def", "/join/abc/extra", "/other/join/abc", "/join/abc%0A", "/join/abc%0D", "/join/%D0%B0%D0%B1%D0%B2"] {
            XCTAssertFalse(service.handle(url: try XCTUnwrap(URL(string: "https://example.invalid" + path))), path)
            XCTAssertEqual(service.link?.code, "retained", path)
        }
        XCTAssertTrue(observer.oldCodes.isEmpty)
    }
}

final class KeystoreImportObserverLifecycleTests: XCTestCase {
    private final class Observer: KeystoreImportObserver {
        var oldPayloads: [String?] = []
        var onUpdate: (() -> Void)?
        func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
            oldPayloads.append(oldDefinition?.encoded)
            onUpdate?()
        }
    }

    private func file(payload: String = "test-payload", version: Any = "3") throws -> URL {
        let json: [String: Any] = ["address": "test-only", "encoded": payload,
                                  "encoding": ["content": ["pkcs8", "sr25519"], "type": ["none"], "version": version]]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testRemovingOneObserverLeavesTheOtherSubscribed() throws {
        let service = KeystoreImportService(logger: Logger.shared); let first = Observer(); let second = Observer()
        service.add(observer: first); service.add(observer: second)
        service.remove(observer: first)
        XCTAssertTrue(service.handle(url: try file()))
        XCTAssertTrue(first.oldPayloads.isEmpty)
        XCTAssertEqual(second.oldPayloads.count, 1)
    }

    func testRemovingAnUnknownObserverPreservesRegisteredObservers() throws {
        let service = KeystoreImportService(logger: Logger.shared); let observer = Observer()
        service.add(observer: observer); service.remove(observer: Observer())
        XCTAssertTrue(service.handle(url: try file()))
        XCTAssertEqual(observer.oldPayloads.count, 1)
    }

    func testDuplicateObserversAreNotRetainedOrNotifiedTwice() throws {
        let service = KeystoreImportService(logger: Logger.shared); let observer = Observer()
        service.add(observer: observer); service.add(observer: observer)
        weak var released: Observer?
        autoreleasepool { let transient = Observer(); released = transient; service.add(observer: transient) }
        XCTAssertNil(released)
        XCTAssertTrue(service.handle(url: try file()))
        XCTAssertEqual(observer.oldPayloads.count, 1)
    }

    func testFailedReadAndMalformedJsonPreserveThePreviousImport() throws {
        let service = KeystoreImportService(logger: Logger.shared); let observer = Observer()
        service.add(observer: observer)
        let good = try file(payload: "retained")
        XCTAssertTrue(service.handle(url: good))
        let bad = try file(); try Data("not json".utf8).write(to: bad)
        XCTAssertFalse(service.handle(url: bad))
        XCTAssertFalse(service.handle(url: bad.appendingPathComponent("missing")))
        XCTAssertEqual(service.definition?.encoded, "retained")
        XCTAssertEqual(observer.oldPayloads.count, 1)
    }

    func testClearResetsTheDefinitionPassedToTheNextImport() throws {
        let service = KeystoreImportService(logger: Logger.shared); let observer = Observer()
        service.add(observer: observer)
        XCTAssertTrue(service.handle(url: try file(payload: "first")))
        XCTAssertTrue(service.handle(url: try file(payload: "second")))
        service.clear(); XCTAssertNil(service.definition)
        XCTAssertTrue(service.handle(url: try file(payload: "third")))
        XCTAssertEqual(observer.oldPayloads, [nil, "first", nil])
    }

    func testAnObserverCanUnsubscribeDuringImportWithoutRemovingItsPeer() throws {
        let service = KeystoreImportService(logger: Logger.shared); let first = Observer(); let second = Observer()
        first.onUpdate = { [weak first] in if let first { service.remove(observer: first) } }
        service.add(observer: first); service.add(observer: second)
        XCTAssertTrue(service.handle(url: try file(payload: "first")))
        XCTAssertTrue(service.handle(url: try file(payload: "second")))
        XCTAssertEqual(first.oldPayloads.count, 1)
        XCTAssertEqual(second.oldPayloads, [nil, "first"])
    }

    func testNumericAndStringEncodingVersionsBothReachTheImportObserver() throws {
        let service = KeystoreImportService(logger: Logger.shared); let observer = Observer()
        service.add(observer: observer)
        for version in ["3", 3] as [Any] {
            XCTAssertTrue(service.handle(url: try file(version: version)))
            XCTAssertEqual(service.definition?.encoding.version, "3")
        }
        XCTAssertEqual(observer.oldPayloads.count, 2)
    }
}
