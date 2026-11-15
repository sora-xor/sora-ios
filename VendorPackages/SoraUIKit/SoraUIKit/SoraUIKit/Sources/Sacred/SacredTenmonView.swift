import Metal
import QuartzCore
import UIKit

/// Something that plays the launch flight: to a stop, then on once the wallet is ready.
public protocol SacredFlight: AnyObject {
    /// Flies to where it waits. `completion` runs when it has stopped there.
    func playIntro(completion: @escaping () -> Void)
    /// Goes on from where it waits. `completion` runs on arrival.
    func playOutro(completion: @escaping () -> Void)
    /// Stops where it waits with nothing moving; a pending completion is dropped.
    func rest()
    /// Shows where it comes to rest, with no flight.
    func showArrival()
}

extension SacredGateView: SacredFlight {}

/// The launch scene's shader, built once for the process and off the main thread.
public final class SacredTenmonPipeline {
    public static let shared = SacredTenmonPipeline()

    let device: MTLDevice?
    let queue: MTLCommandQueue?
    private let lock = NSLock()
    private var built: MTLRenderPipelineState?
    private var failed = false
    private var started = false
    private var waiters: [(Bool) -> Void] = []

    private init() {
        device = MTLCreateSystemDefaultDevice()
        queue = device?.makeCommandQueue()
    }

    /// False on a machine with no GPU to draw with, or once the shader has failed to build.
    public var isAvailable: Bool {
        guard device != nil, queue != nil else { return false }
        lock.lock()
        defer { lock.unlock() }
        return !failed
    }

    public var isReady: Bool { state != nil }

    var state: MTLRenderPipelineState? {
        lock.lock()
        defer { lock.unlock() }
        return built
    }

    /// Starts building. Calling it again does nothing.
    public func prepare() {
        lock.lock()
        let begin = !started
        started = true
        lock.unlock()
        guard begin, let device else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var result: MTLRenderPipelineState?
            if let library = try? device.makeLibrary(source: SacredTenmonShader.source, options: nil) {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "tenmonVertex")
                descriptor.fragmentFunction = library.makeFunction(name: "tenmonFragment")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                result = try? device.makeRenderPipelineState(descriptor: descriptor)
            }
            self.lock.lock()
            self.built = result
            self.failed = result == nil
            let waiting = self.waiters
            self.waiters = []
            self.lock.unlock()
            DispatchQueue.main.async { waiting.forEach { $0(result != nil) } }
        }
    }

    /// Answers once, on the main thread: at once if the shader is built, when it is, or with `false`
    /// after `limit`. Call it on the main thread.
    public func whenReady(within limit: TimeInterval, _ block: @escaping (Bool) -> Void) {
        prepare()
        var answered = false
        let answer: (Bool) -> Void = { ready in
            guard !answered else { return }
            answered = true
            block(ready)
        }
        lock.lock()
        if built != nil {
            lock.unlock()
            answer(true)
            return
        }
        if failed || device == nil {
            lock.unlock()
            answer(false)
            return
        }
        waiters.append(answer)
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + limit) { answer(false) }
    }
}

/// Plays the flight through the gate of heaven (`SacredTenmonScene`, drawn by `SacredTenmonShader`).
///
/// Frames are drawn on a thread of their own, so the flight keeps its pace while the main thread starts
/// the wallet, and each phase ends on the clock whether or not a frame was drawn.
public final class SacredTenmonView: UIView, SacredFlight {
    /// Tests turn the scene off to time the splash on the plain flight.
    public static var isEnabled = true
    /// Whether this device and its settings fly the scene: a GPU, and the full motion tier.
    public static var canFly: Bool {
        isEnabled && SacredTenmonPipeline.shared.isAvailable && FxPolicy.current.litMotion
    }

    public enum Phase: Equatable {
        case idle
        case intro
        case holding
        case outro
        case arrived
    }

