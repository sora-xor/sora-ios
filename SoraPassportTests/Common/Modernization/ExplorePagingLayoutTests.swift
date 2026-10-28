// SPDX-License-Identifier: BSD-4-Clause
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class ExplorePagingLayoutTests: XCTestCase {
  private func make(_ count: Int = 4, width: CGFloat = 320) -> (
    UICollectionView, DefaultFlowLayout, PagingLayoutSource
  ) {
    let layout = DefaultFlowLayout()
    let source = PagingLayoutSource(count: count)
    let collection = UICollectionView(
      frame: CGRect(x: 0, y: 0, width: width, height: 200), collectionViewLayout: layout)
    collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
    collection.dataSource = source
    collection.reloadData()
    collection.layoutIfNeeded()
    layout.prepare()
    return (collection, layout, source)
  }
  func testPagesUseTheEntireViewport() {
    let (c, l, s) = make()
    XCTAssertEqual(l.itemSize, c.bounds.size)
    XCTAssertEqual(l.scrollDirection, .horizontal)
    withExtendedLifetime(s) {}
  }
  func testPagesKeepTheDocumentedSixteenPointGap() {
    let (_, l, s) = make()
    XCTAssertEqual(l.minimumLineSpacing, 16)
    withExtendedLifetime(s) {}
  }
  func testFirstPageSnapsToItsLeadingEdge() {
    let (c, l, s) = make()
    let point = l.targetContentOffset(
      forProposedContentOffset: CGPoint(x: 5, y: 0), withScrollingVelocity: .zero)
    XCTAssertEqual(point.x, 0)
    withExtendedLifetime((c, s)) {}
  }
  func testSecondPageSnapIncludesItsInterPageGap() {
    let (c, l, s) = make()
    let point = l.targetContentOffset(
      forProposedContentOffset: CGPoint(x: 330, y: 0), withScrollingVelocity: .zero)
    XCTAssertEqual(point.x, 336)
    withExtendedLifetime((c, s)) {}
  }
  func testThirdPageSnapIncludesEveryPrecedingGap() {
    let (c, l, s) = make()
    let point = l.targetContentOffset(
      forProposedContentOffset: CGPoint(x: 670, y: 0), withScrollingVelocity: .zero)
    XCTAssertEqual(point.x, 672)
    withExtendedLifetime((c, s)) {}
  }
  func testLastPageSnapAlignsWithTheContentBoundary() {
    let (c, l, s) = make()
    let point = l.targetContentOffset(
      forProposedContentOffset: CGPoint(x: 1005, y: 0), withScrollingVelocity: .zero)
    XCTAssertEqual(point.x, 1008)
    XCTAssertEqual(point.x, c.contentSize.width - c.bounds.width)
    withExtendedLifetime(s) {}
  }
  func testSinglePageNeverAddsAnUnnecessaryGap() {
    let (c, l, s) = make(1)
    let point = l.targetContentOffset(forProposedContentOffset: .zero, withScrollingVelocity: .zero)
    XCTAssertEqual(point, .zero)
    withExtendedLifetime((c, s)) {}
  }
  func testEmptyCollectionHasNoScrollDestination() {
    let (c, l, s) = make(0)
    XCTAssertEqual(
      l.targetContentOffset(forProposedContentOffset: .zero, withScrollingVelocity: .zero), .zero)
    withExtendedLifetime((c, s)) {}
  }
  func testLayoutResizingRecalculatesPageDimensions() {
    let (c, l, s) = make()
    c.frame.size = CGSize(width: 480, height: 300)
    l.invalidateLayout()
    l.prepare()
    XCTAssertEqual(l.itemSize, CGSize(width: 480, height: 300))
    withExtendedLifetime(s) {}
  }
  func testSnapAlwaysKeepsTheVerticalOffsetAtZero() {
    let (c, l, s) = make()
    let point = l.targetContentOffset(
      forProposedContentOffset: CGPoint(x: 330, y: 75), withScrollingVelocity: CGPoint(x: 0, y: 9))
    XCTAssertEqual(point.y, 0)
    withExtendedLifetime((c, s)) {}
  }
}
private final class PagingLayoutSource: NSObject, UICollectionViewDataSource {
  let count: Int
  init(count: Int) { self.count = count }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  { count }
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell
  { collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) }
}
