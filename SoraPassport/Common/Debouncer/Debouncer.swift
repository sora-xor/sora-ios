import Foundation

final class Debouncer {
	private let queue: DispatchQueue
	private var job: DispatchWorkItem = DispatchWorkItem(block: {})
	private let interval: TimeInterval

	public init(interval: TimeInterval, qos: DispatchQoS.QoSClass? = nil) {
		self.interval = interval
		if let qos = qos {
			self.queue = DispatchQueue.global(qos: qos)
		} else {
			self.queue = DispatchQueue.main
		}
	}

	public func perform(_ block: @escaping () -> Void) {
		job.cancel()
		job = DispatchWorkItem {
			block()
		}
		queue.asyncAfter(deadline: .now() + interval, execute: job)
	}

	public func cancel() {
		job.cancel()
	}
}
