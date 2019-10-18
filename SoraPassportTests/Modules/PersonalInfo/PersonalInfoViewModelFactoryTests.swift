/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport

class PersonalInfoViewModelFactoryTests: XCTestCase {
    func testAcceptedValues() {
        check(for: "D", shouldAccept: true)
        check(for: "DummyDummyDummyDummyDummyDummy", shouldAccept: true)
        check(for: "Виталий Дементьев", shouldAccept: true)
        check(for: "Ваш'ер-Лаграв", shouldAccept: true)
        check(for: "姓名", shouldAccept: true)
    }

    func testUnacceptedValue() {
        check(for: "DummyDummyDummyDummyDummyDummyA", shouldAccept: false)
        check(for: "Виталий, Деметьев", shouldAccept: false)
        check(for: "Ваш`ер-Лаграв", shouldAccept: false)
        check(for: "Ваш'ер=Лаграв", shouldAccept: false)
        check(for: "姓2名", shouldAccept: false)
    }

    // MARK: Private

    func check(for value: String, shouldAccept: Bool) {
        let personalForm = PersonalForm(firstName: value,
                                        lastName: value,
                                        countryCode: "RU",
                                        invitationCode: "")

        let viewModelFactory = PersonalInfoViewModelFactory()
        let viewModel = viewModelFactory.createRegistrationForm(from: personalForm)

        let expectedValue = shouldAccept ? value : ""

        XCTAssertEqual(viewModel[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].value,
                       expectedValue)
        XCTAssertEqual(viewModel[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].value,
                       expectedValue)
    }
}
