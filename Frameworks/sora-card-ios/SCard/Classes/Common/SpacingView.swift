import Foundation
import SoraUIKit

class SpacingView: SoramitsuView {

    private var height: CGFloat = 0

    init(height: CGFloat) {
        self.height = height
        super.init(frame: .zero)
        setupInitialLayout()
    }

    private func setupInitialLayout() {
        self.snp.makeConstraints {
            $0.height.equalTo(height)
        }
    }
}
