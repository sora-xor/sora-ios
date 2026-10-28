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

    private let stateLock = NSLock()
    private var generation: UUID?
    private var isStartingOrRunning = false

    private func isCurrent(_ id: UUID) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return generation == id
    }

    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: (@escaping (Bool) -> Void) -> Void
    private let makeSession: (AVCaptureMetadataOutputObjectsDelegate) throws -> AVCaptureSession

    init(matcher: WalletQRMatcherProtocol,
         delegate: WalletQRCaptureServiceDelegate?,
         delegateQueue: DispatchQueue? = nil,
         authorizationStatus: @escaping () -> AVAuthorizationStatus = { AVCaptureDevice.authorizationStatus(for: .video) },
         requestAccess: @escaping (@escaping (Bool) -> Void) -> Void = { AVCaptureDevice.requestAccess(for: .video, completionHandler: $0) },
         makeSession: @escaping (AVCaptureMetadataOutputObjectsDelegate) throws -> AVCaptureSession = WalletQRCaptureService.makeCaptureSession) {

        self.authorizationStatus = authorizationStatus
        self.requestAccess = requestAccess
        self.makeSession = makeSession
        self.matcher = matcher
        self.delegate = delegate
        self.delegateQueue = delegateQueue ?? WalletQRCaptureService.processingQueue

        super.init()
    }

    private func configureSessionIfNeeded() throws {
        guard captureSession == nil else { return }
        captureSession = try makeSession(self)
    }

    private static func makeCaptureSession(delegate: AVCaptureMetadataOutputObjectsDelegate) throws -> AVCaptureSession {
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

        output.setMetadataObjectsDelegate(delegate, queue: WalletQRCaptureService.processingQueue)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        return captureSession
    }

    private func startAuthorizedSession(id: UUID) {
        Self.processingQueue.async {
            guard self.isCurrent(id) else { return }
            do {
                try self.configureSessionIfNeeded()
                guard self.isCurrent(id), let captureSession = self.captureSession else { return }
                captureSession.startRunning()
                self.notify(id: id) { $0.qrCapture(service: self, didSetup: captureSession) }
            } catch {
                self.notify(error: error, id: id)
            }
        }
    }

    private func notify(error: Error, id: UUID) {
        stateLock.lock()
        if generation == id { isStartingOrRunning = false }
        stateLock.unlock()
        notify(id: id) { $0.qrCapture(service: self, didReceive: error) }
    }

    private func notify(id: UUID, action: @escaping (WalletQRCaptureServiceDelegate) -> Void) {
        delegateQueue.async { [weak self] in
            guard let self, self.isCurrent(id), let delegate = self.delegate else { return }
            action(delegate)
        }
    }
}

extension WalletQRCaptureService: WalletQRCaptureServiceProtocol {
    func start() {
        stateLock.lock()
        guard !isStartingOrRunning else { stateLock.unlock(); return }
        let id = UUID()
        generation = id
        isStartingOrRunning = true
        stateLock.unlock()
        switch authorizationStatus() {
        case .authorized:
            startAuthorizedSession(id: id)
        case .notDetermined:
            requestAccess { [weak self] granted in
                guard let self, self.isCurrent(id) else { return }
                if granted {
                    self.startAuthorizedSession(id: id)
                } else {
                    self.notify(error: WalletQRCaptureServiceError.deviceAccessDeniedNow, id: id)
                }
            }
        case .denied:
            notify(error: WalletQRCaptureServiceError.deviceAccessDeniedPreviously, id: id)
        case .restricted:
            notify(error: WalletQRCaptureServiceError.deviceAccessRestricted, id: id)
        @unknown default:
            notify(error: WalletQRCaptureServiceError.deviceAccessRestricted, id: id)
        }
    }

    func stop() {
        stateLock.lock()
        generation = nil
        isStartingOrRunning = false
        stateLock.unlock()
        Self.processingQueue.async { self.captureSession?.stopRunning() }
    }
}

extension WalletQRCaptureService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        stateLock.lock()
        let id = isStartingOrRunning ? generation : nil
        stateLock.unlock()
        guard let id else { return }
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        guard let possibleCode = metadata.stringValue else {
            return
        }

        if matcher.match(code: possibleCode) {
            notify(id: id) { $0.qrCapture(service: self, didMatch: possibleCode) }
        } else {
            notify(id: id) { $0.qrCapture(service: self, didFailMatching: possibleCode) }
        }
    }
}
