import Foundation

final class DataStreamHandler {
    let processors: [DataStreamProcessing]

    var logger: LoggerProtocol?

    private var jsonDecoder = JSONDecoder()

    private let processingQueue: DispatchQueue = {
        let label = "co.jp.soramitsu.datastream.handler.\(UUID().uuidString)"
        return DispatchQueue(label: label)
    }()

    init(streamProcessors: [DataStreamProcessing]) {
        self.processors = streamProcessors
    }

    // MARK: Private
    private func handle(eventData: Data) throws {
        let event = try jsonDecoder.decode(DataStreamOneOfEvent.self, from: eventData)
        processors.forEach { $0.process(event: event) }

        logger?.debug("Did process event \(event)")
    }
}

extension DataStreamHandler: DataStreamHandling {
    func didReceive(remoteEvent: Data) {
        processingQueue.async { [weak self] in
            do {
                try self?.handle(eventData: remoteEvent)
            } catch {
                self?.logger?.error("Did receive handling error: \(error)")
            }
        }
    }

    func didReceiveSyncRequest() {
        processingQueue.async { [weak self] in
            self?.processors.forEach { $0.processOutOfSync() }
        }
    }
}
