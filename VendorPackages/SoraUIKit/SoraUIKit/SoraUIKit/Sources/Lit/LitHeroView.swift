import Metal
import QuartzCore
import UIKit
import simd

/// The compiled shader and what it samples, one for the whole app. Building it from source takes up to a couple of
/// seconds the first time (the system keeps the result for later launches), so it never happens on the main thread.
private final class LitHeroPipeline {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let state: MTLRenderPipelineState
    let sampler: MTLSamplerState
    let mark: MTLTexture

    private enum Status {
        case idle
        case building
        case ready(LitHeroPipeline)
        case failed
    }

    private static var status = Status.idle
    private static var waiting: [(LitHeroPipeline?) -> Void] = []

    /// Main thread only, and calls back on it: at once if the shader is already built, nil if it cannot be.
    static func request(_ completion: @escaping (LitHeroPipeline?) -> Void) {
        switch status {
        case let .ready(pipeline):
            completion(pipeline)
        case .failed:
            completion(nil)
        case .building:
            waiting.append(completion)
        case .idle:
            status = .building
            waiting.append(completion)
            DispatchQueue.global(qos: .userInitiated).async {
                let pipeline = LitHeroPipeline()
                DispatchQueue.main.async {
                    status = pipeline.map(Status.ready) ?? .failed
                    let callbacks = waiting
                    waiting = []
                    callbacks.forEach { $0(pipeline) }
                }
            }
        }
    }

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: LitHeroShader.source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "litVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "litFragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            state = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor),
              let mark = Self.makeMarkTexture(device: device) else { return nil }
        self.device = device
        self.queue = queue
        self.sampler = sampler
        self.mark = mark
    }

    /// The mark's mask, from the same outline the plain drawing uses. Every level is drawn on the CPU: this can run
    /// while the app is in the background, where the GPU takes no work.
    private static func makeMarkTexture(device: MTLDevice) -> MTLTexture? {
        let side = 512
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: side, height: side, mipmapped: true)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        for level in 0..<texture.mipmapLevelCount {
            let size = max(side >> level, 1)
            guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
                  let data = context.data else { return nil }
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            // The bitmap's rows run top to bottom in memory only with Core Graphics' axis flipped.
            context.translateBy(x: 0, y: CGFloat(size))
            context.scaleBy(x: 1, y: -1)
            context.addPath(PortfolioLitMark.path(side: CGFloat(size)))
            context.setFillColor(gray: 1, alpha: 1)
            context.fillPath()
            texture.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: level, withBytes: data, bytesPerRow: size)
        }
        return texture
    }
}

/// Draws the hero scene with `LitHeroShader` into a Metal layer. Frames are drawn only while something
/// moves: the comet, the ring drawing in, a highlight easing, or the phone turning.
public final class LitHeroView: UIView {
    public struct Segment: Equatable {
        public var start: CGFloat
        public var sweep: CGFloat
        public var color: UIColor
        public var strength: CGFloat
        public var widthScale: CGFloat
        public var lift: CGFloat

        public init(start: CGFloat, sweep: CGFloat, color: UIColor, strength: CGFloat = 1, widthScale: CGFloat = 1, lift: CGFloat = 0) {
            self.start = start
            self.sweep = sweep
            self.color = color
            self.strength = strength
            self.widthScale = widthScale
            self.lift = lift
        }
    }

    /// False if this device cannot draw the scene; the caller keeps its plain drawing. True from the start on any
    /// device with Metal; a shader that then fails to build turns it false and calls `onUnavailable`.
    public private(set) var isAvailable = false
    public var onUnavailable: (() -> Void)?

    public override class var layerClass: AnyClass { CAMetalLayer.self }
    private var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    private var renderer: LitHeroPipeline?
    private var link: CADisplayLink?
    private var uniforms = LitHeroUniforms()
    private var needsFrame = true

