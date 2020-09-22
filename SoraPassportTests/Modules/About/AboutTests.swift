/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo

class AboutTests: XCTestCase {
    let about: AboutData = {
        let legalData = LegalData(termsUrl: URL(string: "https://sora/terms")!,
                                  privacyPolicyUrl: URL(string: "https://sora/privacy")!)

        let supportData = SupportData(title: "",
                                      subject: "",
                                      details: "",
                                      email: "")

        return AboutData(version: "1.1.0",
                         opensourceUrl: URL(string: "https://sora/opensource")!,
                         legal: legalData,
                         writeUs: supportData)
    }()

    func testSetupAndActivitiesSelection() {
        // given

        let presenter = AboutPresenter(locale: Locale.current, about: about)
        let view = MockAboutViewProtocol()
        let wireframe = MockAboutWireframeProtocol()

        presenter.view = view
        presenter.wireframe = wireframe

        // when

        stub(view) { stub in
            when(stub).didReceive(version: any(String.self)).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub).showWeb(url: any(), from: any(), style: any()).thenDoNothing()
        }

        presenter.setup()

        presenter.activateTerms()
        presenter.activateOpensource()
        presenter.activatePrivacyPolicy()

        // then

        verify(view, times(1)).didReceive(version: about.version)
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.about.legal.termsUrl }, from: any(), style: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.about.legal.privacyPolicyUrl }, from: any(), style: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.about.opensourceUrl }, from: any(), style: any())
    }
}
