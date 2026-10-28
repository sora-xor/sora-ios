// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit

final class DefaultFlowLayout: UICollectionViewFlowLayout {
    // MARK: - Constants

    private enum Constants {
        static let spacing: CGFloat = 16
    }

    // MARK: - Private Properties

    private var contentOffset: CGPoint = .zero

    private var currentContentOffset: CGPoint {
        collectionView?.contentOffset ?? .zero
    }

    private var bounds: CGRect {
        collectionView?.bounds ?? .zero
    }

    private var numberOfItems: Int {
        collectionView?.numberOfItems(inSection: 0) ?? 0
    }

    // MARK: - UICollectionViewFlowLayout

    override func prepare() {
        super.prepare()
        configure()
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity _: CGPoint
    ) -> CGPoint {
        let proposedRect = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: bounds.width,
            height: bounds.height
        )

        guard let layoutAttributes = super.layoutAttributesForElements(in: proposedRect) else {
            return .zero
        }

        // find nearest cell
        var offset = CGFloat.greatestFiniteMagnitude
        var targetIndex = 0
        let horizontalCenter = proposedContentOffset.x + bounds.width / 2
        for attributes in layoutAttributes {
            if (attributes.center.x - horizontalCenter).magnitude < offset.magnitude {
                offset = attributes.center.x - horizontalCenter
                targetIndex = attributes.indexPath.item
            }
        }

        let targetContentOffset = getContentOffset(for: targetIndex)
        guard targetContentOffset != contentOffset else {
            DispatchQueue.main.async {
                self.collectionView?.setContentOffset(targetContentOffset, animated: true)
            }
            return currentContentOffset
        }

        contentOffset = targetContentOffset
        return targetContentOffset
    }

    // MARK: - Private Methods

    private func configure() {
        scrollDirection = .horizontal
        minimumLineSpacing = Constants.spacing
        configureItemSize()
    }

    private func configureItemSize() {
        let width: CGFloat = bounds.width
        let height = bounds.height
        itemSize = CGSize(width: width, height: height)
    }

    private func getContentOffset(for item: Int) -> CGPoint {
        var offsetX = itemSize.width * CGFloat(item)

        if item == numberOfItems - 1 {
            offsetX += Constants.spacing
        }

        return CGPoint(x: offsetX, y: 0)
    }
}
