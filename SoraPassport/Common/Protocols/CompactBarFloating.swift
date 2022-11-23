import UIKit

public enum CompactBarScrollingMode {
    case initial
    case compact
    case fullScreen
}

public enum CompactBarScrollingDirection {
    case top
    case bottom
}

public protocol CompactBarFloating: class {
    var compactBar: UIView { get }
    var compactBarSupportScrollView: UIScrollView { get }

    var compactBarScrollingMode: CompactBarScrollingMode { get }
    var compactBarTranslationFriction: CGFloat { get }
    var compactBarFullscreenSwitchOffset: CGFloat { get }
    var compactBarTransitionAnimationDuration: TimeInterval { get }

    func updateScrollingState(at targetContentOffset: CGPoint, animated: Bool)
    func handleInitialScrollingMode(at targetContentOffset: CGPoint, animated: Bool)
    func handleCompactScrollingMode(at targetContentOffset: CGPoint, animated: Bool)
    func handleFullScreenScrollingMode(at targetContentOffset: CGPoint, animated: Bool)
    func completeScrolling(at targetContentOffset: CGPoint, velocity: CGPoint, animated: Bool) -> CGPoint
    func transitCompactBar(progress: CGFloat, animated: Bool)
}

private struct CompactBarFloatingConstants {
    static var scrollingModeKey: String = "compactBarScrollingMode"
    static var scrollingDirectionKey: String = "compactBarScrollingDirection"
    static var scrollingOffsetCheckpointKey: String = "compactBarScrollingOffsetCheckpoint"
    static var lastScrollingOffsetKey: String = "compactBarLastScrollingOffset"
}

extension CompactBarFloating where Self: UIViewController {
    public private(set) var compactBarScrollingMode: CompactBarScrollingMode {
        get {
            let currentMode = objc_getAssociatedObject(self,
                                                       &CompactBarFloatingConstants.scrollingModeKey)
            return (currentMode as? CompactBarScrollingMode) ?? .initial
        }

        set {
            objc_setAssociatedObject(self,
                                     &CompactBarFloatingConstants.scrollingModeKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY)
        }
    }

    public private(set) var compactBarScrollingDirection: CompactBarScrollingDirection {
        get {
            let currentMode = objc_getAssociatedObject(self,
                                                       &CompactBarFloatingConstants.scrollingDirectionKey)
            return (currentMode as? CompactBarScrollingDirection) ?? .bottom
        }

        set {
            objc_setAssociatedObject(self,
                                     &CompactBarFloatingConstants.scrollingDirectionKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY)
        }
    }

    public private(set) var compactBarScrollingOffsetCheckpoint: CGPoint {
        get {
            let scrollingOffsetCheckpoint = objc_getAssociatedObject(
                self,
                &CompactBarFloatingConstants.scrollingOffsetCheckpointKey
            )
            return (scrollingOffsetCheckpoint as? CGPoint) ?? .zero
        }

        set {
            objc_setAssociatedObject(self,
                                     &CompactBarFloatingConstants.scrollingOffsetCheckpointKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY)
        }
    }

    public private(set) var compactBarLastScrollingOffset: CGPoint {
        get {
            let lastScrollingOffset = objc_getAssociatedObject(self,
                                                  &CompactBarFloatingConstants.lastScrollingOffsetKey)
            return (lastScrollingOffset as? CGPoint) ?? .zero
        }

        set {
            objc_setAssociatedObject(self,
                                     &CompactBarFloatingConstants.lastScrollingOffsetKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY)
        }
    }

    public var compactBarTranslationFriction: CGFloat {
        return 0.25
    }

    public var compactBarFullscreenSwitchOffset: CGFloat {
        return CGFloat.greatestFiniteMagnitude
    }

    public var compactBarTransitionAnimationDuration: TimeInterval {
        return 0.3
    }

    var shouldHandleFloatingBar: Bool {
        let contentInsets = compactBarSupportScrollView.adjustedContentInset

        let remainedContentHeight = compactBarSupportScrollView.contentSize.height
            - compactBar.bounds.size.height
        let remainedBoundsHeight = view.bounds.height - contentInsets.bottom

        return remainedContentHeight > remainedBoundsHeight
    }

    public func setupCompactBar(with mode: CompactBarScrollingMode) {
        if compactBar.superview != view {
            view.addSubview(compactBar)
        }

        self.compactBarScrollingMode = mode

        switch mode {
        case .initial, .fullScreen:
            hideCompactTopBar(animated: false)
        case .compact:
            showCompactTopBar(animated: false)
        }
    }

    public func updateScrollingState(at targetContentOffset: CGPoint, animated: Bool) {
        if shouldHandleFloatingBar {
            switch compactBarScrollingMode {
            case .initial:
                handleInitialScrollingMode(at: targetContentOffset, animated: animated)
            case .compact:
                handleCompactScrollingMode(at: targetContentOffset, animated: animated)
            case .fullScreen:
                handleFullScreenScrollingMode(at: targetContentOffset, animated: animated)
            }
        } else {
            hideCompactTopBar(animated: animated)
        }
    }

