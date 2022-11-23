import Foundation

extension DispatchQueue {
    /**

     Debounce as in Rx

     Events

     =#====#=#=#=#=====>

     Debounced

     ===#==========#===>

     */
    public func asyncDebounce(target: AnyObject, after delay: TimeInterval, execute work: @escaping @convention(block) () -> Void) {
        let debounceIdentifier = DispatchQueue.debounceIdentifierFor(target)
        if let existingWorkItem = DispatchQueue.workItems.removeValue(forKey: debounceIdentifier) {
            existingWorkItem.cancel()
            NSLog("Debounced work item: \(debounceIdentifier)")
        }
        let workItem = DispatchWorkItem {
            DispatchQueue.workItems.removeValue(forKey: debounceIdentifier)

            for ptr in DispatchQueue.weakTargets.allObjects {
                if debounceIdentifier == DispatchQueue.debounceIdentifierFor(ptr as AnyObject) {
                    work()
                    NSLog("Run work item: \(debounceIdentifier)")
                    break
                }
            }
        }

        DispatchQueue.workItems[debounceIdentifier] = workItem
        DispatchQueue.weakTargets.addPointer(Unmanaged.passUnretained(target).toOpaque())

        asyncAfter(deadline: .now() + delay, execute: workItem)
    }

}

private extension DispatchQueue {

    static var workItems = [AnyHashable: DispatchWorkItem]()

    static var weakTargets = NSPointerArray.weakObjects()

    static func debounceIdentifierFor(_ object: AnyObject) -> String {
        return "\(Unmanaged.passUnretained(object).toOpaque())." + String(describing: object)
    }
}
