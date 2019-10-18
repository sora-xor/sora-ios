/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class ActivityFeedCollectionFlowLayout: UICollectionViewFlowLayout {
    private(set) var decoratorAttributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private(set) var decorationViewKind: String?

    var shouldDisplayDecoration: Bool = true

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributesList = super.layoutAttributesForElements(in: rect) ?? [UICollectionViewLayoutAttributes]()

        decoratorAttributesDictionary.forEach { (_, attributes) in
            if attributes.frame.intersects(rect) {
                attributesList.append(attributes)
            }
        }

        return attributesList
    }

    override func layoutAttributesForDecorationView(ofKind elementKind: String,
                                                    at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard decorationViewKind == elementKind else {
            return nil
        }

        return decoratorAttributesDictionary[indexPath]
    }

    override func register(_ nib: UINib?, forDecorationViewOfKind elementKind: String) {
        decorationViewKind = elementKind

        super.register(nib, forDecorationViewOfKind: elementKind)
    }

    override func register(_ viewClass: AnyClass?, forDecorationViewOfKind elementKind: String) {
        decorationViewKind = elementKind

        super.register(viewClass, forDecorationViewOfKind: elementKind)
    }

    override func prepare() {
        super.prepare()

        decoratorAttributesDictionary = [:]

        if shouldDisplayDecoration {
            updateDecorationAttributes()
        }
    }

    private func updateDecorationAttributes() {
        guard let decorationViewKind = decorationViewKind else {
            return
        }

        guard
            let collectionView = collectionView,
            let dataSource = collectionView.dataSource else {
            return
        }

        let sectionCount = dataSource.numberOfSections?(in: collectionView) ?? 1

        guard sectionCount > 1 else {
            return
        }

        var verticalPosition: CGFloat = 0.0

        for section in 0..<sectionCount {
            verticalPosition = configureDecorationAttributes(for: section,
                                                             decorationViewKind: decorationViewKind,
                                                             collectionView: collectionView,
                                                             verticalPosition: verticalPosition)
        }
    }

    private func configureDecorationAttributes(for section: Int,
                                               decorationViewKind: String,
                                               collectionView: UICollectionView,
                                               verticalPosition: CGFloat) -> CGFloat {

        let layoutDelegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout

        var newVerticalPosition = verticalPosition

        let optionalHeaderSize = layoutDelegate?.collectionView?(collectionView,
                                                                 layout: self,
                                                                 referenceSizeForHeaderInSection: section)

        newVerticalPosition += optionalHeaderSize?.height ?? headerReferenceSize.height

        let itemsCount = collectionView.dataSource?.collectionView(collectionView, numberOfItemsInSection: section) ?? 0

        var sectionHeight: CGFloat = 0.0
        var separatorPositions: [CGFloat] = []
        var itemWidth: CGFloat = 0.0

        for row in 0..<itemsCount {
            let indexPath = IndexPath(item: row, section: section)
            let rowSize = layoutDelegate?.collectionView?(collectionView,
                                                          layout: self,
                                                          sizeForItemAt: indexPath) ?? itemSize

            sectionHeight += rowSize.height

            if row < itemsCount - 1 {
                separatorPositions.append(sectionHeight)
            } else {
                itemWidth = rowSize.width
            }
        }

        if section > 0 {
            let indexPath = IndexPath(item: 0, section: section)
            let decoratorAttributes = ActivityFeedDecoratorAttributes(forDecorationViewOfKind: decorationViewKind,
                                                                      with: indexPath)
            decoratorAttributes.separatorVerticalPositions = separatorPositions
            decoratorAttributes.frame = CGRect(x: collectionViewContentSize.width / 2.0 - itemWidth / 2.0,
                                               y: newVerticalPosition,
                                               width: itemWidth,
                                               height: sectionHeight)
            decoratorAttributes.zIndex = -1

            decoratorAttributesDictionary[decoratorAttributes.indexPath] = decoratorAttributes
        }

        newVerticalPosition += sectionHeight

        return newVerticalPosition
    }
}