    public private(set) var phase: Phase = .idle
    /// Where the planet lands. Unset, it lands where a PIN screen shows its emblem.
    public var landing: SacredEmblemLayout.Placement? { didSet { rebuildScene() } }
    public private(set) var placement: SacredEmblemLayout.Placement?
    /// The page day breaks into.
    public var page: UIColor = Lit.page { didSet { rebuildScene() } }
    /// Whether the planet stays when the rest has given way to the page.
    public var keepsPlanet = true { didSet { rebuildScene() } }

    private let renderLayer = CAMetalLayer()
    private let lock = NSLock()
    // Everything below is shared with the drawing thread, under the lock.
    private var scene: SacredTenmonScene?
    private var part: SacredTenmonScene.Phase = .intro
    private var partStart: CFTimeInterval = 0
    private var partDuration: CFTimeInterval = 1
    private var holdStart: CFTimeInterval = 0
    private var turnAtOutro: Float = 0
    private var firstDraw: CFTimeInterval = 0
    private var wantsFrames = false
    private var drawsOnce = false
    private var threadRunning = false
    private var drawn = 0
    private var slowFrames = 0
    // Main thread only.
    private var pixelsPerPoint: CGFloat = min(UIScreen.main.scale, 2) * 0.75
    private var clock = 0

    /// Frames drawn so far.
    public var framesDrawn: Int {
        lock.lock()
        defer { lock.unlock() }
        return drawn
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = UIColor(litHex: 0x06060B)
        renderLayer.device = SacredTenmonPipeline.shared.device
        renderLayer.pixelFormat = .bgra8Unorm
        renderLayer.framebufferOnly = true
        renderLayer.isOpaque = true
        layer.addSublayer(renderLayer)
        SacredTenmonPipeline.shared.prepare()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(pause), name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(resume), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        lock.lock()
        wantsFrames = false
        lock.unlock()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderLayer.frame = bounds
        CATransaction.commit()
        rebuildScene()
    }

