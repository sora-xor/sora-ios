/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import AVFoundation

protocol QRMatcherProtocol: class {
    func match(code: String) -> Bool
}

protocol QRCaptureServiceProtocol: class {
    func start()
    func stop()
}

enum QRCaptureServiceError: Error {
    case deviceAccessDeniedPreviously
    case deviceAccessDeniedNow
    case deviceAccessRestricted
}

protocol QRCaptureServiceDelegate: class {
    func didSetup(captureSession: AVCaptureSession)
    func didMatchCode(_ service: QRCaptureService)
    func didReceive(error: Error)
}

class QRCaptureService: NSObject {
    static let processingQueue = DispatchQueue(label: "qr.capture.service.queue")

    private(set) var matcher: QRMatcherProtocol
    private(set) var captureSession: AVCaptureSession?

    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue: DispatchQueue

    init(matcher: QRMatcherProtocol,
         delegate: QRCaptureServiceDelegate? = nil,
         delegateQueue: DispatchQueue = .main) {

        self.matcher = matcher
        self.delegate = delegate
        self.delegateQueue = delegateQueue

        super.init()
    }

    private func configureSessionIfNeeded() throws {
        guard self.captureSession == nil else {
            return
        }

        let device = AVCaptureDevice.devices(for: .video).first { $0.position == .back}

        guard let camera = device else {
            throw QRCaptureServiceError.deviceAccessRestricted
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            throw QRCaptureServiceError.deviceAccessRestricted
        }

        let output = AVCaptureMetadataOutput()

        let captureSession = AVCaptureSession()
        captureSession.addInput(input)
        captureSession.addOutput(output)

        self.captureSession = captureSession

        output.setMetadataObjectsDelegate(self, queue: QRCaptureService.processingQueue)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]

        if self.delegateQueue != QRCaptureService.processingQueue {
            self.delegateQueue.sync {
                self.delegate?.didSetup(captureSession: captureSession)
            }
        } else {
            self.delegate?.didSetup(captureSession: captureSession)
        }
    }

    private func startAuthorizedSession() {
        QRCaptureService.processingQueue.async {
            do {
                try self.configureSessionIfNeeded()
                self.captureSession?.startRunning()
            } catch {
                self.delegateQueue.async {
                    self.delegate?.didReceive(error: error)
                }
            }
        }
    }
}

extension QRCaptureService: QRCaptureServiceProtocol {
    public func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    self.startAuthorizedSession()
                } else {
                    self.delegateQueue.async {
                        self.delegate?.didReceive(error: QRCaptureServiceError.deviceAccessDeniedNow)
                    }
                }
            }
        case .denied:
            delegateQueue.async {
                self.delegate?.didReceive(error: QRCaptureServiceError.deviceAccessDeniedPreviously)
            }
        case .restricted:
            delegateQueue.async {
                self.delegate?.didReceive(error: QRCaptureServiceError.deviceAccessRestricted)
            }
        @unknown default:
            break
        }
    }

    func stop() {
        QRCaptureService.processingQueue.async {
            self.captureSession?.stopRunning()
        }
    }
}

extension QRCaptureService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        guard let possibleCode = metadata.stringValue else {
            return
        }

        if matcher.match(code: possibleCode), let delegate = delegate {
            delegateQueue.async {
                delegate.didMatchCode(self)
            }
        }
    }
}
