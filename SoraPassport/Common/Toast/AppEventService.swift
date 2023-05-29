import UIKit

protocol AppEventDisplayLogic: SilentViewController {
    func show()

    func hide(completion: @escaping () -> Void)
}

final class AppEventService {
    enum HideMode {
        case never
        case after(delay: Double)
    }

    var hideMode: HideMode

    private var viewController: AppEventDisplayLogic?
    private var windowShowed = false
    private var window: UIWindow?
    private var isStopped: Bool = false
    private let throttler = Throttler(minimumDelay: 0.3)

    init(hideMode: HideMode = .after(delay: 3)) {
        self.hideMode = hideMode
    }
    
    deinit {
        window = nil
    }
}

extension AppEventService {
    func showToasterIfNeeded(viewController: AppEventDisplayLogic, isNeedHide: Bool = true, isNeedForceUpdate: Bool = false) {
        guard !windowShowed else { return }
        throttler.throttle { [weak self] in
            guard !(self?.isStopped ?? false) else { return }
            
            self?.viewController = viewController
            
            guard (!(self?.windowShowed ?? false)) || isNeedForceUpdate else { return  }
            
            let completion: (Bool) -> Void = { [weak self] isNeedHide1 in
                self?.window = SilentWindow(root: viewController)
                viewController.show()
                
                self?.windowShowed = true

                if isNeedHide1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.hideToasterIfNeeded()
                    }
                }
            }
            
            if isNeedForceUpdate {
                self?.hideToasterIfNeeded(with: isNeedHide, completion: completion)
                return
            }

            completion(isNeedHide)
        }
    }
    
    func hideToasterIfNeeded(with isNeedHide: Bool = true, completion: ((Bool) -> Void)? = nil) {
        throttler.throttle { [weak self] in
            self?.viewController?.hide { [weak self] in
                if self?.windowShowed == false {
                    self?.window = nil
                }
                completion?(isNeedHide)
            }
            self?.windowShowed = false
        }
    }
    
    func start() {
        isStopped = false
        
        guard let viewController = viewController else { return }
        showToasterIfNeeded(viewController: viewController)
    }
    
    func stop(with completion: (() -> Void)? = nil) {
        hideToasterIfNeeded { [weak self] _ in
            self?.isStopped = true
        }
    }
}

