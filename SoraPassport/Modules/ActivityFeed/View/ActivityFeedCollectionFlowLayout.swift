/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class ActivityFeedCollectionFlowLayout: UICollectionViewFlowLayout {
    private(set) var decoratorAttributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private(set) var decorationViewKind: String?

    var shouldDisplayDecoration: Bool = true {
        didSet {
            if shouldDisplayDecoration != oldValue {
                invalidateLayout()
            }
        }
    }

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

        guard let collectionView = collectionView else {
            return
        }

        guard let dataSource = collectionView.dataSource else {
            return
        }

        guard let delegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout else {
            return
        }

        let sectionCount = dataSource.numberOfSections?(in: collectionView) ?? 1

        guard sectionCount > 1 else {
            return
        }

        var currentYOrigin: CGFloat = 0.0

        for section in 0..<sectionCount {
            let headerSize = delegate.collectionView?(collectionView,
                                                      layout: self,
                                                      referenceSizeForHeaderInSection: section) ?? headerReferenceSize

            currentYOrigin += headerSize.height

            let itemsCount = dataSource.collectionView(collectionView, numberOfItemsInSection: section)

            var sectionHeight: CGFloat = 0.0
            var separatorPositions: [CGFloat] = []
            var itemWidth: CGFloat = 0.0

            for row in 0..<itemsCount {
                let indexPath = IndexPath(item: row, section: section)
                let rowSize = delegate.collectionView?(collectionView,
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
                                                   y: currentYOrigin,
                                                   width: itemWidth,
                                                   height: sectionHeight)
                decoratorAttributes.zIndex = -1

                decoratorAttributesDictionary[decoratorAttributes.indexPath] = decoratorAttributes
            }

            currentYOrigin += sectionHeight
        }
    }
}
