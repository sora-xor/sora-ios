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
    
    @objc
    func close() {
        dismiss(animated: true)
    }

}
