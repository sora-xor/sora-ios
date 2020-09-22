/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import IrohaCrypto

final class Constants {
    static let expectationDuration: TimeInterval = 60.0
    static let networkRequestTimeout: TimeInterval = 60.0
    static let dummyNetworkURL: URL = URL(string: "https://localhost:8888")!
    static let dummyPincode = "1234"
    static let dummyDid = "did:sora:id"
    static let dummyPubKeyId = "did:sora:id#keys-1"
    static let dummyProjectId = "938d033f-580d-477c-a89f-fcebfcdf8eff"
    static let dummyInvitationCode = "12345678"
    static let dummyInvitationLink = URL(string: "https://ref.sora.org/join/12345678")!
    static let dummySmsCode = "4321"
    static let dummyApplicationFormId = "123231"
    static let dummyFirstName = "DummyName"
    static let dummyLastName = "DummySurname"
    static let dummyPhone = "+7(231)2312313"
    static let dummyEmail = "dummy@gmail.com"
    static let dummyPushToken = "euaP_Bzkq18:APA91bFb3aspRc8rgqQgRJHqWr7OOh4dFm"
    static let dummyValidMnemonic = "sheriff fire three cross tone smile element shop theme bring release artwork tunnel prepare myself"
    static let dummyInvalidMnemonic = "sheriff firewall three cross tone smile element shop theme bring release artwork tunnel prepare myself"
    static let dummyWalletAccountId = "dummy@sora"
    static let dummyOtherWalletAccountId = "otherdummy@sora"
    static let dummyEthAddress = Data(hex: "0xa129197a2FC51260d87B804a29A2aB31BC5B105d")
    static let dummyOtherEthAddress = Data(hex: "0x5E6Fb707C4a469e983434173044d0508A18E47d6")
    static let withdrawalHash =
    Data(hex: "94282533eb24ba1445b9b606a416bbbfc444ab4b6de9fcd241af558e3a1585d5")
    static let transactionHash =
    Data(hex: "89422533eb24ba1445b9b606a416bbbfc444ab4b6de9fcd241af558e3a1585d5")
    static let englishLocalization = "en"
}

func createDummyDecentralizedDocument() -> DecentralizedDocumentObject {
    let proof = DDOProof(type: .ed25519Sha3,
                         created: "",
                         creator: "",
                         signatureValue: "",
                         nonce: "")

    return DecentralizedDocumentObject(decentralizedId: Constants.dummyDid,
                                       created: nil,
                                       updated: nil,
                                       publicKey: [],
                                       authentication: [],
                                       guardian: nil,
                                       service: nil,
                                       proof: proof)
}

func createDummyRequestSigner() -> DARequestSigner {
    var signer = DARequestSigner()

    if let privateKey = try? IRIrohaKeyFactory().createRandomKeypair().privateKey() {
        let rawSigner = IRIrohaSigner(privateKey: privateKey)
        signer = signer.with(rawSigner: rawSigner)
    }

    signer = signer.with(decentralizedId: Constants.dummyDid)
        .with(publicKeyId: Constants.dummyPubKeyId)
        .with(timestamp: Int64(Date().timeIntervalSince1970 * 1000))
    
    return signer
}
