/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: GPL-3.0
 */

import UIKit
import SoraUI

final class LoadingViewController: UIViewController {
    private struct Constants {
        static let initialProgress: CGFloat = 0.5
        static let progressStep: CGFloat = 0.05
        static let progressAnimationDuration: CGFloat = 4.0
        static let timerFireInterval: TimeInterval = 1.0
        static let minAnimationDuration: TimeInterval = 0.3
        static let maxAnimationDuration: TimeInterval = 3.0
    }

    @IBOutlet private var activityIndicatorView: LoadingView!
    @IBOutlet private var progressView: ProgressView!
    @IBOutlet private var slider: SliderView!
    @IBOutlet private var sliderLabel: UILabel!

    lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        formatter.minimumSignificantDigits = 1

        return formatter
    }()

    var progressTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        progressView.animationDuration = Constants.progressAnimationDuration
        progressView.setProgress(Constants.initialProgress, animated: false)

        updateActivityIndicatorAnimation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        activityIndicatorView.startAnimating()

        startProgressTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        activityIndicatorView.stopAnimating()

        stopProgressTimer()
    }

    private func startProgressTimer() {
        guard progressTimer == nil else {
            return
        }

        progressTimer = Timer.scheduledTimer(timeInterval: Constants.timerFireInterval,
                                             target: self,
                                             selector: #selector(actionOn(timer:)),
                                             userInfo: nil,
                                             repeats: true)
    }

    private func stopProgressTimer() {
        self.progressTimer?.invalidate()
        self.progressTimer = nil
    }

    @objc func actionOn(timer: Timer) {
        let newProgress = progressView.progress + Constants.progressStep
        progressView.setProgress(newProgress, animated: true)
    }

    @IBAction func actionOnSliderChange(sender: SliderView) {
        updateActivityIndicatorAnimation()
    }

    func updateActivityIndicatorAnimation() {
        let duration = Constants.minAnimationDuration + (Constants.maxAnimationDuration - Constants.minAnimationDuration) * TimeInterval(slider.value)

        let isAnimating = activityIndicatorView.isAnimating

        activityIndicatorView.stopAnimating()
        activityIndicatorView.animationDuration = duration

        if isAnimating {
            activityIndicatorView.startAnimating()
        }

        if let numberString = numberFormatter.string(from: NSNumber(value: duration)) {
            sliderLabel.text = "Animation Duration: \(numberString)"
        }
    }
}
