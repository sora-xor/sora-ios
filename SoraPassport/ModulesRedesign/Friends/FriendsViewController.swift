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
import Then
import SoraUI
import Anchorage
import SoraFoundation
import SoraUIKit
import SnapKit

final class FriendsViewController: UIViewController {
    
    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.isHidden = true
        return tableView
    }()
    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        view.sora.isHidden = true
        return view
    }()
   
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.referralTitle(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.headline2
        label.numberOfLines = 3
        return label
    }()
    
    private lazy var descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.referralSubtitle(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.paragraphM
        label.numberOfLines = 6
        return label
    }()
    
    private lazy var imageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.archerGirl()
        imageView.sora.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private lazy var gradientView: GradientView = {
        let view = GradientView()
        
        view.startColor = SoramitsuUI.shared.theme.palette.color(.bgSurface)
        view.endColor = SoramitsuUI.shared.theme.palette.color(.bgSurface).withAlphaComponent(0.0)
        
        view.startPoint = CGPoint(x: 0, y: 0.5)
        view.endPoint = CGPoint(x: 1, y: 0.5)
        
        return view
    }()
    
    private lazy var buttonStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.alignment = .fill
        stackView.sora.distribution = .equalSpacing
        stackView.spacing = 8
        return stackView
    }()
    
    private lazy var startInvitingButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.referralStartInviting(preferredLanguages: .currentLocale) ,
                                      fontData: FontType.buttonM ,
                                      textColor: .custom(uiColor: Colors.white100),
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.didSelectAction(.startInvite)
        }
        return button
    }()
    
    private lazy var enterLinkButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.referralEnterLinkTitle(preferredLanguages: .currentLocale) ,
                                      fontData: FontType.buttonM ,
                                      textColor: .accentPrimary ,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimaryContainer
        button.sora.attributedText = title
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.didSelectAction(.enterLink)
        }
        return button
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        return indicator
    }()
    
    
    var presenter: FriendsPresenterProtocol!
    private(set) var contentViewModels: [CellViewModel] = []
    

    // MARK: - Vars

    /// Used to correction the distance to the top of the screen
    private var statusBarHeightCorrection: CGFloat {
        UIApplication.shared.statusBarFrame.size.height + 10
    }

    /// Used to correction the middle position of the pull-up controller
    /// and prevent moving content of the main view on animation to the upper state
    private var navigationBarHeightCorrection: CGFloat {
        statusBarHeightCorrection + (navigationController?.navigationBar.frame.size.height ?? 0)
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupLocalization()
        configureNew()
        
        addCloseButton()
        setupHierarchy()
        setupLayout()
        
        activityIndicator.startAnimating()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }
}

// MARK: - Private Functions

private extension FriendsViewController {
    
    private func setupHierarchy() {
        view.addSubview(tableView)
        view.addSubview(containerView)
        view.addSubview(activityIndicator)
        containerView.addSubviews([imageView, titleLabel, descriptionLabel, buttonStackView])
        
        imageView.addSubview(gradientView)
        
        buttonStackView.addArrangedSubviews([startInvitingButton, enterLinkButton])
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.equalTo(view).offset(16)
            make.centerX.equalTo(view)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(view)
        }
        
        imageView.snp.makeConstraints { make in
            make.top.trailing.equalTo(containerView)
            make.trailing.equalTo(containerView)
            make.height.equalTo(325)
            make.width.equalTo(204)
        }
        
        gradientView.snp.makeConstraints { make in
            make.top.bottom.leading.equalTo(imageView)
            make.trailing.equalTo(imageView).multipliedBy(0.4098)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalTo(containerView).offset(24)
            make.width.equalTo(179)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.equalTo(containerView).offset(24)
            make.width.equalTo(147)
        }
        
        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(24)
            make.leading.equalTo(containerView).offset(24)
            make.centerX.equalTo(containerView)
            make.bottom.equalTo(containerView).offset(-24)
        }
        
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
    }

    func configureNew() {
        setupTableView()
    }

    func setupLocalization() {
        title = R.string.localizable.referralToolbarTitle(preferredLanguages: localizationManager?.preferredLocalizations)
    }

    func setupTableView() {
        tableView.separatorInset = .zero
        tableView.separatorColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = 100
        tableView.register(AvailableInvitationsCell.self,
                           forCellReuseIdentifier: AvailableInvitationsCell.reuseIdentifier)
        tableView.register(TotalRewardsCell.self,
                           forCellReuseIdentifier: TotalRewardsCell.reuseIdentifier)
        tableView.register(RewardRawCell.self,
                           forCellReuseIdentifier: RewardRawCell.reuseIdentifier)
        tableView.register(ReferrerCell.self,
                           forCellReuseIdentifier: ReferrerCell.reuseIdentifier)
        tableView.register(RewardFooterCell.self,
                           forCellReuseIdentifier: RewardFooterCell.reuseIdentifier)
        tableView.register(RewardSeparatorCell.self,
                           forCellReuseIdentifier: RewardSeparatorCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - FriendsViewProtocol

extension FriendsViewController: FriendsViewProtocol {
    func setup(with models: [CellViewModel]) {
        tableView.isHidden = false
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
        containerView.sora.isHidden = true

        contentViewModels = models
        tableView.reloadData()
    }

    func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool) {
        contentViewModels = models

        let indexPaths = updatedIndexs.map { IndexPath(row: $0, section: 0) }

        if isExpanding {
            tableView.insertRows(at: indexPaths, with: .fade)
            tableView.scrollToRow(at: IndexPath(row: models.count - 1, section: 0), at: .bottom, animated: true)
        } else {
            tableView.deleteRows(at: indexPaths, with: .fade)
        }
    }

    func startInvitingScreen(with referrer: String) {
        activityIndicator.isHidden = true
        tableView.isHidden = true
        containerView.sora.isHidden = false

        if !referrer.isEmpty {
            let title = SoramitsuTextItem(text: R.string.localizable.referralYourReferrer(preferredLanguages: .currentLocale),
                                          fontData: FontType.buttonM ,
                                          textColor: .accentPrimary ,
                                          alignment: .center)
            enterLinkButton.sora.attributedText = title
        }
    }

    func showAlert(with text: String, image: UIImage?) {
        let alert = ModalAlertFactory.createAlert(text, image: image)
        present(alert, animated: true, completion: nil)
    }
}

extension FriendsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contentViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = contentViewModels[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: \(viewModel.cellReuseIdentifier)")
        }
        cell.bind(viewModel: contentViewModels[indexPath.row])
        return cell
    }
}

extension FriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Localizable

extension FriendsViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

