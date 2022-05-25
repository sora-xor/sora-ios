import Foundation
import UIKit
import Lottie

class SplashViewController: UIViewController, SplashViewProtocol {

    var presenter: SplashPresenter!

    private lazy var splash: SplashView = {
        return R.nib.launchScreen(owner: nil)!
    }()

    private lazy var animationView = AnimationView(filePath: R.file.soraSplashJson.path()!)

    override func viewDidLoad() {
        view.backgroundColor = R.color.baseBackground()
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        animationView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        animationView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        animationView.play(fromProgress: 0, toProgress: 0.8, loopMode: .playOnce, completion: nil)
    }

    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        animationView.play(fromProgress: 0.8, toProgress: 1, loopMode: .playOnce) { (_) in
            completion()
        }
    }
}
