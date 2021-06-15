import XCTest
import SoraFoundation
@testable import SoraPassport

class PersonalInfoViewModelFactoryTests: XCTestCase {
    func testAcceptedValues() {
        check(for: "D", changes: [], resultValue: "D", expectCompletion: true)
        check(for: "A", changes: ["🙄"], resultValue: "A🙄", expectCompletion: true)
        check(for: "B", changes: ["🙅",""], resultValue: "B🙅", expectCompletion: true)
        check(for: "Dummy", changes: (0..<5).map({ _ in "Dummy" }), resultValue: "DummyDummyDummyDummyDummyDummy", expectCompletion: true)
        check(for: "Виталий", changes: [" ", "Деменьтьев"], resultValue: "Виталий Деменьтьев", expectCompletion: true)
        check(for: "Ваш", changes: ["'","ер","-Лаграв"], resultValue: "Ваш'ер-Лаграв", expectCompletion: true)
        check(for: "姓", changes: ["名"], resultValue: "姓名", expectCompletion: true)
        check(for: "Виталий", changes: ["-"," ", "Деменьтьев"], resultValue: "Виталий- Деменьтьев", expectCompletion: true)
    }

    func testHandlingInput() {
        check(for: "DummyDummyDummyDummyDummyDummy", changes: ["A", "B"], resultValue: "DummyDummyDummyDummyDummyDummyAB", expectCompletion: true)
        check(for: "Robert", changes: ["-"], resultValue: "Robert-", expectCompletion: true)
        check(for: "Robert", changes: ["'"], resultValue: "Robert'", expectCompletion: true)
    }

    func testHandlingInputMaxLengthInBytes() {
        checkLengthInBytes(for: "123456789012345678901234567890123", result: false)
        checkLengthInBytes(for: "12345678901234567890123456789012", result: true)
        checkLengthInBytes(for: "DummyDummyDummyDummyDummyDummy", result: true)
        checkLengthInBytes(for: "越1越2越3越4越5越6越7越8", result: true)
        checkLengthInBytes(for: "1️⃣2️⃣3️⃣4️⃣56789", result: false)
        checkLengthInBytes(for: "1️⃣2️⃣3️⃣4️⃣5678", result: true)
    }

    // MARK: Private

    func check(for initialValue: String, changes: [String], resultValue: String, expectCompletion: Bool) {
        let personalForm = PersonalForm(firstName: "",
                                        lastName: "",
                                        countryCode: "RU",
                                        invitationCode: "",
                                        username: initialValue)

        let viewModelFactory = PersonalInfoViewModelFactory()
        let viewModel = viewModelFactory.createRegistrationForm(from: personalForm,
                                                                locale: Locale.current)

        changes.forEach {
            let value = viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler.value
            _ = viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler
                    .didReceiveReplacement($0, for: NSRange(location: value.unicodeScalars.count, length: 0))
        }

        XCTAssertEqual(viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler.completed, expectCompletion,
                       "initial: \(initialValue)\nchanges: \(changes)")
        XCTAssertEqual(viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler.completed, expectCompletion,
                       "initial: \(initialValue)\nchanges: \(changes)")

        XCTAssertEqual(viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler.normalizedValue,
                       resultValue)
        XCTAssertEqual(viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler.normalizedValue,
                       resultValue)
    }

    func checkLengthInBytes(for initialValue: String, result: Bool) {
        let viewModelFactory = PersonalInfoViewModelFactory()
        let viewModel = viewModelFactory.createViewModels(from: initialValue, locale: Locale.current)

        let model = viewModel[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue]

        let range = NSRange(location: 0, length: 0)

        let inputHandler: InputHandler! = model.inputHandler as? InputHandler

        let shouldApply = inputHandler?.valueBytesLimited(in: range, with: "") ?? false

        XCTAssertNotNil(inputHandler)
        XCTAssertEqual(shouldApply, result)
    }
}
