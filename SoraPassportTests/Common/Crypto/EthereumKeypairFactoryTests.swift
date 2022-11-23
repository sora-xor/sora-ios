import XCTest
@testable import SoraPassport

class EthereumKeypairFactoryTests: XCTestCase {
    private struct TestVector {
        let mnemonic: String
        let privateKey: String
        let entropy: String
    }

    private static let testVectors: [TestVector] = [
        TestVector(mnemonic: "void come effort suffer camp survey warrior heavy shoot primary clutch crush open amazing screen patrol group space point ten exist slush involve unfold",
            privateKey: "2a0d9b9e39b5aceaa4720463a904d945e993757cd8cee7ff35c9b572985d79ea",
            entropy: "f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f"),
        TestVector(mnemonic: "true cruel abuse teach push floor sauce core height diesel bar stove gallery hidden cargo spare jaguar anxiety",
                   privateKey: "c5a9e554d622426b8f910e1c15888967dfef7ff82314ac27dfac0b76c2b58920",
                   entropy: "e9469004ef4aeab2efe1826aa7b049eb55f0d6c8ae837721"),
        TestVector(mnemonic: "vessel ladder alter error federal sibling chat ability sun glass valve picture",
                   privateKey: "a4c3a36b0062af9c9518a31de70fc22e665666128c5d52f12f106b0a4739295a",
                   entropy: "f30f8c1da665478f49b001d94c5fc452"),
        TestVector(mnemonic: "cliff cloud edit young bench cake police rather business gesture marine lawsuit erupt reason grab",
                   privateKey: "59aab2dba6342d09d026c2acd576d24fee746c18fd4f057c0817f07917987d90",
                   entropy: "2ae57d19ffa15040a9ed921f0c2e203f14cf6619")
    ]
/*
    func testSuccessPrivateKeyGenerationFromMnemonic() {
        do {
            let keypairFactory = EthereumKeypairFactory()

            for test in Self.testVectors {
                let privateKey = try keypairFactory.derivePrivateKey(from: test.mnemonic).soraHex
                XCTAssertEqual(privateKey, test.privateKey)
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testSuccessPrivateKeyGenerationFromEntropy() {
        do {
            let keypairFactory = EthereumKeypairFactory()

            for test in Self.testVectors {
                let entropy = Data(hexString:test.entropy)!
                let privateKey = try keypairFactory.derivePrivateKey(from: entropy).soraHex
                XCTAssertEqual(privateKey, test.privateKey)
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
 */
}
