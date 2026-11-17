// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import UIKit
import SoraUIKit

/// What the wallet does about the screen its one scene is on.
///
/// A folding iPhone has two screens and moves the running scene between them: a cover screen that is a
/// short, wide phone, and an inner screen the size of a small tablet whose natural way up is landscape.
/// Layout follows the window's size (`LayoutCanvas`); this type holds the rest: which way up the scene
/// may turn on each screen, and telling screens that show a secret when the scene has changed screens.
/// Nothing here asks which model the device is.
enum WalletDisplay {
    /// Posted on the main thread when the wallet's scene has moved to another screen, or the device has
    /// been closed or opened. A screen that is showing a recovery phrase or a key covers it again: what
    /// the owner chose to reveal on one screen is not carried onto another one.
    static let screenDidChangeNotification = Notification.Name("co.jp.sora.wallet.display.screenDidChange")

    // MARK: Orientation

    /// Which way up the wallet may be on a screen of `screenSize`.
    ///
    /// Phone-sized screens stay portrait, as every iPhone has been and as Info.plist says. A screen
    /// that is roomy both ways (an unfolded inner screen, which is landscape when held the natural
    /// way) follows the device, like an iPad: locked to portrait there, the wallet would sit sideways
    /// or in a strip down the middle.
    static func supportedOrientations(screenSize: CGSize, idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        if idiom == .pad { return .all }
        return LayoutCanvas(size: screenSize).isWide ? .all : .portrait
    }

    static func supportedOrientations(for scene: UIWindowScene?) -> UIInterfaceOrientationMask {
        let screen = scene?.screen ?? UIScreen.main
        return supportedOrientations(screenSize: screen.bounds.size, idiom: screen.traitCollection.userInterfaceIdiom)
    }

    // MARK: Moving between screens

    /// What tells one screen arrangement from another: the screen itself and the kind of room it gives.
    struct Placement: Equatable {
        let screen: ObjectIdentifier?
        let kind: LayoutCanvas.Kind

        init(screen: UIScreen?, size: CGSize) {
            self.screen = screen.map(ObjectIdentifier.init)
            self.kind = LayoutCanvas(size: size).kind
        }
    }

    /// Remembers where the scene was and says when it has moved. A turn of the inner screen keeps both
    /// the screen and the kind of room, so it is not a move.
    final class ScreenTracker {
        private(set) var placement: Placement?
        private let center: NotificationCenter

        init(center: NotificationCenter = .default) {
            self.center = center
        }

        /// Call whenever the scene's geometry may have changed. Returns true when it moved screens.
        @discardableResult
        func update(screen: UIScreen?, size: CGSize) -> Bool {
            let next = Placement(screen: screen, size: size)
            defer { placement = next }
            guard let placement, placement != next else { return false }
            center.post(name: WalletDisplay.screenDidChangeNotification, object: nil)
            return true
        }

        /// The hinge went to or from closed: the other screen is, or is about to be, the lit one.
        func hingeDidCross(closed: Bool, wasClosed: Bool) {
            guard closed != wasClosed else { return }
            center.post(name: WalletDisplay.screenDidChangeNotification, object: nil)
        }
    }

    static let tracker = ScreenTracker()

