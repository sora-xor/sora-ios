import CoreGraphics
import Foundation

/// The proportions and figures the wallet's motion and composition are built on.
///
/// Every figure is a compass-and-straightedge construction on one circle, so they nest: the seed's six
/// circles sit on the hexagon the kagome's triangles share, and the coin's square is inscribed in the
/// same circle. None of them draws a line through the centre: the red disc sits there, and lines
/// leaving a red disc read as a flag.
public enum SacredGeometry {
    /// 黄金比. Steps the timing ladder.
    public static let phi: CGFloat = 1.618033988749895
    /// 白銀比 (大和比), the proportion of Hōryū-ji and of Japanese paper. Steps sizes.
    public static let yamato: CGFloat = 1.4142135623730951

    /// Durations step by φ from 110 ms: 110, 178, 288, 466, 754, 1220 ms.
    public static func beat(_ step: Int) -> TimeInterval {
        0.110 * pow(Double(phi), Double(max(0, step)))
    }

    public enum Figure: CaseIterable {
        /// 七宝, the flower of life: nineteen circles inside one.
        case shippo
        /// 籠目, the six-pointed weave hung as a ward.
        case kagome
        /// 羅盤, a divided ring: seventy-two marks, twelve of them long.
        case compass
        /// 天円地方: the circle of heaven round the square of earth, the shape of the first coins.
        case coin
        /// Six circles round a seventh place.
        case seed
    }

    /// Radius of each seed circle, and the distance of its centre, as a share of the figure's radius.
    public static let seedShare: CGFloat = 0.5
    /// The coin's inner circle and its square's corners, as a share of the figure's radius.
    public static let coinInnerShare: CGFloat = 0.93

    /// Centres of the six seed circles, from the top, clockwise on screen (y grows down).
    public static func seedCentres(radius: CGFloat) -> [CGPoint] {
        (0..<6).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 3
            return CGPoint(x: radius * seedShare * cos(angle), y: radius * seedShare * sin(angle))
        }
    }

    /// Centres of the flower's nineteen circles; each has a third of the figure's radius.
    public static func shippoCentres(radius: CGFloat) -> [CGPoint] {
        let step = radius / 3
        var centres = [CGPoint.zero]
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            centres.append(CGPoint(x: step * cos(angle), y: step * sin(angle)))
            centres.append(CGPoint(x: 2 * step * cos(angle), y: 2 * step * sin(angle)))
            let between = angle + .pi / 6
            centres.append(CGPoint(x: 3.0.squareRoot() * step * cos(between), y: 3.0.squareRoot() * step * sin(between)))
        }
        return centres
    }

    /// A regular polygon's corners. `rotation` turns the first corner from the positive x axis.
    public static func corners(sides: Int, radius: CGFloat, rotation: CGFloat) -> [CGPoint] {
        guard sides > 0 else { return [] }
        return (0..<sides).map { index in
            let angle = rotation + 2 * .pi * CGFloat(index) / CGFloat(sides)
            return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
    }

    public static func polygon(sides: Int, radius: CGFloat, rotation: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = corners(sides: sides, radius: radius, rotation: rotation)
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    /// A circle that runs clockwise on screen from `start` (the top unless said), so `strokeEnd` draws it
    /// like a brush.
    public static func circle(centre: CGPoint = .zero, radius: CGFloat, start: CGFloat = -.pi / 2) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: centre, radius: radius, startAngle: start, endAngle: start + 2 * .pi, clockwise: false)
        path.closeSubpath()
        return path
    }

    /// One seed circle, drawn from the middle of the figure outwards and round: with a disc over the
    /// middle, the stroke grows out from behind it.
    public static func seedCircle(_ index: Int, radius: CGFloat) -> CGPath {
        let centre = seedCentres(radius: radius)[((index % 6) + 6) % 6]
        return circle(centre: centre, radius: radius * seedShare, start: atan2(-centre.y, -centre.x))
    }

    /// The figure centred on the origin.
    public static func path(for figure: Figure, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        switch figure {
        case .shippo:
            shippoCentres(radius: radius).forEach { path.addPath(circle(centre: $0, radius: radius / 3)) }
            path.addPath(circle(radius: radius))
        case .kagome:
            path.addPath(polygon(sides: 3, radius: radius, rotation: -.pi / 2))
            path.addPath(polygon(sides: 3, radius: radius, rotation: .pi / 2))
            path.addPath(circle(radius: radius))
            path.addPath(circle(radius: radius * 1.06))
        case .compass:
            path.addPath(circle(radius: radius))
            path.addPath(circle(radius: radius * 0.84))
            for mark in 0..<72 {
                let angle = 2 * CGFloat.pi * CGFloat(mark) / 72
                let inner: CGFloat = mark % 6 == 0 ? 0.76 : 0.805
                path.move(to: CGPoint(x: radius * 0.84 * cos(angle), y: radius * 0.84 * sin(angle)))
                path.addLine(to: CGPoint(x: radius * inner * cos(angle), y: radius * inner * sin(angle)))
            }
        case .coin:
            path.addPath(circle(radius: radius))
            path.addPath(circle(radius: radius * coinInnerShare))
            path.addPath(polygon(sides: 4, radius: radius * coinInnerShare, rotation: .pi / 4))
        case .seed:
            seedCentres(radius: radius).forEach { path.addPath(circle(centre: $0, radius: radius * seedShare)) }
            path.addPath(circle(radius: radius))
        }
        return path
    }
}
