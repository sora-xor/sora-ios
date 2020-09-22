import XCTest
@testable import SoraPassport

class PersonalInfoViewModelFactoryTests: XCTestCase {
    func testAcceptedValues() {
        check(for: "D", changes: [], resultValue: "D", expectCompletion: true)
        check(for: "Dummy", changes: (0..<5).map({ _ in "Dummy" }), resultValue: "DummyDummyDummyDummyDummyDummy", expectCompletion: true)
        check(for: "Виталий", changes: [" ", "Деменьтьев"], resultValue: "Виталий Деменьтьев", expectCompletion: true)
        check(for: "Ваш", changes: ["'","ер","-Лаграв"], resultValue: "Ваш'ер-Лаграв", expectCompletion: true)
        check(for: "姓", changes: ["名"], resultValue: "姓名", expectCompletion: true)
        check(for: "Виталий", changes: ["-"," ", "Деменьтьев"], resultValue: "Виталий- Деменьтьев", expectCompletion: true)
    }

    func testHandlingInput() {
        check(for: "DummyDummyDummyDummyDummyDummy", changes: ["A", "B"], resultValue: "DummyDummyDummyDummyDummyDummy", expectCompletion: true)
        check(for: "Виталий", changes: [",", " ", "Деметьев"], resultValue: "Виталий Деметьев", expectCompletion: true)
        check(for: "Ваш", changes: ["`", "ер", "-", "Лаграв"], resultValue: "Вашер-Лаграв", expectCompletion: true)
        check(for: "Ваш", changes: ["'", "ер", "=","Лаграв"], resultValue: "Ваш'ерЛаграв", expectCompletion: true)
        check(for: "", changes: ["姓", "2", "名"], resultValue: "姓名", expectCompletion: true)
        check(for: "", changes: [" ", "-", "'"], resultValue: "", expectCompletion: false)
        check(for: "Robert", changes: [" ", "-", "'"], resultValue: "Robert -'", expectCompletion: false)
        check(for: "Robert", changes: [" ", "-", "'", "Brown"], resultValue: "Robert -'Brown", expectCompletion: true)
        check(for: "Robert", changes: [" "], resultValue: "Robert", expectCompletion: true)
        check(for: "Robert ", changes: [], resultValue: "Robert", expectCompletion: true)
        check(for: "Robert", changes: ["-"], resultValue: "Robert-", expectCompletion: false)
        check(for: "Robert", changes: ["'"], resultValue: "Robert'", expectCompletion: false)
    }

    // MARK: Private

    func check(for initialValue: String, changes: [String], resultValue: String, expectCompletion: Bool) {
        let personalForm = PersonalForm(firstName: initialValue,
                                        lastName: initialValue,
                                        countryCode: "RU",
                                        invitationCode: "")

        let viewModelFactory = PersonalInfoViewModelFactory()
        let viewModel = viewModelFactory.createRegistrationForm(from: personalForm,
                                                                locale: Locale.current)

        changes.forEach {
            let value = viewModel[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler.value
            _ = viewModel[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler
                    .didReceiveReplacement($0, for: NSRange(location: value.unicodeScalars.count, length: 0))
            _ = viewModel[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].inputHandler
                    .didReceiveReplacement($0, for: NSRange(location: value.unicodeScalars.count, length: 0))
        }

        XCTAssertEqual(viewModel[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler.completed, expectCompletion,
                       "initial: \(initialValue)\nchanges: \(changes)")
        XCTAssertEqual(viewModel[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].inputHandler.completed, expectCompletion,
                       "initial: \(initialValue)\nchanges: \(changes)")

        XCTAssertEqual(viewModel[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler.normalizedValue,
                       resultValue)
        XCTAssertEqual(viewModel[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].inputHandler.normalizedValue,
                       resultValue)
    }
}
