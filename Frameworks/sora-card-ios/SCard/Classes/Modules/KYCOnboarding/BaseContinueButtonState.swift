import Foundation
import SoraUIKit

enum BaseContinueButtonState: Equatable {
    case enabled(String)
    case disabled(String)
    
    var textItem: SoramitsuTextItem {
        let text: String
        
        switch self {
        case .enabled(let buttonText), .disabled(let buttonText):
            text = buttonText
        }
        
        let color: SoramitsuColor = (self == .enabled(text)) ? .bgSurface : .fgSecondary
        
        return SoramitsuTextItem(
            text: text,
            fontData: FontType.buttonM,
            textColor: color,
            alignment: .center
        )
    }
    
    func apply(to button: SoramitsuButton) {
        button.sora.attributedText = self.textItem
    }
    
    static func == (lhs: BaseContinueButtonState, rhs: BaseContinueButtonState) -> Bool {
        switch (lhs, rhs) {
        case (.enabled(let text1), .enabled(let text2)),
             (.disabled(let text1), .disabled(let text2)):
            return text1 == text2
        default:
            return false
        }
    }
}
