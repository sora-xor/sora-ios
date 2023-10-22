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
import AVFoundation

protocol WalletQRMatcherProtocol: AnyObject {
    func match(code: String) -> Bool
}

protocol WalletQRCaptureServiceProtocol: AnyObject {
    var delegate: WalletQRCaptureServiceDelegate? { get set }
    var delegateQueue: DispatchQueue { get set }

    func start()
    func stop()
}

protocol WalletQRCaptureServiceFactoryProtocol {
    func createService(with matcher: WalletQRMatcherProtocol,
                       delegate: WalletQRCaptureServiceDelegate?,
                       delegateQueue: DispatchQueue?) -> WalletQRCaptureServiceProtocol
}

enum WalletQRCaptureServiceError: Error {
    case deviceAccessDeniedPreviously
    case deviceAccessDeniedNow
    case deviceAccessRestricted
}

protocol WalletQRCaptureServiceDelegate: AnyObject {
    func qrCapture(service: WalletQRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession)
    func qrCapture(service: WalletQRCaptureServiceProtocol, didMatch code: String)
    func qrCapture(service: WalletQRCaptureServiceProtocol, didFailMatching code: String)
    func qrCapture(service: WalletQRCaptureServiceProtocol, didReceive error: Error)
}

final class WalletQRCaptureServiceFactory: WalletQRCaptureServiceFactoryProtocol {
    func createService(with matcher: WalletQRMatcherProtocol,
                       delegate: WalletQRCaptureServiceDelegate? = nil,
                       delegateQueue: DispatchQueue?) -> WalletQRCaptureServiceProtocol {
        return WalletQRCaptureService(matcher: matcher,
                                      delegate: delegate,
                                      delegateQueue: delegateQueue)
    }
}

final class WalletQRCaptureService: NSObject {
    static let processingQueue = DispatchQueue(label: "qr.capture.service.queue")

    private(set) var matcher: WalletQRMatcherProtocol
    private(set) var captureSession: AVCaptureSession?

    weak var delegate: WalletQRCaptureServiceDelegate?
    var delegateQueue: DispatchQueue

    init(matcher: WalletQRMatcherProtocol,
         delegate: WalletQRCaptureServiceDelegate?,
         delegateQueue: DispatchQueue? = nil) {

        self.matcher = matcher
        self.delegate = delegate
        self.delegateQueue = delegateQueue ?? WalletQRCaptureService.processingQueue

        super.init()
    }

    private func configureSessionIfNeeded() throws {
        guard self.captureSession == nil else {
            return
        }

        let device = AVCaptureDevice.devices(for: .video).first { $0.position == .back}

        guard let camera = device else {
            throw WalletQRCaptureServiceError.deviceAccessRestricted
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            throw WalletQRCaptureServiceError.deviceAccessRestricted
        }

        let output = AVCaptureMetadataOutput()

        let captureSession = AVCaptureSession()
        captureSession.addInput(input)
        captureSession.addOutput(output)

        self.captureSession = captureSession

        output.setMetadataObjectsDelegate(self, queue: WalletQRCaptureService.processingQueue)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    }

    private func startAuthorizedSession() {
        WalletQRCaptureService.processingQueue.async {
            do {
                try self.configureSessionIfNeeded()

                if let captureSession = self.captureSession {
                    captureSession.startRunning()

                    self.notifyDelegateWithCreation(of: captureSession)
                }
            } catch {
                self.notifyDelegate(with: error)
            }
        }
    }

    private func notifyDelegate(with error: Error) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didReceive: error)
        }
    }

    private func notifyDelegateWithCreation(of captureSession: AVCaptureSession) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didSetup: captureSession)
        }
    }

    private func notifyDelegateWithSuccessMatching(of code: String) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didMatch: code)
        }
    }

    private func notifyDelegateWithFailedMatching(of code: String) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didFailMatching: code)
        }
    }

    private func run(in queue: DispatchQueue, block: @escaping () -> Void) {
        if delegateQueue != WalletQRCaptureService.processingQueue {
            delegateQueue.async {
                block()
            }
        } else {
            block()
        }
    }
}

extension WalletQRCaptureService: WalletQRCaptureServiceProtocol {
    public func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    self.startAuthorizedSession()
                } else {
                    self.notifyDelegate(with: WalletQRCaptureServiceError.deviceAccessDeniedNow)
                }
            }
        case .denied:
            notifyDelegate(with: WalletQRCaptureServiceError.deviceAccessDeniedPreviously)
        case .restricted:
            notifyDelegate(with: WalletQRCaptureServiceError.deviceAccessRestricted)
        @unknown default:
            break
        }
    }

    func stop() {
        WalletQRCaptureService.processingQueue.async {
            self.captureSession?.stopRunning()
        }
    }
}

extension WalletQRCaptureService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        guard let possibleCode = metadata.stringValue else {
            return
        }

        if matcher.match(code: possibleCode) {
            notifyDelegateWithSuccessMatching(of: possibleCode)
        } else {
            notifyDelegateWithFailedMatching(of: possibleCode)
        }
    }
}