    // Scene state
    public var planetCenter: CGPoint = .zero { didSet { if planetCenter != oldValue { setNeedsFrame() } } }
    public var planetRadius: CGFloat = 46 { didSet { if planetRadius != oldValue { setNeedsFrame() } } }
    public var ringRadius: CGFloat = 128
    public var ringWidth: CGFloat = 13
    public var ringThickness: CGFloat = 3.2
    public var outerOrbit: CGFloat = 150
    public var aspect: CGFloat = 0.31 { didSet { if aspect != oldValue { setNeedsFrame() } } }
    public var rollRadians: CGFloat = -10 * .pi / 180 { didSet { if rollRadians != oldValue { setNeedsFrame() } } }
    public var tilt: CGPoint = .zero { didSet { if tilt != oldValue { setNeedsFrame() } } }
    public var isDarkPage = false { didSet { if isDarkPage != oldValue { setNeedsFrame() } } }
    public var bottomFade: CGFloat = 60

    /// Whether the comet laps the ring. When off it fades out and the view stops drawing.
    public var isCometRunning = false { didSet { if isCometRunning != oldValue { updateLink() } } }
    /// Seconds per lap: short while the wallet is reading the chain.
    public var lapDuration: CFTimeInterval = 9

    /// How much of the ring is drawn, 0...1.
    public private(set) var reveal: CGFloat = 1
    private var revealFrom: CFTimeInterval?
    private var revealDuration: CFTimeInterval = 1.1
    private var revealWaiting = false