    private func rebuildScene() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = pixelsPerPoint
        let pixels = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        // Only when it changes: setting it again would throw away the frame the layer is showing.
        if renderLayer.drawableSize != pixels { renderLayer.drawableSize = pixels }
        let place = landing ?? SacredEmblemLayout.pinPlacement(bounds: bounds, safeArea: safeAreaInsets)
            ?? SacredEmblemLayout.fallback(bounds: bounds, safeArea: safeAreaInsets)
        placement = place
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        page.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let next = SacredTenmonScene(
            size: SIMD2(Float(pixels.width), Float(pixels.height)), pixelsPerPoint: Float(scale),
            landing: SIMD2(Float(place.centre.x * scale), Float(place.centre.y * scale)),
            landingRadius: Float(place.planetRadius * scale),
            page: SIMD3(Float(red), Float(green), Float(blue)), keepsPlanet: keepsPlanet)
        lock.lock()
        scene = next
        lock.unlock()
    }

    // MARK: Phases

    public func playIntro(completion: @escaping () -> Void) {
        layoutIfNeeded()
        phase = .intro
        let now = CACurrentMediaTime()
        lock.lock()
        part = .intro
        partStart = now
        partDuration = SacredTenmonScene.introDuration
        drawsOnce = false
        lock.unlock()
        startDrawing()
        after(SacredTenmonScene.introDuration) { [weak self] in
            guard let self else { return }
            self.phase = .holding
            self.lock.lock()
            self.part = .hold
            self.holdStart = CACurrentMediaTime()
            self.lock.unlock()
            completion()
        }
    }

    public func playOutro(completion: @escaping () -> Void) {
        layoutIfNeeded()
        phase = .outro
        let now = CACurrentMediaTime()
        lock.lock()
        turnAtOutro = part == .hold ? SacredTenmonScene.turn(holding: Float(now - holdStart)) : 0
        part = .outro
        partStart = now
        partDuration = SacredTenmonScene.outroDuration
        drawsOnce = false
        lock.unlock()
        startDrawing()
        after(SacredTenmonScene.outroDuration) { [weak self] in
            guard let self else { return }
            self.phase = .arrived
            // One last frame at the very end of the way, then nothing more is drawn.
            self.drawOnce()
            completion()
        }
    }

    public func rest() {
        clock += 1
        layoutIfNeeded()
        phase = .holding
        lock.lock()
        part = .hold
        holdStart = CACurrentMediaTime()
        lock.unlock()
        drawOnce()
    }

    public func showArrival() {
        rest()
    }

    private func after(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        clock += 1
        let mine = clock
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.clock == mine else { return }
            block()
        }
    }

    // MARK: Drawing

    private func drawOnce() {
        lock.lock()
        drawsOnce = true
        lock.unlock()
        startDrawing()
    }

    private func startDrawing() {
        guard UIApplication.shared.applicationState != .background else { return }
        lock.lock()
        wantsFrames = true
        let spawn = !threadRunning
        threadRunning = true
        lock.unlock()
        guard spawn else { return }
        let box = WeakView(self)
        let thread = Thread { SacredTenmonView.run(box) }
        thread.name = "sacred-tenmon"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    @objc private func pause() {
        lock.lock()
        wantsFrames = false
        lock.unlock()
    }

    @objc private func resume() {
        switch phase {
        case .intro, .outro: startDrawing()
        case .holding, .arrived: drawOnce()
        case .idle: break
        }
    }

    private final class WeakView {
        weak var view: SacredTenmonView?
        init(_ view: SacredTenmonView) { self.view = view }
    }

    private static func run(_ box: WeakView) {
        var next = CACurrentMediaTime()
        while true {
            let goesOn: Bool = autoreleasepool {
                guard let view = box.view else { return false }
                return view.drawFrame()
            }
            guard goesOn else { return }
            // Sixty frames a second at most, whatever the screen can show.
            next = max(next + 1.0 / 60.0, CACurrentMediaTime() + 0.002)
            Thread.sleep(forTimeInterval: max(0.001, next - CACurrentMediaTime()))
        }
    }

    /// On the drawing thread. Returns false when the thread should end.
    private func drawFrame() -> Bool {
        let pipeline = SacredTenmonPipeline.shared
        lock.lock()
        guard wantsFrames else {
            threadRunning = false
            lock.unlock()
            return false
        }
        guard let scene, let state = pipeline.state, let queue = pipeline.queue else {
            // Not laid out, or the shader is still building: look again next frame.
            lock.unlock()
            return true
        }
        let now = CACurrentMediaTime()
        if firstDraw == 0 { firstDraw = now }
        let part = self.part
        let progress = Float(min(1, max(0, (now - partStart) / max(0.001, partDuration))))
        let turn: Float
        switch part {
        case .intro: turn = 0
        case .hold: turn = drawsOnce ? 0 : SacredTenmonScene.turn(holding: Float(now - holdStart))
        case .outro: turn = SacredTenmonScene.settledTurn(from: turnAtOutro, progress: progress)
        }
        let once = drawsOnce
        let seconds = Float(now - firstDraw)
        lock.unlock()

        var uniforms = scene.uniforms(part, progress: progress, clock: seconds, turn: turn)
        guard let drawable = renderLayer.nextDrawable(), let buffer = queue.makeCommandBuffer() else { return true }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return true }
        encoder.setRenderPipelineState(state)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SacredTenmonUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.addCompletedHandler { [weak self] finished in
            self?.note(gpuSeconds: finished.gpuEndTime - finished.gpuStartTime)
        }
        buffer.present(drawable)
        buffer.commit()

        lock.lock()
        drawn += 1
        if once, drawsOnce {
            wantsFrames = false
            threadRunning = false
            lock.unlock()
            return false
        }
        lock.unlock()
        return true
    }

    /// A GPU that cannot keep sixty frames gets fewer pixels to fill: one per point.
    private func note(gpuSeconds: CFTimeInterval) {
        guard gpuSeconds > 0.014 else { return }
        lock.lock()
        slowFrames += 1
        let lower = slowFrames == 6
        lock.unlock()
        guard lower else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pixelsPerPoint > 1 else { return }
            self.pixelsPerPoint = 1
            self.rebuildScene()
        }
    }
}
