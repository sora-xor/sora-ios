import Foundation

final class DisclaimerViewFactory: DisclaimerViewFactoryProtocol {
    func createView() -> DisclaimerViewProtocol? {
        let view = DisclaimerViewController(nib: R.nib.disclaimerViewController)
        return view
    }
}