    private var ringStart: CGFloat = 0
    private var targets: [Segment] = []
    private var shown: [Segment] = []
    private var cometAngle: CGFloat = .pi / 2
    private var cometPower: CGFloat = 0
    private var lastTick: CFTimeInterval = 0
    private var bloom: CGFloat = 0
    /// The GPU fell behind the comet for over a second: it rests until then. A busy moment passes, so it tries again
    /// after a rest that doubles each time it is needed.
    private static var restUntil: CFTimeInterval = 0
    private static var restSeconds: CFTimeInterval = 30
    private var lateTicks = 0
    private var motionStarted: CFTimeInterval?
    /// Frames handed to the GPU and not yet finished. Counted where the GPU says so, under a lock: handing
    /// each one back through the main queue woke the main thread thirty more times a second.
    private let inFlight = LitFrameCount()
    private var cometShouldRun: Bool { isCometRunning && CACurrentMediaTime() >= Self.restUntil }
    private var isOnScreen = false
    /// Looks again, once a second, while the scene is in a window but hidden: whoever hides it may show it
    /// again without telling anyone.
    private var hiddenCheck: Timer?
    /// The GPU was behind and a frame was skipped: it is drawn on a later tick. Kept apart from `needsFrame`,
    /// which says something other than the comet changed and asks for sixty frames a second.
    private var retryFrame = false
    private var missedFrames = 0
    private var isInBackground = false
    private var observers: [NSObjectProtocol] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        isOpaque = false
        setUpRenderer()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isInBackground = true
                self?.updateLink()
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isInBackground = false
                self?.setNeedsFrame()
            },
            // A screen that covers this one whole hides it: the scene stops drawing until it shows again.
            center.addObserver(forName: LitStage.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.updateLink()
            },
            center.addObserver(forName: UIWindow.didBecomeVisibleNotification, object: nil, queue: .main) { [weak self] _ in
                self?.updateLink()
            }
        ]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hiddenCheck?.invalidate()
        link?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Builds the shader ahead of the first hero, off the main thread. Call it from the main thread, early at launch.
    public static func preload(then completion: (() -> Void)? = nil) {
        LitHeroPipeline.request { _ in completion?() }
    }

    private func setUpRenderer() {
        guard let metalLayer, let device = MTLCreateSystemDefaultDevice() else { return }
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.isOpaque = false
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
        metalLayer.maximumDrawableCount = 3
        isAvailable = true
        var isSettingUp = true
        LitHeroPipeline.request { [weak self] built in self?.rendererArrived(built, late: !isSettingUp) }
        isSettingUp = false
    }

    private func rendererArrived(_ built: LitHeroPipeline?, late: Bool) {
        guard let built else {
            isAvailable = false
            onUnavailable?()
            return
        }
        renderer = built
        // Only the first launch after an update can get here with the home already up: the scene fades in.
        if late, window != nil, LitMotion.allowed {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.35
            layer.add(fade, forKey: "arrive")
        }
        if revealWaiting {
            revealWaiting = false
            revealFrom = CACurrentMediaTime()
        }
        setNeedsFrame()
    }

    // MARK: Scene updates

    /// Sets the ring. New colours or arcs take effect at once; strength, width and lift ease over a moment.
    public func setSegments(_ segments: [Segment], ringStart start: CGFloat) {
        ringStart = start
        if segments.count == shown.count, zip(segments, shown).allSatisfy({ $0.start == $1.start && $0.sweep == $1.sweep && $0.color == $1.color }) {
            targets = segments
        } else {
            targets = segments
            shown = segments
        }
        setNeedsFrame()
    }

    /// Draws the ring in from its start.
    public func runReveal(duration: CFTimeInterval) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            reveal = 1
            setNeedsFrame()
            return
        }
        reveal = 0
        revealDuration = duration
        if renderer == nil {
            revealWaiting = true
        } else {
            revealFrom = CACurrentMediaTime()
        }
        setNeedsFrame()
    }

    /// One soft flare of the whole scene: a read has just finished.
    public func flare() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        bloom = 1
        setNeedsFrame()
    }

    public func setNeedsFrame() {
        needsFrame = true
        updateLink()
    }

    // MARK: Frame loop

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            updateDrawableSize()
            needsFrame = true
        }
        updateLink()
    }

    public override var isHidden: Bool {
        didSet { if isHidden != oldValue { updateLink() } }
    }

    /// Whether the scene can be seen: in a window, with nothing hidden above it. Looked at afresh each
    /// time a frame is asked for; a scene that has just come back into view draws at once.
    private func lookWhetherShown() {
        let shown = window != nil && LitStage.isShown(layer)
        if shown, !isOnScreen {
            updateDrawableSize()
            needsFrame = true
        }
        isOnScreen = shown
        // In a window but hidden (a screen covers this one, or an ancestor was hidden): look again shortly.
        // Not while the app is in the background: coming to the front asks again by itself.
        if window != nil, !shown, !isInBackground {
            if hiddenCheck == nil {
                let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateLink() }
                timer.tolerance = 0.5
                RunLoop.main.add(timer, forMode: .common)
                hiddenCheck = timer
            }
        } else {
            hiddenCheck?.invalidate()
            hiddenCheck = nil
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawableSize()
        setNeedsFrame()
    }

    private func updateDrawableSize() {
        guard let metalLayer else { return }
        let scale = window?.screen.scale ?? traitCollection.displayScale
        guard scale > 0 else { return }
        metalLayer.contentsScale = scale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        if size.width > 0, size.height > 0, metalLayer.drawableSize != size {
            metalLayer.drawableSize = size
        }
    }

    private var isAnimating: Bool {
        if cometShouldRun || cometPower > 0.001 { return true }
        if revealFrom != nil || bloom > 0.003 { return true }
        return zip(targets, shown).contains { abs($0.strength - $1.strength) > 0.002 || abs($0.widthScale - $1.widthScale) > 0.002 || abs($0.lift - $1.lift) > 0.002 }
    }

    private func updateLink() {
        lookWhetherShown()
        guard renderer != nil, isOnScreen, !isInBackground, needsFrame || retryFrame || isAnimating else {
            link?.invalidate()
            link = nil
            return
        }
        guard link == nil else { return }
        lastTick = CACurrentMediaTime()
        let target = LitLinkTarget { [weak self] in self?.tick() }
        let displayLink = CADisplayLink(target: target, selector: #selector(LitLinkTarget.tick))
        displayLink.preferredFrameRateRange = Self.frameRates(60)
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
        cadence = 60
    }

    private static func frameRates(_ cadence: Int) -> CAFrameRateRange {
        cadence == 30 ? CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
            : CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    }

    /// Frames a second the frame loop asks for: thirty while only the comet moves, sixty for anything else.
    private var cadence = 60

    private func setCadence(_ wanted: Int) {
        guard wanted != cadence, let link else { return }
        cadence = wanted
        link.preferredFrameRateRange = Self.frameRates(wanted)
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(now - lastTick, 0.1))
        lastTick = now

        cometPower += ((cometShouldRun ? 1 : 0) - cometPower) * min(dt * 3.5, 1)
        if cometPower < 0.002, !cometShouldRun { cometPower = 0 }
        if cometPower > 0 {
            cometAngle += dt * 2 * .pi / CGFloat(lapDuration)
            cometAngle = cometAngle.truncatingRemainder(dividingBy: 2 * .pi)
        }
        if bloom > 0 {
            bloom *= CGFloat(exp(-Double(dt) * 3.4))
            if bloom <= 0.003 { bloom = 0 }
        }
        if let from = revealFrom {
            let t = min((now - from) / revealDuration, 1)
            reveal = CGFloat(1 - pow(1 - t, 3))
            if t >= 1 {
                reveal = 1
                revealFrom = nil
            }
        }
        for index in shown.indices where index < targets.count {
            let k = min(dt * 11, 1)
            shown[index].strength += (targets[index].strength - shown[index].strength) * k
            shown[index].widthScale += (targets[index].widthScale - shown[index].widthScale) * k
            shown[index].lift += (targets[index].lift - shown[index].lift) * k
        }
        // A comet alone needs only thirty frames a second; anything else that moves gets sixty. The frame
        // loop itself slows to thirty then: it used to wake sixty times a second and draw on every other one.
        let onlyComet = !needsFrame && revealFrom == nil && bloom == 0 && zip(targets, shown).allSatisfy {
            abs($0.strength - $1.strength) <= 0.002 && abs($0.widthScale - $1.widthScale) <= 0.002 && abs($0.lift - $1.lift) <= 0.002
        }
        setCadence(onlyComet ? 30 : 60)
        needsFrame = false
        retryFrame = false
        drawFrame()
        updateLink()
    }

    /// Whether the GPU is keeping up with the comet, the one thing that asks for frames on its own. Frames waiting
    /// on the GPU more often than not, over a second and more: it cannot carry the comet on this phone. What else the
    /// first moments on screen are busy with does not count.
    private func notePace(behind: Bool) {
        guard cometShouldRun else {
            motionStarted = nil
            lateTicks = 0
            return
        }
        let now = CACurrentMediaTime()
        guard let started = motionStarted else {
            motionStarted = now
            return
        }
        guard now - started > 1.5 else { return }
        lateTicks = behind ? lateTicks + 1 : max(lateTicks - 1, 0)
        guard lateTicks >= 24 else { return }
        lateTicks = 0
        motionStarted = nil
        let rest = Self.restSeconds
        Self.restUntil = now + rest
        Self.restSeconds = min(rest * 2, 600)
        DispatchQueue.main.asyncAfter(deadline: .now() + rest + 0.1) { [weak self] in self?.updateLink() }
    }

    private func drawFrame() {
        // Frames still on the GPU: a later tick draws instead of holding up the main thread for a drawable.
        guard inFlight.value < 2 else {
            retryFrame = true
            notePace(behind: true)
            return
        }
        notePace(behind: false)
        guard let metalLayer, let renderer, bounds.width > 0, bounds.height > 0 else { return }
        fillUniforms(scale: metalLayer.contentsScale)
        guard let drawable = metalLayer.nextDrawable(), let buffer = renderer.queue.makeCommandBuffer() else {
            missFrame()
            return
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else {
            missFrame()
            return
        }
        encoder.setRenderPipelineState(renderer.state)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LitHeroUniforms>.stride, index: 0)
        encoder.setFragmentTexture(renderer.mark, index: 0)
        encoder.setFragmentSamplerState(renderer.sampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        inFlight.add(1)
        buffer.addCompletedHandler { [inFlight] _ in inFlight.add(-1) }
        buffer.present(drawable)
        buffer.commit()
        missedFrames = 0
    }

    /// No drawable or no buffer this once: the frame that was asked for is still owed, so the next tick tries
    /// again. Not for ever: after half a second of misses it waits for the next thing that asks for a frame.
    private func missFrame() {
        missedFrames += 1
        if missedFrames <= 30 { retryFrame = true }
    }

    private func fillUniforms(scale: CGFloat) {
        uniforms.viewport = SIMD4(Float(bounds.width), Float(bounds.height), Float(scale), 0)
        uniforms.center = SIMD4(Float(planetCenter.x), Float(planetCenter.y), Float(planetRadius), isDarkPage ? 1 : 0)
        uniforms.ring = SIMD4(Float(ringRadius), Float(ringWidth), Float(ringThickness), Float(reveal))
        uniforms.pose = SIMD4(Float(aspect), Float(rollRadians), Float(tilt.x), Float(tilt.y))
        uniforms.comet = SIMD4(Float(cometAngle), Float(cometPower), Float(bottomFade), Float(bloom))
        uniforms.ringInfo = SIMD4(Float(ringStart), Float(min(shown.count, 6)), 0.65, Float(outerOrbit))
        var angles = [SIMD4<Float>](repeating: .zero, count: 6)
        var colors = [SIMD4<Float>](repeating: .zero, count: 6)
        for (index, segment) in shown.prefix(6).enumerated() {
            angles[index] = SIMD4(Float(segment.start), Float(segment.sweep), Float(segment.strength), Float(segment.widthScale))
            var linear = Self.linear(segment.color)
            linear.w = Float(segment.lift)
            colors[index] = linear
        }
        uniforms.segmentAngles = (angles[0], angles[1], angles[2], angles[3], angles[4], angles[5])
        uniforms.segmentColors = (colors[0], colors[1], colors[2], colors[3], colors[4], colors[5])
        var bounce = [SIMD4<Float>](repeating: .zero, count: 8)
        if !shown.isEmpty {
            for sample in 0..<8 {
                let angle = (CGFloat(sample) + 0.5) * 2 * .pi / 8
                for (index, segment) in shown.prefix(6).enumerated() {
                    var off = (angle - segment.start).truncatingRemainder(dividingBy: 2 * .pi)
                    if off < 0 { off += 2 * .pi }
                    if off < segment.sweep {
                        var color = colors[index]
                        color *= Float(segment.strength)
                        bounce[sample] = color
                        break
                    }
                }
            }
        }
        uniforms.bounce = (bounce[0], bounce[1], bounce[2], bounce[3], bounce[4], bounce[5], bounce[6], bounce[7])
    }

    private static func linear(_ color: UIColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(pow(Float(r), 2.2), pow(Float(g), 2.2), pow(Float(b), 2.2), 0)
    }
}

