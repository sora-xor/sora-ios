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

import UIKit
import SoraUI

class SkeletonCollectionViewCell: UICollectionViewCell {

    private(set) var viewModel: SkeletonCellViewModel?
    private(set) var skrullableView: SkrullableView?

    func present(for viewModel: SkeletonCellViewModel) {
        if viewModel != self.viewModel {
            self.viewModel = viewModel

            self.skrullableView?.removeFromSuperview()
            self.skrullableView = nil

            if let skrullableView = configureSkeleton(for: viewModel) {
                skrullableView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(skrullableView)

                skrullableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
                skrullableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
                skrullableView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
                skrullableView.heightAnchor.constraint(equalToConstant: viewModel.contentSize.height).isActive = true

                skrullableView.startSkrulling()

                self.skrullableView = skrullableView
            }
        }
    }

    func configureSkeleton(for viewModel: SkeletonCellViewModel) -> SkrullableView? {
        return nil
    }
}
