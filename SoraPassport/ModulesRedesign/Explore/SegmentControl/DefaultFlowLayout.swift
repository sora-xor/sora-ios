// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
