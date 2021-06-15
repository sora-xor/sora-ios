import Foundation
import SoraUI

extension ModalSheetPresentationStyle {
    static var sora: ModalSheetPresentationStyle {
        let indicatorSize = CGSize(width: 35.0, height: 2.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(preferredHeight: 20.0,
                                                            backgroundColor: R.color.baseBackground()!,
                                                            cornerRadius: 20.0,
                                                            indicatorVerticalOffset: 2.0,
                                                            indicatorSize: indicatorSize,
                                                            indicatorColor: R.color.baseContentTertiary()!)
        let style = ModalSheetPresentationStyle(backdropColor: R.color.baseBackground()!,
                                                headerStyle: headerStyle)
        return style
    }
}

