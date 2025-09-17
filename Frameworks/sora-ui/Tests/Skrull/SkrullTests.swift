/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import SoraUI

class SkrullTests: XCTestCase {
    func testSkeletonInitialization() {
        let skrullSize = CGSize(width: 300.0, height: 300.0)

        let skeletonPosition = CGPoint(x: 0.5, y: 0.5)
        let skeletonSize = CGSize(width: 0.5, height: 0.5)

        let cornerRadii = CGSize(width: 10.0, height: 10.0)
        let roundingMode: UIRectCorner = UIRectCorner.topLeft.union(.topRight)

        let startColor = UIColor.red
        let endColor = UIColor.green

        let skrull = Skrull(size: skrullSize,
                            decorations: [],
                            skeletons: [
                                SingleSkeleton(position: skeletonPosition, size: skeletonSize)
                                    .round(cornerRadii, mode: roundingMode)
                                    .fillStart(startColor)
                                    .fillEnd(endColor)
            ]
        )

        XCTAssertEqual(skrullSize, skrull.size)

        guard let resultSkeleton = skrull.skeletons.first else {
            XCTFail()
            return
        }

        XCTAssertEqual(skeletonPosition, resultSkeleton.position)
        XCTAssertEqual(skeletonSize, resultSkeleton.size)
        XCTAssertEqual(cornerRadii, resultSkeleton.cornerRadii)
        XCTAssertEqual(roundingMode, resultSkeleton.cornerRoundingMode)
        XCTAssertEqual(startColor, resultSkeleton.startColor)
        XCTAssertEqual(endColor, resultSkeleton.endColor)

        XCTAssertNoThrow(skrull.build())
    }

    func testMultilineInitialization() {
        let skrullSize = CGSize(width: 300.0, height: 300.0)

        let skeletonOrigin = CGPoint(x: 0.5, y: 0.5)
        let skeletonSize = CGSize(width: 0.5, height: 0.5)

        let cornerRadii = CGSize(width: 10.0, height: 10.0)
        let roundingMode: UIRectCorner = UIRectCorner.topLeft.union(.topRight)

        let startColor = UIColor.red
        let endColor = UIColor.green

        let numberOfLines: UInt8 = 10
        let spacing: CGFloat = 0.05
        let lastLineFraction: CGFloat = 0.5

        let skrull = Skrull(size: skrullSize,
                            decorations: [],
                            skeletons: [
                                MultilineSkeleton(startLinePosition: skeletonOrigin,
                                                  lineSize: skeletonSize,
                                                  count: numberOfLines,
                                                  spacing: spacing)
                                    .round(cornerRadii, mode: roundingMode)
                                    .fillStart(startColor)
                                    .fillEnd(endColor)
                                    .lastLine(fraction: lastLineFraction)
            ]
        )

        XCTAssertEqual(skrullSize, skrull.size)
        XCTAssertEqual(skrull.skeletons.count, Int(numberOfLines))

        skrull.skeletons.forEach { (skeleton) in
            XCTAssertEqual(cornerRadii, skeleton.cornerRadii)
            XCTAssertEqual(roundingMode, skeleton.cornerRoundingMode)
            XCTAssertEqual(startColor, skeleton.startColor)
            XCTAssertEqual(endColor, skeleton.endColor)
        }

        XCTAssertNoThrow(skrull.build())
    }

    func testDecorationInitialization() {
        let skrullSize = CGSize(width: 300.0, height: 300.0)

        let decorationPosition = CGPoint(x: 0.5, y: 0.5)
        let decorationSize = CGSize(width: 1.0, height: 1.0)

        let cornerRadii = CGSize(width: 10.0, height: 10.0)
        let roundingMode: UIRectCorner = UIRectCorner.topLeft.union(.topRight)

        let fillColor = UIColor.red
        let strokeColor = UIColor.green
        let strokeWidth: CGFloat = 2.0
        let shadowColor: UIColor = UIColor.lightGray.withAlphaComponent(0.6)
        let shadowOffset: CGSize = CGSize(width: 2.0, height: 4.0)
        let shadowRadius: CGFloat = 10.0

        let skrull = Skrull(size: skrullSize,
                            decorations: [
                                SingleDecoration(position: decorationPosition, size: decorationSize)
                                    .round(cornerRadii, mode: roundingMode)
                                    .fill(fillColor)
                                    .stroke(strokeColor, width: strokeWidth)
                                    .shadow(shadowColor, offset: shadowOffset, radius: shadowRadius)
            ],
                            skeletons: [])

        XCTAssertEqual(skrullSize, skrull.size)

        guard let resultDecoration = skrull.decorations.first else {
            XCTFail()
            return
        }

        XCTAssertEqual(decorationPosition, resultDecoration.position)
        XCTAssertEqual(decorationSize, resultDecoration.size)
        XCTAssertEqual(cornerRadii, resultDecoration.cornerRadii)
        XCTAssertEqual(roundingMode, resultDecoration.cornerRoundingMode)
        XCTAssertEqual(fillColor, resultDecoration.fillColor)
        XCTAssertEqual(strokeColor, resultDecoration.strokeColor)
        XCTAssertEqual(strokeWidth, resultDecoration.strokeWidth)
        XCTAssertEqual(shadowColor, resultDecoration.shadowColor)
        XCTAssertEqual(shadowOffset, resultDecoration.shadowOffset)
        XCTAssertEqual(shadowRadius, resultDecoration.shadowRadius)

        XCTAssertNoThrow(skrull.build())
    }
}
