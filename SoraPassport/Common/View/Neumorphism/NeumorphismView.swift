import UIKit

class NeumorphismView: UIView {

    let shadowLayerName = "shadow"

    @IBInspectable var bottomShadowColor: UIColor =  R.color.neumorphism.darkShadow()! {
        didSet {
            addNeumorphismShadows()
        }
    }

    @IBInspectable var topShadowColor: UIColor = R.color.neumorphism.lightShadow()! {
        didSet {
            addNeumorphismShadows()
        }
    }

    @IBInspectable var shadowCornerRadius: CGFloat = 32 {
        didSet {
            addNeumorphismShadows()
        }
    }

    @IBInspectable var shadowRadius: CGFloat = 4 {
        didSet {
            addNeumorphismShadows()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = false
        addNeumorphismShadows()
    }

    func addNeumorphismShadows() {
        removeNeumorphismShadows()

        let mainColor = CALayer()
        mainColor.name = shadowLayerName
        mainColor.frame = bounds
        mainColor.backgroundColor = R.color.neumorphism.base()?.cgColor
        mainColor.cornerRadius = shadowCornerRadius
        layer.insertSublayer(mainColor, at: 0)

        let darkShadow = CALayer()
        darkShadow.name = shadowLayerName
        darkShadow.frame = bounds
        darkShadow.backgroundColor = bottomShadowColor.cgColor
        darkShadow.shadowColor = bottomShadowColor.cgColor
        darkShadow.cornerRadius = shadowCornerRadius
        darkShadow.shadowOffset = CGSize(width: shadowRadius, height: shadowRadius)
        darkShadow.shadowOpacity = 1
        darkShadow.shadowRadius = shadowRadius
        layer.insertSublayer(darkShadow, at: 0)

        let lightShadow = CALayer()
        lightShadow.name = shadowLayerName
        lightShadow.frame = bounds
        lightShadow.backgroundColor = topShadowColor.cgColor
        lightShadow.shadowColor = topShadowColor.cgColor
        lightShadow.cornerRadius = shadowCornerRadius
        lightShadow.shadowOffset = CGSize(width: -shadowRadius, height: -shadowRadius)
        lightShadow.shadowOpacity = 1
        lightShadow.shadowRadius = shadowRadius
        layer.insertSublayer(lightShadow, at: 0)
    }

    func removeNeumorphismShadows() {
        layer.sublayers?.removeAll(where: { sublayer in
            sublayer.name == shadowLayerName
        })
    }
}
