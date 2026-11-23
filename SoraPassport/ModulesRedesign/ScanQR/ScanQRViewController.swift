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
import SoraUI
import AVFoundation

protocol ScanQRViewProtocol: ControllerBackedProtocol, AdaptiveDesignable, ApplicationSettingsPresentable, AlertPresentable {
    func didReceive(session: AVCaptureSession)
    func presentAlert(title: String)
    func showCameraUnavailable()
    func showPhotoAccess(_ available: Bool)
}

extension ScanQRViewProtocol {
    func showCameraUnavailable() {}
    func showPhotoAccess(_ available: Bool) {}
}

final class ScanQRViewController: SoramitsuViewController {

    private let qrFrameView: CameraFrameView = {
        let frame = CameraFrameView()
        frame.translatesAutoresizingMaskIntoConstraints = false
        frame.windowPosition = CGPoint(x: 0.5, y: 0.5)
        frame.fillColor = .clear
        frame.backgroundColor = WalletUX.surface
        frame.layer.cornerRadius = 24
        frame.layer.cornerCurve = .continuous
        frame.layer.borderWidth = 2
        frame.layer.borderColor = WalletUX.accent.cgColor
        frame.clipsToBounds = true
        return frame
    }()

    private let cameraIcon: UIImageView = {
        let icon = UIImageView(image: UIImage(systemName: "camera.viewfinder"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = WalletUX.accent
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.isAccessibilityElement = false
        return icon
    }()

    private let cameraStatus = SoramitsuLabel()
    private let photosStatus = SoramitsuLabel()
    private let cameraPlaceholder = UIStackView()

    lazy var closeButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 44, height: 44))
        button.sora.image = R.image.wallet.cross()
        button.sora.tintColor = .accentPrimary
        button.sora.backgroundColor = .bgSurface
        button.sora.cornerRadius = .circle
        button.accessibilityLabel = R.string.localizable.commonClose(preferredLanguages: .currentLocale)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in self?.close() }
        return button
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.headline3
        label.sora.dynamicTextStyle = .headline
        label.sora.numberOfLines = 0
        label.sora.text = R.string.localizable.commonScanQr(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var galleryButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.leftImage = UIImage(systemName: "photo.on.rectangle")
        button.sora.tintColor = .fgInverted
        button.sora.title = R.string.localizable.commonUploadFromLibrary(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.viewModel.activateImport()
        }
        return button
    }()

    var viewModel: ScanQRViewModelProtocol
    private let previewSpace = UILayoutGuide()
    private lazy var preferredSide = qrFrameView.widthAnchor.constraint(equalToConstant: 0)

    init(viewModel: ScanQRViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let size = view.bounds.size
        preferredSide.constant = WalletDisplay.canvas(for: view).kind == .phone
            ? max(0, size.width - 48)
            : Self.scanWindowSide(viewSize: size, bottomInset: view.safeAreaInsets.bottom)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        viewModel.prepareDismiss()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.prepareAppearance()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        viewModel.handleDismiss()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.handleAppearance()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .bgPage
        view.addLayoutGuide(previewSpace)
        view.addSubviews(qrFrameView, closeButton, titleLabel, photosStatus, galleryButton)
        for label in [cameraStatus, photosStatus] {
            label.sora.font = FontType.textS
            label.sora.dynamicTextStyle = .footnote
            label.sora.textColor = .fgSecondary
            label.sora.alignment = .center
            label.sora.numberOfLines = 0
            label.isHidden = true
        }
        cameraStatus.sora.text = WalletUX.text("Camera unavailable")
        cameraPlaceholder.axis = .vertical
        cameraPlaceholder.alignment = .center
        cameraPlaceholder.spacing = 8
        cameraPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        cameraPlaceholder.addArrangedSubview(cameraIcon)
        cameraPlaceholder.addArrangedSubview(cameraStatus)
        qrFrameView.addSubview(cameraPlaceholder)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide
        let top = previewSpace.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12)
        top.priority = UILayoutPriority(999)
        preferredSide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            titleLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            previewSpace.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            previewSpace.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            previewSpace.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 12),
            top,
            previewSpace.bottomAnchor.constraint(equalTo: photosStatus.topAnchor, constant: -8),
            qrFrameView.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            qrFrameView.centerYAnchor.constraint(equalTo: previewSpace.centerYAnchor),
            qrFrameView.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -32),
            qrFrameView.heightAnchor.constraint(lessThanOrEqualTo: previewSpace.heightAnchor),
            qrFrameView.heightAnchor.constraint(equalTo: qrFrameView.widthAnchor), preferredSide,

            cameraIcon.widthAnchor.constraint(equalToConstant: 44),
            cameraIcon.heightAnchor.constraint(equalTo: cameraIcon.widthAnchor),
            cameraPlaceholder.centerXAnchor.constraint(equalTo: qrFrameView.centerXAnchor),
            cameraPlaceholder.centerYAnchor.constraint(equalTo: qrFrameView.centerYAnchor),
            cameraPlaceholder.widthAnchor.constraint(lessThanOrEqualTo: qrFrameView.widthAnchor, constant: -16),
            photosStatus.leadingAnchor.constraint(equalTo: galleryButton.leadingAnchor),
            photosStatus.trailingAnchor.constraint(equalTo: galleryButton.trailingAnchor),
            photosStatus.bottomAnchor.constraint(equalTo: galleryButton.topAnchor, constant: -8),
            galleryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            galleryButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16)
        ])
        WalletDisplay.pinReadable(galleryButton, width: safe.widthAnchor, centerX: safe.centerXAnchor, margin: 24)
    }

    static func scanWindowSide(viewSize: CGSize, bottomInset: CGFloat) -> CGFloat {
        let room = 2 * (viewSize.height * 0.53 - bottomInset - 164)
        return max(200, min(min(viewSize.width, viewSize.height) - 48, 392, room)).rounded(.down)
    }

    private func configureVideoLayer(with captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = qrFrameView.bounds
        cameraPlaceholder.isHidden = true

        qrFrameView.frameLayer = videoPreviewLayer
        LitMotion.rise(qrFrameView, by: 5)
    }
}

extension ScanQRViewController: ScanQRViewProtocol {
    func showCameraUnavailable() {
        cameraStatus.isHidden = false
    }

    func showPhotoAccess(_ available: Bool) {
        photosStatus.isHidden = available
        photosStatus.sora.text = available ? nil : WalletUX.text("Photos unavailable")
        if !available { UIAccessibility.post(notification: .announcement, argument: photosStatus.text) }
    }

    func didReceive(session: AVCaptureSession) {
        configureVideoLayer(with: session)
    }
    
    func presentAlert(title: String) {
        present(message: nil,
                title: title,
                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                from: self)
    }
}
