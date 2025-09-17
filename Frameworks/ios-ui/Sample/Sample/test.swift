//
//  test.swift
//  Sample
//
//  Created by Ivan Shlyapkin on 28.09.2022.
//

import Foundation
import UIKit

class TabBarShapeView: UIView {
    var shapeLayer: CAShapeLayer!
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        shapeLayer = self.layer as? CAShapeLayer
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.gray.cgColor
        shapeLayer.lineWidth = 1
    }
    override func layoutSubviews() {
        super.layoutSubviews()

        let middleRad: CGFloat = bounds.height - 10.0

        let cornerRad: CGFloat = 12.0

        let pth = UIBezierPath()

        let topLeftC: CGPoint = CGPoint(x: bounds.minX + cornerRad, y: bounds.minY + cornerRad)
        let topRightC: CGPoint = CGPoint(x: bounds.maxX - cornerRad, y: bounds.minY + cornerRad)
        let botRightC: CGPoint = CGPoint(x: bounds.maxX - cornerRad, y: bounds.maxY - cornerRad)
        let botLeftC: CGPoint = CGPoint(x: bounds.minX + cornerRad, y: bounds.maxY - cornerRad)

        var pt: CGPoint!

        // 1
        pt = CGPoint(x: bounds.minX, y: bounds.minY + cornerRad)
        pth.move(to: pt)

        // c1
        pth.addArc(withCenter: topLeftC, radius: cornerRad, startAngle: .pi * 1.0, endAngle: .pi * 1.5, clockwise: true)

        // 2
        pt = CGPoint(x: bounds.midX - middleRad, y: bounds.minY)
        pth.addLine(to: pt)

        // c2
        pt.y += middleRad * 0.5
        pth.addArc(withCenter: pt, radius: middleRad * 0.5, startAngle: -.pi * 0.5, endAngle: 0.0, clockwise: true)

        // c3
        pt.x += middleRad * 1.0
        pth.addArc(withCenter: pt, radius: middleRad * 0.5, startAngle: .pi * 1.0, endAngle: 0.0, clockwise: false)

        // c4
        pt.x += middleRad * 1.0
        pth.addArc(withCenter: pt, radius: middleRad * 0.5, startAngle: .pi * 1.0, endAngle: .pi * 1.5, clockwise: true)

        // 3
        pt = CGPoint(x: bounds.maxX - cornerRad, y: bounds.minY)
        pth.addLine(to: pt)

        // c5
        pth.addArc(withCenter: topRightC, radius: cornerRad, startAngle: -.pi * 0.5, endAngle: 0.0, clockwise: true)

        // 4
        pt = CGPoint(x: bounds.maxX, y: bounds.maxY - cornerRad)
        pth.addLine(to: pt)

        // c6
        pth.addArc(withCenter: botRightC, radius: cornerRad, startAngle: 0.0, endAngle: .pi * 0.5, clockwise: true)

        // 5
        pt = CGPoint(x: bounds.minX + cornerRad, y: bounds.maxY)
        pth.addLine(to: pt)

        // c7
        pth.addArc(withCenter: botLeftC, radius: cornerRad, startAngle: .pi * 0.5, endAngle: .pi * 1.0, clockwise: true)

        pth.close()

        shapeLayer.path = pth.cgPath

    }
}
