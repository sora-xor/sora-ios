import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import SoraFoundation

class PersonalInfoInteractorTests: NetworkBaseTests {

    func testSuccessfullRegistration() {
        do {
            let keystore = InMemoryKeychain()
            var settings = InMemorySettingsManager()

            settings.verificationState = VerificationState()
            settings.decentralizedId = Constants.dummyDid
            settings.invitationCode = Constants.dummyInvitationCode

            XCTAssertNotNil(settings.decentralizedId)

            guard let pincodeExists = try? keystore.checkKey(for: KeystoreTag.pincode.rawValue), !pincodeExists else {
                XCTFail("Pincode must be unset")
                return
            }

        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