    public func handleInitialScrollingMode(at targetContentOffset: CGPoint, animated: Bool) {
        let scrollingFraction = targetContentOffset.y / compactBar.bounds.size.height

        transitCompactBar(progress: scrollingFraction, animated: animated)

        if scrollingFraction >= 1.0 {
            compactBarScrollingDirection = .bottom
            compactBarScrollingOffsetCheckpoint = targetContentOffset
            compactBarLastScrollingOffset = targetContentOffset

            compactBarScrollingMode = .compact

            showCompactTopBar(animated: animated)
        } else {
            if targetContentOffset.y < compactBarLastScrollingOffset.y {
                compactBarScrollingDirection = .top
            } else {
                compactBarScrollingDirection = .bottom
            }

            compactBarLastScrollingOffset = targetContentOffset
        }
    }

    public func handleCompactScrollingMode(at targetContentOffset: CGPoint, animated: Bool) {
        let scrollingFraction = targetContentOffset.y / compactBar.bounds.size.height

        if scrollingFraction < 1.0 {
            transitCompactBar(progress: scrollingFraction, animated: true)
            compactBarScrollingMode = .initial
        } else {
            if targetContentOffset.y < compactBarLastScrollingOffset.y {
                compactBarScrollingDirection = .top
                compactBarScrollingOffsetCheckpoint = targetContentOffset
            } else {
                compactBarScrollingDirection = .bottom

                if targetContentOffset.y - compactBarScrollingOffsetCheckpoint.y > compactBarFullscreenSwitchOffset {
                    compactBarScrollingOffsetCheckpoint = targetContentOffset
                    compactBarScrollingMode = .fullScreen

                    hideCompactTopBar(animated: animated)
                }
            }

            compactBarLastScrollingOffset = targetContentOffset
        }
    }

    public func handleFullScreenScrollingMode(at targetContentOffset: CGPoint, animated: Bool) {
        let scrollingFraction = targetContentOffset.y / compactBar.bounds.size.height

        if scrollingFraction < 1.0 {
            transitCompactBar(progress: scrollingFraction, animated: true)
            compactBarScrollingMode = .initial

            hideCompactTopBar(animated: animated)
        } else {
            if targetContentOffset.y < compactBarLastScrollingOffset.y {
                compactBarScrollingDirection = .top

                if compactBarScrollingOffsetCheckpoint.y - targetContentOffset.y  > compactBarFullscreenSwitchOffset {
                    compactBarScrollingOffsetCheckpoint = targetContentOffset
                    compactBarScrollingMode = .compact

                    showCompactTopBar(animated: animated)
                }
            } else {
                compactBarScrollingDirection = .bottom
                compactBarScrollingOffsetCheckpoint = targetContentOffset
            }

            compactBarLastScrollingOffset = targetContentOffset
        }
    }

    public func completeScrolling(at targetContentOffset: CGPoint, velocity: CGPoint, animated: Bool) -> CGPoint {
        guard shouldHandleFloatingBar else {
            return targetContentOffset
        }

        var finalContentOffset = targetContentOffset

        let scrollingFraction = targetContentOffset.y / compactBar.bounds.size.height

        if scrollingFraction < 1.0 {
            let contentInsets = compactBarSupportScrollView.adjustedContentInset

            let remainedContentHeight = compactBarSupportScrollView.contentSize.height
                - compactBar.bounds.size.height
            let remainedBoundsHeight = view.bounds.height - contentInsets.bottom

            if compactBarScrollingDirection == .bottom, targetContentOffset.y > -contentInsets.top,
                remainedContentHeight > remainedBoundsHeight {
                finalContentOffset.y = compactBar.bounds.size.height
            } else {
                finalContentOffset.y = -contentInsets.top
            }
        }

        return finalContentOffset
    }

    public func transitCompactBar(progress: CGFloat, animated: Bool) {
        let adjustedValue = min(max(progress, 0.0), 1.0)

        let transitionBlock = {
            self.compactBar.frame.origin.y = (adjustedValue - 1.0) *
                self.compactBar.frame.size.height * self.compactBarTranslationFriction

            self.compactBar.alpha = adjustedValue * adjustedValue
        }

        if animated {
            UIView.animate(withDuration: self.compactBarTransitionAnimationDuration) {
                transitionBlock()
            }
        } else {
            transitionBlock()
        }
    }

    public func showCompactTopBar(animated: Bool) {
        transitCompactBar(progress: 1.0, animated: animated)
    }

    public func hideCompactTopBar(animated: Bool) {
        transitCompactBar(progress: 0.0, animated: animated)
    }
}
