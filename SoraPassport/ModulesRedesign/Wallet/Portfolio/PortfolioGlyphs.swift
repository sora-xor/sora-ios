// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import UIKit

/// Vector glyphs of the portfolio surfaces.
enum PortfolioGlyphs {
    /// The Polkaswap flower, point for point the outline of the asset catalogue vector
    /// (`Wallet/polkaswap.imageset`, a 40 x 40 pt PDF), so the hero can draw it sharp at any size.
    static func flowerPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 36.2891, y: 16.2891))
        path.addCurve(to: CGPoint(x: 38.9062, y: 17.3828), controlPoint1: CGPoint(x: 37.3307, y: 16.2891), controlPoint2: CGPoint(x: 38.2031, y: 16.6536))
        path.addCurve(to: CGPoint(x: 40, y: 20), controlPoint1: CGPoint(x: 39.6354, y: 18.0859), controlPoint2: CGPoint(x: 40, y: 18.9583))
        path.addCurve(to: CGPoint(x: 38.9062, y: 22.6172), controlPoint1: CGPoint(x: 40, y: 21.0156), controlPoint2: CGPoint(x: 39.6354, y: 21.888))
        path.addCurve(to: CGPoint(x: 36.2891, y: 23.7109), controlPoint1: CGPoint(x: 38.2031, y: 23.3464), controlPoint2: CGPoint(x: 37.3307, y: 23.7109))
        path.addCurve(to: CGPoint(x: 31.2891, y: 22.6562), controlPoint1: CGPoint(x: 35.612, y: 23.7109), controlPoint2: CGPoint(x: 33.9453, y: 23.3594))
        path.addCurve(to: CGPoint(x: 22.2266, y: 20), controlPoint1: CGPoint(x: 28.6328, y: 21.9271), controlPoint2: CGPoint(x: 25.612, y: 21.0417))
        path.addCurve(to: CGPoint(x: 31.2891, y: 17.3828), controlPoint1: CGPoint(x: 25.612, y: 18.9583), controlPoint2: CGPoint(x: 28.6328, y: 18.0859))
        path.addCurve(to: CGPoint(x: 36.2891, y: 16.2891), controlPoint1: CGPoint(x: 33.9453, y: 16.6536), controlPoint2: CGPoint(x: 35.612, y: 16.2891))
        path.close()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addCurve(to: CGPoint(x: 1.0938, y: 17.3828), controlPoint1: CGPoint(x: 0, y: 18.9583), controlPoint2: CGPoint(x: 0.3646, y: 18.0859))
        path.addCurve(to: CGPoint(x: 3.7109, y: 16.2891), controlPoint1: CGPoint(x: 1.8229, y: 16.6536), controlPoint2: CGPoint(x: 2.6953, y: 16.2891))
        path.addCurve(to: CGPoint(x: 8.7109, y: 17.3828), controlPoint1: CGPoint(x: 4.388, y: 16.2891), controlPoint2: CGPoint(x: 6.0547, y: 16.6536))
        path.addCurve(to: CGPoint(x: 17.7734, y: 20), controlPoint1: CGPoint(x: 11.3672, y: 18.0859), controlPoint2: CGPoint(x: 14.388, y: 18.9583))
        path.addCurve(to: CGPoint(x: 8.7109, y: 22.6562), controlPoint1: CGPoint(x: 14.388, y: 21.0417), controlPoint2: CGPoint(x: 11.3672, y: 21.9271))
        path.addCurve(to: CGPoint(x: 3.7109, y: 23.7109), controlPoint1: CGPoint(x: 6.0547, y: 23.3594), controlPoint2: CGPoint(x: 4.388, y: 23.7109))
        path.addCurve(to: CGPoint(x: 1.0938, y: 22.6172), controlPoint1: CGPoint(x: 2.6953, y: 23.7109), controlPoint2: CGPoint(x: 1.8229, y: 23.3464))
        path.addCurve(to: CGPoint(x: 0, y: 20), controlPoint1: CGPoint(x: 0.3646, y: 21.888), controlPoint2: CGPoint(x: 0, y: 21.0156))
        path.close()
        path.move(to: CGPoint(x: 9.3359, y: 30.7422))
        path.addCurve(to: CGPoint(x: 8.2422, y: 28.125), controlPoint1: CGPoint(x: 8.6068, y: 29.9609), controlPoint2: CGPoint(x: 8.2422, y: 29.0885))
        path.addCurve(to: CGPoint(x: 8.5156, y: 26.7188), controlPoint1: CGPoint(x: 8.2422, y: 27.6562), controlPoint2: CGPoint(x: 8.3333, y: 27.1875))
        path.addCurve(to: CGPoint(x: 9.3359, y: 25.5078), controlPoint1: CGPoint(x: 8.724, y: 26.25), controlPoint2: CGPoint(x: 8.9974, y: 25.8464))
        path.addCurve(to: CGPoint(x: 12.7734, y: 23.5938), controlPoint1: CGPoint(x: 9.8047, y: 25.0391), controlPoint2: CGPoint(x: 10.9505, y: 24.401))
        path.addCurve(to: CGPoint(x: 19.0234, y: 21.0938), controlPoint1: CGPoint(x: 14.6224, y: 22.7865), controlPoint2: CGPoint(x: 16.7057, y: 21.9531))
        path.addCurve(to: CGPoint(x: 16.4844, y: 27.3047), controlPoint1: CGPoint(x: 18.1641, y: 23.4115), controlPoint2: CGPoint(x: 17.3177, y: 25.4818))
        path.addCurve(to: CGPoint(x: 14.5703, y: 30.7422), controlPoint1: CGPoint(x: 15.6771, y: 29.1276), controlPoint2: CGPoint(x: 15.0391, y: 30.2734))
        path.addCurve(to: CGPoint(x: 13.3594, y: 31.5625), controlPoint1: CGPoint(x: 14.2318, y: 31.0807), controlPoint2: CGPoint(x: 13.8281, y: 31.3542))
        path.addCurve(to: CGPoint(x: 11.9531, y: 31.8359), controlPoint1: CGPoint(x: 12.8906, y: 31.7448), controlPoint2: CGPoint(x: 12.4219, y: 31.8359))
        path.addCurve(to: CGPoint(x: 9.3359, y: 30.7422), controlPoint1: CGPoint(x: 10.9896, y: 31.8359), controlPoint2: CGPoint(x: 10.1172, y: 31.4714))
        path.close()
        path.move(to: CGPoint(x: 9.3359, y: 14.4531))
        path.addCurve(to: CGPoint(x: 8.2422, y: 11.8359), controlPoint1: CGPoint(x: 8.6068, y: 13.6719), controlPoint2: CGPoint(x: 8.2422, y: 12.7995))
        path.addCurve(to: CGPoint(x: 8.5156, y: 10.4297), controlPoint1: CGPoint(x: 8.2422, y: 11.3672), controlPoint2: CGPoint(x: 8.3333, y: 10.8984))
        path.addCurve(to: CGPoint(x: 9.3359, y: 9.2188), controlPoint1: CGPoint(x: 8.724, y: 9.9609), controlPoint2: CGPoint(x: 8.9974, y: 9.5573))
        path.addCurve(to: CGPoint(x: 11.9531, y: 8.125), controlPoint1: CGPoint(x: 10.0651, y: 8.4896), controlPoint2: CGPoint(x: 10.9375, y: 8.125))
        path.addCurve(to: CGPoint(x: 14.5703, y: 9.2188), controlPoint1: CGPoint(x: 12.9948, y: 8.125), controlPoint2: CGPoint(x: 13.8672, y: 8.4896))
        path.addCurve(to: CGPoint(x: 16.4844, y: 12.6953), controlPoint1: CGPoint(x: 15.0391, y: 9.6875), controlPoint2: CGPoint(x: 15.6771, y: 10.8464))
        path.addCurve(to: CGPoint(x: 19.0234, y: 18.9063), controlPoint1: CGPoint(x: 17.3177, y: 14.5182), controlPoint2: CGPoint(x: 18.1641, y: 16.5885))
        path.addCurve(to: CGPoint(x: 12.7734, y: 16.4063), controlPoint1: CGPoint(x: 16.7057, y: 18.0469), controlPoint2: CGPoint(x: 14.6224, y: 17.2135))
        path.addCurve(to: CGPoint(x: 9.3359, y: 14.4531), controlPoint1: CGPoint(x: 10.9505, y: 15.5729), controlPoint2: CGPoint(x: 9.8047, y: 14.9219))
        path.close()
        path.move(to: CGPoint(x: 16.2891, y: 36.2891))
        path.addCurve(to: CGPoint(x: 17.3438, y: 31.2891), controlPoint1: CGPoint(x: 16.2891, y: 35.612), controlPoint2: CGPoint(x: 16.6406, y: 33.9453))
        path.addCurve(to: CGPoint(x: 20, y: 22.2266), controlPoint1: CGPoint(x: 18.0729, y: 28.6328), controlPoint2: CGPoint(x: 18.9583, y: 25.612))
        path.addCurve(to: CGPoint(x: 22.6172, y: 31.2891), controlPoint1: CGPoint(x: 21.0417, y: 25.612), controlPoint2: CGPoint(x: 21.9141, y: 28.6328))
        path.addCurve(to: CGPoint(x: 23.7109, y: 36.2891), controlPoint1: CGPoint(x: 23.3464, y: 33.9453), controlPoint2: CGPoint(x: 23.7109, y: 35.612))
        path.addCurve(to: CGPoint(x: 22.6172, y: 38.9062), controlPoint1: CGPoint(x: 23.7109, y: 37.3047), controlPoint2: CGPoint(x: 23.3464, y: 38.1771))
        path.addCurve(to: CGPoint(x: 20, y: 40), controlPoint1: CGPoint(x: 21.9141, y: 39.6354), controlPoint2: CGPoint(x: 21.0417, y: 40))
        path.addCurve(to: CGPoint(x: 17.3828, y: 38.9062), controlPoint1: CGPoint(x: 18.9844, y: 40), controlPoint2: CGPoint(x: 18.112, y: 39.6354))
        path.addCurve(to: CGPoint(x: 16.2891, y: 36.2891), controlPoint1: CGPoint(x: 16.6536, y: 38.1771), controlPoint2: CGPoint(x: 16.2891, y: 37.3047))
        path.close()
        path.move(to: CGPoint(x: 16.2891, y: 3.7109))
        path.addCurve(to: CGPoint(x: 17.3828, y: 1.0938), controlPoint1: CGPoint(x: 16.2891, y: 2.6693), controlPoint2: CGPoint(x: 16.6536, y: 1.7969))
        path.addCurve(to: CGPoint(x: 20, y: 0), controlPoint1: CGPoint(x: 18.112, y: 0.3646), controlPoint2: CGPoint(x: 18.9844, y: 0))
        path.addCurve(to: CGPoint(x: 22.6172, y: 1.0938), controlPoint1: CGPoint(x: 21.0417, y: 0), controlPoint2: CGPoint(x: 21.9141, y: 0.3646))
        path.addCurve(to: CGPoint(x: 23.7109, y: 3.7109), controlPoint1: CGPoint(x: 23.3464, y: 1.7969), controlPoint2: CGPoint(x: 23.7109, y: 2.6693))
        path.addCurve(to: CGPoint(x: 22.6172, y: 8.7109), controlPoint1: CGPoint(x: 23.7109, y: 4.388), controlPoint2: CGPoint(x: 23.3464, y: 6.0547))
        path.addCurve(to: CGPoint(x: 20, y: 17.7734), controlPoint1: CGPoint(x: 21.9141, y: 11.3672), controlPoint2: CGPoint(x: 21.0417, y: 14.388))
        path.addCurve(to: CGPoint(x: 17.3438, y: 8.7109), controlPoint1: CGPoint(x: 18.9583, y: 14.388), controlPoint2: CGPoint(x: 18.0729, y: 11.3672))
        path.addCurve(to: CGPoint(x: 16.2891, y: 3.7109), controlPoint1: CGPoint(x: 16.6406, y: 6.0547), controlPoint2: CGPoint(x: 16.2891, y: 4.388))
        path.close()
        path.move(to: CGPoint(x: 21.1719, y: 21.0938))
        path.addCurve(to: CGPoint(x: 27.3828, y: 23.5938), controlPoint1: CGPoint(x: 23.4896, y: 21.9531), controlPoint2: CGPoint(x: 25.5599, y: 22.7865))
        path.addCurve(to: CGPoint(x: 30.8594, y: 25.5078), controlPoint1: CGPoint(x: 29.2318, y: 24.401), controlPoint2: CGPoint(x: 30.3906, y: 25.0391))
        path.addCurve(to: CGPoint(x: 31.9531, y: 28.125), controlPoint1: CGPoint(x: 31.5885, y: 26.2109), controlPoint2: CGPoint(x: 31.9531, y: 27.0833))
        path.addCurve(to: CGPoint(x: 30.8594, y: 30.7422), controlPoint1: CGPoint(x: 31.9531, y: 29.1406), controlPoint2: CGPoint(x: 31.5885, y: 30.013))
        path.addCurve(to: CGPoint(x: 29.6484, y: 31.5625), controlPoint1: CGPoint(x: 30.5208, y: 31.0807), controlPoint2: CGPoint(x: 30.1172, y: 31.3542))
        path.addCurve(to: CGPoint(x: 28.2422, y: 31.8359), controlPoint1: CGPoint(x: 29.1797, y: 31.7448), controlPoint2: CGPoint(x: 28.7109, y: 31.8359))
        path.addCurve(to: CGPoint(x: 25.625, y: 30.7422), controlPoint1: CGPoint(x: 27.2786, y: 31.8359), controlPoint2: CGPoint(x: 26.4062, y: 31.4714))
        path.addCurve(to: CGPoint(x: 23.6719, y: 27.3047), controlPoint1: CGPoint(x: 25.1562, y: 30.2734), controlPoint2: CGPoint(x: 24.5052, y: 29.1276))
        path.addCurve(to: CGPoint(x: 21.1719, y: 21.0938), controlPoint1: CGPoint(x: 22.8646, y: 25.4818), controlPoint2: CGPoint(x: 22.0312, y: 23.4115))
        path.close()
        path.move(to: CGPoint(x: 21.1719, y: 18.9063))
        path.addCurve(to: CGPoint(x: 27.3828, y: 16.4063), controlPoint1: CGPoint(x: 23.4896, y: 18.0469), controlPoint2: CGPoint(x: 25.5599, y: 17.2135))
        path.addCurve(to: CGPoint(x: 30.8594, y: 14.4531), controlPoint1: CGPoint(x: 29.2318, y: 15.5729), controlPoint2: CGPoint(x: 30.3906, y: 14.9219))
        path.addCurve(to: CGPoint(x: 31.9531, y: 11.8359), controlPoint1: CGPoint(x: 31.5885, y: 13.724), controlPoint2: CGPoint(x: 31.9531, y: 12.8516))
        path.addCurve(to: CGPoint(x: 30.8594, y: 9.2188), controlPoint1: CGPoint(x: 31.9531, y: 10.7943), controlPoint2: CGPoint(x: 31.5885, y: 9.9219))
        path.addCurve(to: CGPoint(x: 28.2422, y: 8.125), controlPoint1: CGPoint(x: 30.1563, y: 8.4896), controlPoint2: CGPoint(x: 29.2839, y: 8.125))
        path.addCurve(to: CGPoint(x: 25.625, y: 9.2188), controlPoint1: CGPoint(x: 27.2266, y: 8.125), controlPoint2: CGPoint(x: 26.3542, y: 8.4896))
        path.addCurve(to: CGPoint(x: 23.6719, y: 12.6953), controlPoint1: CGPoint(x: 25.1562, y: 9.6875), controlPoint2: CGPoint(x: 24.5052, y: 10.8464))
        path.addCurve(to: CGPoint(x: 21.1719, y: 18.9063), controlPoint1: CGPoint(x: 22.8646, y: 14.5182), controlPoint2: CGPoint(x: 22.0312, y: 16.5885))
        path.close()
        let scale = min(rect.width, rect.height) / 40
        path.apply(CGAffineTransform(translationX: rect.midX - 20 * scale, y: rect.midY - 20 * scale)
            .scaledBy(x: scale, y: scale))
        return path
    }

    /// The 天 mark of the SORA logo, point for point the XOR token icon's outline on its 22-unit
    /// disc (the same outline the Android app draws), fitted to the disc `rect`.
    static func soraMarkPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5.8, y: 20.7))
        path.addCurve(to: CGPoint(x: 11.1, y: 12.9), controlPoint1: CGPoint(x: 7.5, y: 18.1), controlPoint2: CGPoint(x: 9.3, y: 15.5))
        path.addLine(to: CGPoint(x: 16.3, y: 20.7))
        path.addCurve(to: CGPoint(x: 17.1, y: 20.2), controlPoint1: CGPoint(x: 16.6, y: 20.6), controlPoint2: CGPoint(x: 16.8, y: 20.4))
        path.addCurve(to: CGPoint(x: 17.8, y: 19.7), controlPoint1: CGPoint(x: 17.4, y: 20), controlPoint2: CGPoint(x: 17.6, y: 19.9))
        path.addCurve(to: CGPoint(x: 12, y: 11), controlPoint1: CGPoint(x: 15.9, y: 16.8), controlPoint2: CGPoint(x: 13.9, y: 13.9))
        path.addLine(to: CGPoint(x: 17.8, y: 11))
        path.addLine(to: CGPoint(x: 17.8, y: 9.2))
        path.addLine(to: CGPoint(x: 12, y: 9.2))
        path.addLine(to: CGPoint(x: 12, y: 7.3))
        path.addLine(to: CGPoint(x: 17.8, y: 7.3))
        path.addLine(to: CGPoint(x: 17.8, y: 5.5))
        path.addLine(to: CGPoint(x: 4.3, y: 5.5))
        path.addLine(to: CGPoint(x: 4.3, y: 7.3))
        path.addLine(to: CGPoint(x: 10.1, y: 7.3))
        path.addLine(to: CGPoint(x: 10.1, y: 9.2))
        path.addLine(to: CGPoint(x: 4.3, y: 9.2))
        path.addLine(to: CGPoint(x: 4.3, y: 11))
        path.addLine(to: CGPoint(x: 10.1, y: 11))
        path.addLine(to: CGPoint(x: 4.3, y: 19.7))
        path.addCurve(to: CGPoint(x: 5, y: 20.2), controlPoint1: CGPoint(x: 4.5, y: 19.9), controlPoint2: CGPoint(x: 4.7, y: 20))
        path.addCurve(to: CGPoint(x: 5.8, y: 20.7), controlPoint1: CGPoint(x: 5.3, y: 20.4), controlPoint2: CGPoint(x: 5.5, y: 20.6))
        path.close()
        let scale = min(rect.width, rect.height) / 22
        path.apply(CGAffineTransform(translationX: rect.midX - 11 * scale, y: rect.midY - 11 * scale)
            .scaledBy(x: scale, y: scale))
        return path
    }

    /// The SORA mark as a badge: the red disc with 天, as the hero's planet wears it.
    static func soraMarkImage(size: CGFloat) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            let colors = [PortfolioTheme.soraRed.blended(with: .white, 0.14),
                          PortfolioTheme.soraRed.blended(with: .black, 0.24)].map(\.cgColor)
            context.cgContext.saveGState()
            UIBezierPath(ovalIn: rect).addClip()
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                         locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
            }
            context.cgContext.restoreGState()
            UIColor.white.setFill()
            soraMarkPath(in: rect).fill()
            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 1
            UIColor.white.withAlphaComponent(0.22).setStroke()
            ring.stroke()
        }
    }

    /// The flower as an image, for buttons, chips and nodes.
    static func flowerImage(size: CGFloat, color: UIColor = PortfolioTheme.flowerPink) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        return UIGraphicsImageRenderer(size: rect.size).image { _ in
            color.setFill()
            flowerPath(in: rect).fill()
        }
    }

    /// Move: an arc between two nodes, distinct from the flower that means Swap.
    static func moveImage(size: CGFloat, color: UIColor, lineWidth: CGFloat = 1.8) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        return UIGraphicsImageRenderer(size: rect.size).image { _ in
            color.setStroke()
            let node = size * 0.13
            let start = CGPoint(x: size * 0.2, y: size * 0.8)
            let end = CGPoint(x: size * 0.8, y: size * 0.2)
            let arc = UIBezierPath()
            arc.move(to: CGPoint(x: start.x + node * 0.7, y: start.y - node * 0.7))
            arc.addCurve(to: CGPoint(x: end.x - node * 0.7, y: end.y + node * 0.7),
                         controlPoint1: CGPoint(x: size * 0.62, y: size * 0.78),
                         controlPoint2: CGPoint(x: size * 0.38, y: size * 0.22))
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            arc.stroke()
            for center in [start, end] {
                let circle = UIBezierPath(ovalIn: CGRect(x: center.x - node, y: center.y - node,
                                                         width: node * 2, height: node * 2))
                circle.lineWidth = lineWidth
                circle.stroke()
            }
        }
    }

    /// A small symbol image in a given colour (SF Symbols are part of the system).
    static func symbol(_ name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight = .semibold,
                       color: UIColor) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight))?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }
}
