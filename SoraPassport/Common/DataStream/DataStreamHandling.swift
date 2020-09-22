import Foundation

protocol DataStreamHandling {
    func didReceive(remoteEvent: Data)
    func didReceiveSyncRequest()
}

protocol DataStreamProcessing {
    func process(event: DataStreamOneOfEvent)
    func processOutOfSync()
}
