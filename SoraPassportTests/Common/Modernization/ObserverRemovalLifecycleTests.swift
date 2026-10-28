// SPDX-License-Identifier: Apache-2.0
import Foundation
import XCTest

@testable import SoraPassport

final class ObserverRemovalLifecycleTests: XCTestCase {
  private func drain(_ queue: DispatchQueue) async {
    await withCheckedContinuation { c in queue.async { c.resume() } }
  }
  func testEventObserverCanRemoveItselfDuringDeinitialization() async {
    let queue = DispatchQueue(label: "observer-event-fixture")
    let center = EventCenter(syncQueue: DispatchQueue(label: "observer-events"))
    var observer: RemovingEventObserver? = RemovingEventObserver(center: center)
    weak var reference = observer
    center.add(observer: observer!, dispatchIn: queue)
    let completed = expectation(description: "registration drained")
    center.notify(with: SelectedAccountChanged(), completionOnMain: { completed.fulfill() })
    await fulfillment(of: [completed], timeout: 1)
    observer = nil
    for _ in 0..<100 {
      if reference == nil { break }
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTAssertNil(reference)
  }
  func testRemovingAnEventObserverDoesNotRetainItUntilTheQueueResumes() async {
    let queue = DispatchQueue(label: "observer-queued-removal")
    let center: EventCenter
    center = EventCenter(syncQueue: queue)
    var observer: RemovingEventObserver? = RemovingEventObserver(center: center)
    weak var reference = observer
    queue.suspend()
    center.remove(observer: observer!)
    observer = nil
    XCTAssertNil(reference)
    queue.resume()
    await drain(queue)
  }
  func testRemovedObserverDoesNotReceiveLaterEvents() async {
    let queue = DispatchQueue(label: "observer-delivery")
    let center = EventCenter()
    let observer = RemovingEventObserver(center: nil)
    center.add(observer: observer, dispatchIn: queue)
    center.remove(observer: observer)
    let done = expectation(description: "event finished")
    center.notify(with: SelectedAccountChanged(), completionOnMain: { done.fulfill() })
    await fulfillment(of: [done], timeout: 1)
    XCTAssertEqual(observer.events, 0)
  }
  func testRemovingOneEventObserverPreservesAnother() async {
    let center = EventCenter()
    let removed = RemovingEventObserver(center: nil)
    let kept = RemovingEventObserver(center: nil)
    center.add(observer: removed, dispatchIn: nil)
    center.add(observer: kept, dispatchIn: nil)
    center.remove(observer: removed)
    let done = expectation(description: "event finished")
    center.notify(with: SelectedAccountChanged(), completionOnMain: { done.fulfill() })
    await fulfillment(of: [done], timeout: 1)
    XCTAssertEqual(removed.events, 0)
    XCTAssertEqual(kept.events, 1)
  }
  func testAssetObserverCanRemoveItselfDuringDeinitialization() async {
    let provider = AssetProvider(refresh: {}, schedule: { _, _ in })
    var observer: RemovingBalanceObserver? = RemovingBalanceObserver(provider: provider)
    weak var reference = observer
    provider.add(observer: observer!)
    try? await Task.sleep(nanoseconds: 20_000_000)
    observer = nil
    for _ in 0..<100 {
      if reference == nil { break }
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTAssertNil(reference)
  }
  func testRemovingAnUnregisteredAssetObserverDoesNotRetainIt() async {
    let provider = AssetProvider(refresh: {}, schedule: { _, _ in })
    var observer: RemovingBalanceObserver? = RemovingBalanceObserver(provider: provider)
    weak var reference = observer
    provider.remove(observer: observer!)
    observer = nil
    XCTAssertNil(reference)
    try? await Task.sleep(nanoseconds: 20_000_000)
  }
  func testRemovedAssetObserverDoesNotReceiveLaterBalances() async {
    let provider = AssetProvider(refresh: {}, schedule: { _, _ in })
    let observer = RemovingBalanceObserver(provider: nil)
    provider.add(observer: observer)
    provider.remove(observer: observer)
    provider.notify()
    try? await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(observer.deliveries, 0)
  }
  func testRemovingOneAssetObserverPreservesAnother() async {
    let provider = AssetProvider(refresh: {}, schedule: { _, _ in })
    let removed = RemovingBalanceObserver(provider: nil)
    let kept = RemovingBalanceObserver(provider: nil)
    provider.add(observer: removed)
    provider.add(observer: kept)
    provider.remove(observer: removed)
    provider.notify()
    for _ in 0..<100 {
      if kept.deliveries == 1 { break }
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTAssertEqual(removed.deliveries, 0)
    XCTAssertEqual(kept.deliveries, 1)
  }
}
private final class RemovingEventObserver: EventVisitorProtocol {
  let center: EventCenter?
  private let lock = NSLock()
  private var count = 0
  var events: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  init(center: EventCenter?) { self.center = center }
  deinit { center?.remove(observer: self) }
  func processSelectedAccountChanged(event: SelectedAccountChanged) {
    lock.lock()
    count += 1
    lock.unlock()
  }
}
private final class RemovingBalanceObserver: AssetProviderObserverProtocol {
  let provider: AssetProvider?
  private let lock = NSLock()
  private var count = 0
  var deliveries: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  init(provider: AssetProvider?) { self.provider = provider }
  deinit { provider?.remove(observer: self) }
  func processBalance(data: [BalanceData]) {
    lock.lock()
    count += 1
    lock.unlock()
  }
}
