import Foundation
import SoraUIKit

enum CloseButtonPosition {
    case left
    case right
}

extension UIViewController {
    
    func addCloseButton(position: CloseButtonPosition = .right) {
        let closeButton = UIBarButtonItem(image: R.image.wallet.cross(),
                                     style: .plain,
                                     target: self,
                                     action: #selector(close))
        
        switch position {
        case .right: navigationItem.rightBarButtonItem = closeButton
        case .left:  navigationItem.leftBarButtonItem = closeButton
        }
    }
    
    func addBackButton() {
        let backButton = UIBarButtonItem(image: R.image.wallet.backArrow(),
                                     style: .plain,
                                     target: self,
                                     action: #selector(backward))
        
        navigationItem.leftBarButtonItem = backButton
    }
    
    @objc
    func close() {
        dismiss(animated: true)
    }
    
    @objc
    func backward() {
        guard let navigationController = self.navigationController else { return }
        navigationController.popViewController(animated: true)
    }
}
