import Foundation

protocol LocalAuthInteractorInputProtocol: AnyObject {
    var allowManualBiometryAuth: Bool { get }

    func startAuth()
    func process(pin: String)
    func getPinCodeCount()
    func getInputBlockDate() -> Date?
    func updatePin(pin: String, completion: (() -> Void)?)
}

protocol LocalAuthInteractorOutputProtocol: AnyObject {
    func didEnterWrongPincode()
    func blockUserInputUntil(date: Date)
    func reachedLastChancePinInput()
    func didChangeState(from state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
    func setupPinCodeSymbols(with count: Int)
}

extension LocalAuthInteractorOutputProtocol {
    func setupPinCodeSymbols(with count: Int) {}
}