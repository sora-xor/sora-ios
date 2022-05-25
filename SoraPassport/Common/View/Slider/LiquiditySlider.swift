import UIKit

class LiquiditySlider: UISlider {
  
      override func trackRect(forBounds bounds: CGRect) -> CGRect {
          let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.size.width, height: 8.0))
          super.trackRect(forBounds: customBounds)
          return customBounds
      }
  }