    /// Follows the scene of `window`: its first placement is remembered, later ones are compared.
    static func sceneGeometryDidChange(_ scene: UIWindowScene) {
        let size: CGSize
        if #available(iOS 26.0, *) {
            size = scene.effectiveGeometry.coordinateSpace.bounds.size
        } else {
            size = scene.coordinateSpace.bounds.size
        }
        tracker.update(screen: scene.screen, size: size)
    }

    /// Watches the hinge of the device `view` is on, where there is one. The geometry callback already
    /// reports a move between screens; the hinge says so even when a move is reported late.
    static func observeHinge(on view: UIView) {
        guard #available(iOS 27.1, *) else { return }
        let last = HingeState()
        let interaction = UIHingeInteraction { _, update in
            guard let hinge = update.hinge, hinge.status != .unknown else { return }
            let closed = hinge.status == .closed
            if let before = last.wasClosed { tracker.hingeDidCross(closed: closed, wasClosed: before) }
            last.wasClosed = closed
        }
        view.addInteraction(interaction)
    }

    private final class HingeState {
        var wasClosed: Bool?
    }

    // MARK: The fold

    /// The strip the system reserves for the fold across `view`, in the view's coordinates, while the
    /// device is open. Nil on a device without one.
    static func division(in view: UIView) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return view.reservedRegions(kind: .division).first(where: \.isActive)?.frame
    }

    /// The two pages of `view` on a two-page canvas, either side of the fold; nil for one page.
    static func pages(in view: UIView) -> (left: CGRect, right: CGRect)? {
        LayoutCanvas(size: view.bounds.size).pages(in: view.bounds, division: division(in: view))
    }

    // MARK: Readable columns

    /// Keeps `content` to the readable width in a window wider than that, and centred. On a phone it
    /// is `margin` from each side of the container, exactly where a pair of leading and trailing
    /// constraints puts it: no phone is wider than the readable width, so the limit never applies.
    /// Returns the constraints, already active.
    @discardableResult
    static func pinReadable(_ content: UIView, width: NSLayoutDimension, centerX: NSLayoutXAxisAnchor,
                            margin: CGFloat) -> [NSLayoutConstraint] {
        let fill = content.widthAnchor.constraint(equalTo: width, constant: -margin * 2)
        // Just under required: it gives way only to the readable limit.
        fill.priority = UILayoutPriority(999)
        let constraints = [
            content.centerXAnchor.constraint(equalTo: centerX),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: LayoutCanvas.readableWidth),
            fill
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    /// The same for the one content view of a vertical scroll view.
    @discardableResult
    static func pinReadable(_ content: UIView, inScroll scrollView: UIScrollView, margin: CGFloat) -> [NSLayoutConstraint] {
        let noSideways = scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        noSideways.isActive = true
        return [noSideways] + pinReadable(content, width: scrollView.frameLayoutGuide.widthAnchor,
                                          centerX: scrollView.contentLayoutGuide.centerXAnchor, margin: margin)
    }

    // MARK: The window's canvas

    /// Tests set a canvas instead of resizing the simulator's screen.
    static var canvasOverride: LayoutCanvas?

    /// The canvas of the window `view` is in. A view that is not in a window yet (a row being
    /// measured before it is shown) gets the wallet scene's.
    static func canvas(for view: UIView?) -> LayoutCanvas {
        if let canvasOverride { return canvasOverride }
        if let size = view?.window?.bounds.size { return LayoutCanvas(size: size) }
        if let scene = UIApplication.shared.soraWindowScene {
            return LayoutCanvas(size: scene.coordinateSpace.bounds.size)
        }
        return LayoutCanvas(size: UIScreen.main.bounds.size)
    }
}

// MARK: - A square code in its card

/// Keeps the card of a QR code from growing taller than leaves the rest of its screen in view.
///
/// On a phone the card is a square as wide as its column, and this does nothing. In a window that is
/// short for its width (a folded cover, an unfolded screen in landscape) a square that wide would push
/// the address and Share off the screen, so the card stops at `LayoutCanvas.codeSide` and the code,
/// still square, sits in its middle.
final class WalletCodeSide {
    private let square: NSLayoutConstraint
    private let capped: NSLayoutConstraint
    private(set) var side: CGFloat?

    /// `square` is the card's own height-equals-width constraint, already active.
    init(card: UIView, square: NSLayoutConstraint) {
        self.square = square
        capped = card.heightAnchor.constraint(equalToConstant: 0)
    }

    func update(columnWidth: CGFloat, canvas: LayoutCanvas) {
        let wanted = canvas.codeSide(columnWidth: columnWidth)
        guard columnWidth > 0, wanted < columnWidth - 0.5 else {
            side = nil
            capped.isActive = false
            square.isActive = true
            return
        }
        side = wanted
        square.isActive = false
        capped.constant = wanted
        capped.isActive = true
    }
}

// MARK: - Biometrics by their own name

extension AvailableBiometryType {
    /// Apple's name for the sensor this device has; these are product names and are not translated.
    var productName: String? {
        switch self {
        case .faceId: return "Face ID"
        case .touchId: return "Touch ID"
        case .none: return nil
        }
    }

    /// The glyph on the keypad's unlock key: a face for Face ID, a fingerprint for Touch ID. With
    /// neither, the face glyph the key has always had (the key is hidden then).
    var keypadGlyph: UIImage? {
        switch self {
        case .touchId: return R.image.pin.touch()
        case .faceId, .none: return R.image.wallet.faceId()
        }
    }

    /// The glyph beside the biometric unlock setting.
    var settingsGlyph: UIImage? {
        switch self {
        case .touchId: return R.image.pin.touch()
        case .faceId, .none: return R.image.profile.biometry()
        }
    }

    /// What VoiceOver calls the keypad's unlock key.
    func unlockLabel(preferredLanguages: [String]? = nil) -> String {
        productName ?? R.string.localizable.profileBiometryTitle(preferredLanguages: preferredLanguages)
    }
}
