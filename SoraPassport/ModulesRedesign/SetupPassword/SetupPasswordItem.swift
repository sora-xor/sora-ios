import SoraUIKit
import Combine

final class SetupPasswordItem: NSObject {
    
    var setupPasswordButtonTapped: ((String) -> Void)?
    
    private let output: PassthroughSubject<Output, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    enum Input {
        case passwordChanged(String)
        case confirmPasswordChanged(String)
        case checkViewChanged(Bool)
        case setupPasswordButtonTapped
    }

    enum Output {
        case lowSecurityPassword
        case securedPassword
        case notMatchPasswords
        case matchedPasswords
    }
    
    @Published var isButtonEnable: Bool = false
    
    private var password: String = "" {
        didSet {
            validateCurrentState()
        }
    }
    
    private var confirmedPassword: String = "" {
        didSet {
            validateCurrentState()
        }
    }
    
    private var isCheckSelected: Bool = false {
        didSet {
            validateCurrentState()
        }
    }
    
    deinit {
        print("deinit")
    }

    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        input.sink { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .passwordChanged(let text): self.password = text
            case .confirmPasswordChanged(let text): self.confirmedPassword = text
            case .checkViewChanged(let isEnabled): self.isCheckSelected = isEnabled
            case .setupPasswordButtonTapped: self.setupPasswordButtonTapped?(self.password)
            }
        }.store(in: &cancellables)
        return output.eraseToAnyPublisher()
    }
    
    private func validateCurrentState() {
        isButtonEnable = !password.isEmpty && !confirmedPassword.isEmpty && password == confirmedPassword && isCheckSelected && password.count >= 6
        
        output.send(password.count < 6 ? .lowSecurityPassword : .securedPassword)
        
        if !confirmedPassword.isEmpty {
            output.send(password != confirmedPassword ? .notMatchPasswords : .matchedPasswords)
        }
    }
}

extension SetupPasswordItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        SetupPasswordCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
}
