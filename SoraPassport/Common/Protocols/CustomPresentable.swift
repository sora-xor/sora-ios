import Foundation
import UIKit
import SoraUIKit

protocol CustomPresentable {}

extension CustomPresentable {
    func present(blurred viewController: UIViewController, on presentingViewController: UIViewController) {
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let nc = UINavigationController(rootViewController: viewController)
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        
        presentingViewController.present(containerView, animated: true)
    }
}
