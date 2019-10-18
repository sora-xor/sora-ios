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

    if let privateKey = IREd25519KeyFactory().createRandomKeypair()?.privateKey(),
        let rawSigner = IREd25519Sha512Signer(privateKey: privateKey) {
        signer = signer.with(rawSigner: rawSigner)
    }

    signer = signer.with(decentralizedId: Constants.dummyDid)
        .with(publicKeyId: Constants.dummyPubKeyId)
        .with(timestamp: Int64(Date().timeIntervalSince1970 * 1000))
    
    return signer
}
