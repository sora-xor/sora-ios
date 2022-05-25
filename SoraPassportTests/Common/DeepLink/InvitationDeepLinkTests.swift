import XCTest
import SoraKeystore
@testable import SoraPassport
import SoraFoundation

class InvitationDeepLinkTests: XCTestCase {

    func StoptestValidJoinUrlHandled() {
        let codes = ["12345678", "asasadas", "asd23vnm", "aSd23vnM", "AsdvnM"]

        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)
        codes.forEach { code in
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: code, enviroment: .development), expect: code)
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: code, enviroment: .test), expect: code)
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: code, enviroment: .staging), expect: code)
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: code, enviroment: .release), expect: code)
        }
    }

    func StoptestInvalidCodesHandled() {
        let codes = ["", "asasadaaasasadaad", "asd23vnm1asd23vnm1", "12привет", "ASпривет", "12-12345"]

        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)

        for code in codes {
            guard let encodedCode = code.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) else {
                XCTFail("Can't url encode \(code)")
                continue
            }

            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: encodedCode, enviroment: .development), expect: nil)
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: encodedCode, enviroment: .test), expect: nil)
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: encodedCode, enviroment: .staging), expect: nil)
            performTestForAllUserStates(for: invitationFactory.createInvitationLink(for: encodedCode, enviroment: .release), expect: nil)
        }
    }

    // MARK: Private

    private func performTestForAllUserStates(for url: URL, expect code: String?) {
        performTestWhenUserRegistered(for: url, expect: code)
        performTestWhenUserNotRegistered(for: url, expect: code)
    }

    private func performTestWhenUserRegistered(for url: URL, expect code: String?) {
        var settings = InMemorySettingsManager()
        settings.decentralizedId = Constants.dummyDid

        performTest(for: settings, url: url, expect: code)

        XCTAssertNil(settings.invitationCode)
    }

    private func performTestWhenUserNotRegistered(for url: URL, expect code: String?) {
        var settings = InMemorySettingsManager()
        settings.decentralizedId = Constants.dummyDid
        settings.verificationState = VerificationState()

        performTest(for: settings, url: url, expect: code)

        XCTAssertEqual(settings.invitationCode, code)
    }

    func performTest(for settings: SettingsManagerProtocol, url: URL, expect code: String?) {
        let service = InvitationLinkService(settings: settings)

        _ = service.handle(url: url)

        XCTAssertEqual(service.link?.code, code)
    }
}
