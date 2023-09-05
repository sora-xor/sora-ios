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

import UIKit
import SoraUIKit
import SoraFoundation
import Combine

final class EditViewModel {
    
    weak var view: EditViewControllerProtocol?
    @Published var snapshot: EditViewSnapshot = EditViewSnapshot()
    var snapshotPublisher: Published<EditViewSnapshot>.Publisher { $snapshot }
    
    var editViewService: EditViewServiceProtocol
    var completion: (() -> Void)?
    
    init(editViewService: EditViewServiceProtocol,
         completion: (() -> Void)?) {
        self.editViewService = editViewService
        self.completion = completion
    }
}

extension EditViewModel: EditViewModelProtocol {
    
    func reloadView(with section: EnabledSection?) {
        guard let section = section else {
            snapshot = createSnapshot(with: contentSection())
            return
        }
        
        snapshot = createSnapshot(with: section)
    }
    
    private func createSnapshot(with section: EnabledSection) -> EditViewSnapshot {
        var snapshot = EditViewSnapshot()
        
        let sections = [ section ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> EnabledSection {
        let item = EnabledItem()
        
        item.enabledViewModels = editViewService.viewModels

        item.onTap = { [weak self, weak item] id in
            guard
                let item = item,
                let viewModel = item.enabledViewModels.first(where: { $0.id == id })
            else { return }
            
            switch viewModel.state {
            case .unselected:
                return
            case .selected:
                viewModel.state = .disabled
                ApplicationConfig.shared.enabledCardIdentifiers.removeAll(where: { $0 == viewModel.id })
            case .disabled:
                viewModel.state = .selected
                ApplicationConfig.shared.enabledCardIdentifiers.append(viewModel.id)
            }

            self?.reloadView(with: EnabledSection(items: [.enabled(item)]))
        }
        
        return EnabledSection(items: [.enabled(item)])
    }
}