/// A count shared with the GPU's completion thread.
private final class LitFrameCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func add(_ change: Int) {
        lock.lock()
        count += change
        lock.unlock()
    }
}

private final class LitLinkTarget: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func tick() { action() }
}

/// The 天 outline on its 22-unit disc, for the renderer's mask.
enum PortfolioLitMark {
    static func path(side: CGFloat) -> CGPath {
        let scale = side / 22
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 5.8, y: 20.7), transform: transform)
        path.addCurve(to: CGPoint(x: 11.1, y: 12.9), control1: CGPoint(x: 7.5, y: 18.1), control2: CGPoint(x: 9.3, y: 15.5), transform: transform)
        path.addLine(to: CGPoint(x: 16.3, y: 20.7), transform: transform)
        path.addCurve(to: CGPoint(x: 17.1, y: 20.2), control1: CGPoint(x: 16.6, y: 20.6), control2: CGPoint(x: 16.8, y: 20.4), transform: transform)
        path.addCurve(to: CGPoint(x: 17.8, y: 19.7), control1: CGPoint(x: 17.4, y: 20), control2: CGPoint(x: 17.6, y: 19.9), transform: transform)
        path.addCurve(to: CGPoint(x: 12, y: 11), control1: CGPoint(x: 15.9, y: 16.8), control2: CGPoint(x: 13.9, y: 13.9), transform: transform)
        let corners: [(CGFloat, CGFloat)] = [(17.8, 11), (17.8, 9.2), (12, 9.2), (12, 7.3), (17.8, 7.3), (17.8, 5.5), (4.3, 5.5),
                                             (4.3, 7.3), (10.1, 7.3), (10.1, 9.2), (4.3, 9.2), (4.3, 11), (10.1, 11), (4.3, 19.7)]
        for (x, y) in corners { path.addLine(to: CGPoint(x: x, y: y), transform: transform) }
        path.addCurve(to: CGPoint(x: 5, y: 20.2), control1: CGPoint(x: 4.5, y: 19.9), control2: CGPoint(x: 4.7, y: 20), transform: transform)
        path.addCurve(to: CGPoint(x: 5.8, y: 20.7), control1: CGPoint(x: 5.3, y: 20.4), control2: CGPoint(x: 5.5, y: 20.6), transform: transform)
        path.closeSubpath()
        transform = .identity
        return path
    }
}
