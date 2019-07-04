/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import AVFoundation

class QRInputViewController: UIViewController, AdaptiveDesignable {
    var presenter: QRInputPresenterProtocol!

    var qrService: QRCaptureServiceProtocol?

    var logger: LoggerProtocol?

    @IBOutlet private var qrFrameView: QRFrameView!

    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var titleLeading: NSLayoutConstraint!
    @IBOutlet private var titleTralling: NSLayoutConstraint!
    @IBOutlet private var enterCodeBottomConstraint: NSLayoutConstraint!

    private var canProccess: Bool = false

    // MARK: Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        configureService()
        adjustLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        canProccess = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        qrService?.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        qrService?.stop()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        canProccess = true
    }

    private func adjustLayout() {
        titleTop.constant *= designScaleRatio.width
        titleLeading.constant *= designScaleRatio.width
        titleTralling.constant *= designScaleRatio.width

        if isAdaptiveHeightDecreased {
            enterCodeBottomConstraint.constant *= designScaleRatio.height
        }

        var windowSize = qrFrameView.windowSize
        windowSize.width *= designScaleRatio.width
        windowSize.height *= designScaleRatio.width
        qrFrameView.windowSize = windowSize
    }

    private func configureService() {
        qrService = QRCaptureService(matcher: CodeInputViewModel.invitation,
                                     delegate: self)
    }

    private func configureVideoLayer(with captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds

        qrFrameView.frameLayer = videoPreviewLayer
    }

    // MARK: Action

    @IBAction private func actionEnterManual(sender: AnyObject) {
        presenter.activateManualInput()
    }
}

extension QRInputViewController: QRCaptureServiceDelegate {
    func didSetup(captureSession: AVCaptureSession) {
        configureVideoLayer(with: captureSession)
    }

    func didMatchCode(_ service: QRCaptureService) {
        guard canProccess else {
            return
        }

        if let viewModel = service.matcher as? CodeInputViewModel {
            presenter.process(viewModel: viewModel)
        }
    }

    func didReceive(error: Error) {
        presenter.handle(error: error)
    }
}

extension QRInputViewController: InvitationInputViewProtocol {
    func present(error: Error, from view: ControllerBackedProtocol?) -> Bool {
        return true
    }

    func didStartLoading() {
        // override default logic and display nothing for loading
    }

    func didStopLoading() {
        // override default logic and display nothing for loading
    }
}
