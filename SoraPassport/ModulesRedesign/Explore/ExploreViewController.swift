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
import SoraUIKit
import SoraKeystore
import SoraFoundation
import Combine

final class ExploreViewController: SoramitsuViewController, ControllerBackedProtocol {
    
    var viewModels: [ExplorePageViewModelProtocol]
    var searchViewModel: ExplorePageViewModelProtocol
    var wireframe: ExploreWireframeProtocol?
    var showPredictionMarkets: (@MainActor () -> Void)?
    let debouncer = Debouncer(interval: 0.8)
    
    private let searchController = UISearchController(searchResultsController: nil)

    lazy var scrollDelegate: ExploreScrollViewDelegate = {
        let delegate = ExploreScrollViewDelegate()
        delegate.delegate = segmentViewModel
        return delegate
    }()
    
    lazy var segmentViewModel: TitleSegmentControlViewModel = {
        let viewModel = TitleSegmentControlViewModel()
        viewModel.delegate = self
        return viewModel
    }()
    
    private lazy var segmentView: TitleSegmentControl = {
        let view = TitleSegmentControl(frame: .zero)
        view.viewModel = segmentViewModel
        return view
    }()
    
    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.delegate = scrollDelegate
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var searchView: ExplorePageView = {
        let view = ExplorePageView()
        view.isHidden = true
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        let slides = createSlides()
        setupSlideScrollView(slides: slides)
        searchView.viewModel = searchViewModel
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = CGSize(width: view.frame.width * CGFloat(3), height: scrollView.frame.size.height)
    }
    
    init(viewModels: [ExplorePageViewModelProtocol], searchViewModel: ExplorePageViewModelProtocol) {
        self.viewModels = viewModels
        self.searchViewModel = searchViewModel
    }

    private func setupView() {
        updateRightButtonItem()
        searchController.searchBar.placeholder = R.string.localizable.search(preferredLanguages: .currentLocale)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        updateSearchBar()
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Clear: the tab bar controller draws the aurora behind every tab.
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(scrollView)
        view.addSubview(segmentView)
        view.addSubview(searchView)
        
        NSLayoutConstraint.activate([
            segmentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            segmentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            segmentView.heightAnchor.constraint(equalToConstant: 35),
            
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: segmentView.bottomAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            searchView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            searchView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        SoramitsuUI.updates.addObserver(self)
    }

    func createSlides() -> [ExplorePageView] {
        let assetsPage = ExplorePageView()
        let poolsPage = ExplorePageView()
        let farmsPage = ExplorePageView()
        return [assetsPage, poolsPage, farmsPage]
    }
    
    func setupSlideScrollView(slides : [ExplorePageView]) {
        scrollView.isPagingEnabled = true
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        
        scrollView.addSubview(stackView)
        
        stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        
        for i in 0 ..< slides.count {
            slides[i].viewModel = viewModels[i]
            
            stackView.addArrangedSubview(slides[i])
            slides[i].heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
            slides[i].widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        }
    }
    
    private func updateRightButtonItem() {
        let cratePoolButton = UIBarButtonItem(title: R.string.localizable.exploreCreatePool(preferredLanguages: .currentLocale),
                                              style: .plain,
                                              target: self,
                                              action: #selector(createPool))
        // Styled by the bar appearance (`NeonChrome`), which follows the
        // theme: no red text on bars.

        navigationItem.rightBarButtonItem = cratePoolButton
        if ProductSurfacePolicy.showsPolkamarkt,
           SettingsManager.shared.polkamarktEnabled {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: WalletUX.text("Prediction markets"), style: .plain,
                target: self, action: #selector(openPredictionMarkets))
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }
    
    @objc private func openPredictionMarkets() {
        guard
            ProductSurfacePolicy.showsPolkamarkt,
            SettingsManager.shared.polkamarktEnabled
        else { return }
        showPredictionMarkets?()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRightButtonItem()
    }

    @objc
    private func createPool() {
        wireframe?.showLiquidity(on: self)
    }
    
    private func updateSearchBar() {
        let color = SoramitsuUI.shared.theme == .light ? UIColor(hex: "#3C3C43", alpha: 0.6) : .white
        
        searchController.searchBar.searchTextField.attributedPlaceholder = NSAttributedString.init(
            string: R.string.localizable.search(),
            attributes: [ NSAttributedString.Key.foregroundColor: color]
        )
        searchController.searchBar.setLeftImage(R.image.magnifyingglass()!, with: 8, tintColor: color)
        searchController.searchBar.searchTextField.textColor = color
    }
}

extension ExploreViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        navigationItem.title = R.string.localizable.commonExplore(preferredLanguages: languages)
    }
}

extension ExploreViewController: TitleSegmentControlViewModelDelegate {
    func changeCurrentPage(to number: Int) {
        let pageWidth = scrollView.bounds.width
        let offset = number * Int(pageWidth)
        
        UIView.animate(withDuration: 0.33, animations: { [weak self] in
          self?.scrollView.contentOffset.x = CGFloat(offset)
        })
    }
}

extension ExploreViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        debouncer.perform { [weak self] in
            self?.searchViewModel.searchTextChanged(with: searchController.searchBar.text?.lowercased() ?? "")
        }
    }
}

extension ExploreViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        searchView.isHidden = false
        segmentView.isHidden = true
        scrollView.isHidden = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        searchView.isHidden = true
        segmentView.isHidden = false
        scrollView.isHidden = false
    }
}

extension ExploreViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        updateSearchBar()
        updateRightButtonItem()
    }
}
