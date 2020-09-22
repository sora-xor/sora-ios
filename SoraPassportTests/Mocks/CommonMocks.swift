import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation


public class MockDayChangeHandlerDelegate: DayChangeHandlerDelegate, Cuckoo.ProtocolMock {
    
    public typealias MocksType = DayChangeHandlerDelegate
    
    public typealias Stubbing = __StubbingProxy_DayChangeHandlerDelegate
    public typealias Verification = __VerificationProxy_DayChangeHandlerDelegate

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DayChangeHandlerDelegate?

    public func enableDefaultImplementation(_ stub: DayChangeHandlerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func handlerDidReceiveChange(_ handler: DayChangeHandlerProtocol)  {
        
    return cuckoo_manager.call("handlerDidReceiveChange(_: DayChangeHandlerProtocol)",
            parameters: (handler),
            escapingParameters: (handler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handlerDidReceiveChange(handler))
        
    }
    

	public struct __StubbingProxy_DayChangeHandlerDelegate: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func handlerDidReceiveChange<M1: Cuckoo.Matchable>(_ handler: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(DayChangeHandlerProtocol)> where M1.MatchedType == DayChangeHandlerProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(DayChangeHandlerProtocol)>] = [wrap(matchable: handler) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDayChangeHandlerDelegate.self, method: "handlerDidReceiveChange(_: DayChangeHandlerProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_DayChangeHandlerDelegate: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func handlerDidReceiveChange<M1: Cuckoo.Matchable>(_ handler: M1) -> Cuckoo.__DoNotUse<(DayChangeHandlerProtocol), Void> where M1.MatchedType == DayChangeHandlerProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(DayChangeHandlerProtocol)>] = [wrap(matchable: handler) { $0 }]
	        return cuckoo_manager.verify("handlerDidReceiveChange(_: DayChangeHandlerProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class DayChangeHandlerDelegateStub: DayChangeHandlerDelegate {
    

    

    
    public func handlerDidReceiveChange(_ handler: DayChangeHandlerProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockDayChangeHandlerProtocol: DayChangeHandlerProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = DayChangeHandlerProtocol
    
    public typealias Stubbing = __StubbingProxy_DayChangeHandlerProtocol
    public typealias Verification = __VerificationProxy_DayChangeHandlerProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DayChangeHandlerProtocol?

    public func enableDefaultImplementation(_ stub: DayChangeHandlerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var delegate: DayChangeHandlerDelegate? {
        get {
            return cuckoo_manager.getter("delegate",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.delegate)
        }
        
        set {
            cuckoo_manager.setter("delegate",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.delegate = newValue)
        }
        
    }
    

    

    

	public struct __StubbingProxy_DayChangeHandlerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var delegate: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockDayChangeHandlerProtocol, DayChangeHandlerDelegate> {
	        return .init(manager: cuckoo_manager, name: "delegate")
	    }
	    
	    
	}

	public struct __VerificationProxy_DayChangeHandlerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var delegate: Cuckoo.VerifyOptionalProperty<DayChangeHandlerDelegate> {
	        return .init(manager: cuckoo_manager, name: "delegate", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

public class DayChangeHandlerProtocolStub: DayChangeHandlerProtocol {
    
    
    public var delegate: DayChangeHandlerDelegate? {
        get {
            return DefaultValueRegistry.defaultValue(for: (DayChangeHandlerDelegate?).self)
        }
        
        set { }
        
    }
    

    

    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import UIKit


public class MockApplicationHandlerDelegate: ApplicationHandlerDelegate, Cuckoo.ProtocolMock {
    
    public typealias MocksType = ApplicationHandlerDelegate
    
    public typealias Stubbing = __StubbingProxy_ApplicationHandlerDelegate
    public typealias Verification = __VerificationProxy_ApplicationHandlerDelegate

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ApplicationHandlerDelegate?

    public func enableDefaultImplementation(_ stub: ApplicationHandlerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func didReceiveWillResignActive(notification: Notification)  {
        
    return cuckoo_manager.call("didReceiveWillResignActive(notification: Notification)",
            parameters: (notification),
            escapingParameters: (notification),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveWillResignActive!(notification: notification))
        
    }
    
    
    
    public func didReceiveDidBecomeActive(notification: Notification)  {
        
    return cuckoo_manager.call("didReceiveDidBecomeActive(notification: Notification)",
            parameters: (notification),
            escapingParameters: (notification),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveDidBecomeActive!(notification: notification))
        
    }
    
    
    
    public func didReceiveWillEnterForeground(notification: Notification)  {
        
    return cuckoo_manager.call("didReceiveWillEnterForeground(notification: Notification)",
            parameters: (notification),
            escapingParameters: (notification),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveWillEnterForeground!(notification: notification))
        
    }
    
    
    
    public func didReceiveDidEnterBackground(notification: Notification)  {
        
    return cuckoo_manager.call("didReceiveDidEnterBackground(notification: Notification)",
            parameters: (notification),
            escapingParameters: (notification),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveDidEnterBackground!(notification: notification))
        
    }
    

	public struct __StubbingProxy_ApplicationHandlerDelegate: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceiveWillResignActive<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Notification)> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockApplicationHandlerDelegate.self, method: "didReceiveWillResignActive(notification: Notification)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveDidBecomeActive<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Notification)> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockApplicationHandlerDelegate.self, method: "didReceiveDidBecomeActive(notification: Notification)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveWillEnterForeground<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Notification)> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockApplicationHandlerDelegate.self, method: "didReceiveWillEnterForeground(notification: Notification)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveDidEnterBackground<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Notification)> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockApplicationHandlerDelegate.self, method: "didReceiveDidEnterBackground(notification: Notification)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_ApplicationHandlerDelegate: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceiveWillResignActive<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.__DoNotUse<(Notification), Void> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return cuckoo_manager.verify("didReceiveWillResignActive(notification: Notification)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveDidBecomeActive<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.__DoNotUse<(Notification), Void> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return cuckoo_manager.verify("didReceiveDidBecomeActive(notification: Notification)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveWillEnterForeground<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.__DoNotUse<(Notification), Void> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return cuckoo_manager.verify("didReceiveWillEnterForeground(notification: Notification)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveDidEnterBackground<M1: Cuckoo.Matchable>(notification: M1) -> Cuckoo.__DoNotUse<(Notification), Void> where M1.MatchedType == Notification {
	        let matchers: [Cuckoo.ParameterMatcher<(Notification)>] = [wrap(matchable: notification) { $0 }]
	        return cuckoo_manager.verify("didReceiveDidEnterBackground(notification: Notification)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class ApplicationHandlerDelegateStub: ApplicationHandlerDelegate {
    

    

    
    public func didReceiveWillResignActive(notification: Notification)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func didReceiveDidBecomeActive(notification: Notification)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func didReceiveWillEnterForeground(notification: Notification)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func didReceiveDidEnterBackground(notification: Notification)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockApplicationHandlerProtocol: ApplicationHandlerProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = ApplicationHandlerProtocol
    
    public typealias Stubbing = __StubbingProxy_ApplicationHandlerProtocol
    public typealias Verification = __VerificationProxy_ApplicationHandlerProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ApplicationHandlerProtocol?

    public func enableDefaultImplementation(_ stub: ApplicationHandlerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var delegate: ApplicationHandlerDelegate? {
        get {
            return cuckoo_manager.getter("delegate",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.delegate)
        }
        
        set {
            cuckoo_manager.setter("delegate",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.delegate = newValue)
        }
        
    }
    

    

    

	public struct __StubbingProxy_ApplicationHandlerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var delegate: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockApplicationHandlerProtocol, ApplicationHandlerDelegate> {
	        return .init(manager: cuckoo_manager, name: "delegate")
	    }
	    
	    
	}

	public struct __VerificationProxy_ApplicationHandlerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var delegate: Cuckoo.VerifyOptionalProperty<ApplicationHandlerDelegate> {
	        return .init(manager: cuckoo_manager, name: "delegate", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

public class ApplicationHandlerProtocolStub: ApplicationHandlerProtocol {
    
    
    public var delegate: ApplicationHandlerDelegate? {
        get {
            return DefaultValueRegistry.defaultValue(for: (ApplicationHandlerDelegate?).self)
        }
        
        set { }
        
    }
    

    

    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation


public class MockCountdownTimerProtocol: CountdownTimerProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = CountdownTimerProtocol
    
    public typealias Stubbing = __StubbingProxy_CountdownTimerProtocol
    public typealias Verification = __VerificationProxy_CountdownTimerProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: CountdownTimerProtocol?

    public func enableDefaultImplementation(_ stub: CountdownTimerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var delegate: CountdownTimerDelegate? {
        get {
            return cuckoo_manager.getter("delegate",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.delegate)
        }
        
        set {
            cuckoo_manager.setter("delegate",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.delegate = newValue)
        }
        
    }
    
    
    
    public var state: CountdownTimerState {
        get {
            return cuckoo_manager.getter("state",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.state)
        }
        
    }
    
    
    
    public var notificationInterval: TimeInterval {
        get {
            return cuckoo_manager.getter("notificationInterval",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.notificationInterval)
        }
        
    }
    
    
    
    public var remainedInterval: TimeInterval {
        get {
            return cuckoo_manager.getter("remainedInterval",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.remainedInterval)
        }
        
    }
    

    

    
    
    
    public func start(with interval: TimeInterval)  {
        
    return cuckoo_manager.call("start(with: TimeInterval)",
            parameters: (interval),
            escapingParameters: (interval),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.start(with: interval))
        
    }
    
    
    
    public func stop()  {
        
    return cuckoo_manager.call("stop()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.stop())
        
    }
    

	public struct __StubbingProxy_CountdownTimerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var delegate: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockCountdownTimerProtocol, CountdownTimerDelegate> {
	        return .init(manager: cuckoo_manager, name: "delegate")
	    }
	    
	    
	    var state: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockCountdownTimerProtocol, CountdownTimerState> {
	        return .init(manager: cuckoo_manager, name: "state")
	    }
	    
	    
	    var notificationInterval: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockCountdownTimerProtocol, TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "notificationInterval")
	    }
	    
	    
	    var remainedInterval: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockCountdownTimerProtocol, TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "remainedInterval")
	    }
	    
	    
	    func start<M1: Cuckoo.Matchable>(with interval: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: interval) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCountdownTimerProtocol.self, method: "start(with: TimeInterval)", parameterMatchers: matchers))
	    }
	    
	    func stop() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockCountdownTimerProtocol.self, method: "stop()", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_CountdownTimerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var delegate: Cuckoo.VerifyOptionalProperty<CountdownTimerDelegate> {
	        return .init(manager: cuckoo_manager, name: "delegate", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var state: Cuckoo.VerifyReadOnlyProperty<CountdownTimerState> {
	        return .init(manager: cuckoo_manager, name: "state", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var notificationInterval: Cuckoo.VerifyReadOnlyProperty<TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "notificationInterval", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var remainedInterval: Cuckoo.VerifyReadOnlyProperty<TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "remainedInterval", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func start<M1: Cuckoo.Matchable>(with interval: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: interval) { $0 }]
	        return cuckoo_manager.verify("start(with: TimeInterval)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func stop() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("stop()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class CountdownTimerProtocolStub: CountdownTimerProtocol {
    
    
    public var delegate: CountdownTimerDelegate? {
        get {
            return DefaultValueRegistry.defaultValue(for: (CountdownTimerDelegate?).self)
        }
        
        set { }
        
    }
    
    
    public var state: CountdownTimerState {
        get {
            return DefaultValueRegistry.defaultValue(for: (CountdownTimerState).self)
        }
        
    }
    
    
    public var notificationInterval: TimeInterval {
        get {
            return DefaultValueRegistry.defaultValue(for: (TimeInterval).self)
        }
        
    }
    
    
    public var remainedInterval: TimeInterval {
        get {
            return DefaultValueRegistry.defaultValue(for: (TimeInterval).self)
        }
        
    }
    

    

    
    public func start(with interval: TimeInterval)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func stop()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockCountdownTimerDelegate: CountdownTimerDelegate, Cuckoo.ProtocolMock {
    
    public typealias MocksType = CountdownTimerDelegate
    
    public typealias Stubbing = __StubbingProxy_CountdownTimerDelegate
    public typealias Verification = __VerificationProxy_CountdownTimerDelegate

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: CountdownTimerDelegate?

    public func enableDefaultImplementation(_ stub: CountdownTimerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func didStart(with interval: TimeInterval)  {
        
    return cuckoo_manager.call("didStart(with: TimeInterval)",
            parameters: (interval),
            escapingParameters: (interval),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStart(with: interval))
        
    }
    
    
    
    public func didCountdown(remainedInterval: TimeInterval)  {
        
    return cuckoo_manager.call("didCountdown(remainedInterval: TimeInterval)",
            parameters: (remainedInterval),
            escapingParameters: (remainedInterval),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCountdown(remainedInterval: remainedInterval))
        
    }
    
    
    
    public func didStop(with remainedInterval: TimeInterval)  {
        
    return cuckoo_manager.call("didStop(with: TimeInterval)",
            parameters: (remainedInterval),
            escapingParameters: (remainedInterval),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStop(with: remainedInterval))
        
    }
    

	public struct __StubbingProxy_CountdownTimerDelegate: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didStart<M1: Cuckoo.Matchable>(with interval: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: interval) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCountdownTimerDelegate.self, method: "didStart(with: TimeInterval)", parameterMatchers: matchers))
	    }
	    
	    func didCountdown<M1: Cuckoo.Matchable>(remainedInterval: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: remainedInterval) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCountdownTimerDelegate.self, method: "didCountdown(remainedInterval: TimeInterval)", parameterMatchers: matchers))
	    }
	    
	    func didStop<M1: Cuckoo.Matchable>(with remainedInterval: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: remainedInterval) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCountdownTimerDelegate.self, method: "didStop(with: TimeInterval)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_CountdownTimerDelegate: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didStart<M1: Cuckoo.Matchable>(with interval: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: interval) { $0 }]
	        return cuckoo_manager.verify("didStart(with: TimeInterval)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCountdown<M1: Cuckoo.Matchable>(remainedInterval: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: remainedInterval) { $0 }]
	        return cuckoo_manager.verify("didCountdown(remainedInterval: TimeInterval)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStop<M1: Cuckoo.Matchable>(with remainedInterval: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: remainedInterval) { $0 }]
	        return cuckoo_manager.verify("didStop(with: TimeInterval)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class CountdownTimerDelegateStub: CountdownTimerDelegate {
    

    

    
    public func didStart(with interval: TimeInterval)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func didCountdown(remainedInterval: TimeInterval)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func didStop(with remainedInterval: TimeInterval)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation
import SoraCrypto
import os


 class MockApplicationConfigProtocol: ApplicationConfigProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ApplicationConfigProtocol
    
     typealias Stubbing = __StubbingProxy_ApplicationConfigProtocol
     typealias Verification = __VerificationProxy_ApplicationConfigProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ApplicationConfigProtocol?

     func enableDefaultImplementation(_ stub: ApplicationConfigProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var projectDecentralizedId: String {
        get {
            return cuckoo_manager.getter("projectDecentralizedId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.projectDecentralizedId)
        }
        
    }
    
    
    
     var notificationDecentralizedId: String {
        get {
            return cuckoo_manager.getter("notificationDecentralizedId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.notificationDecentralizedId)
        }
        
    }
    
    
    
     var notificationOptions: UInt8 {
        get {
            return cuckoo_manager.getter("notificationOptions",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.notificationOptions)
        }
        
    }
    
    
    
     var walletDecentralizedId: String {
        get {
            return cuckoo_manager.getter("walletDecentralizedId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.walletDecentralizedId)
        }
        
    }
    
    
    
     var didResolverUrl: String {
        get {
            return cuckoo_manager.getter("didResolverUrl",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.didResolverUrl)
        }
        
    }
    
    
    
     var decentralizedDomain: String {
        get {
            return cuckoo_manager.getter("decentralizedDomain",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.decentralizedDomain)
        }
        
    }
    
    
    
     var defaultProjectUnit: ServiceUnit {
        get {
            return cuckoo_manager.getter("defaultProjectUnit",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.defaultProjectUnit)
        }
        
    }
    
    
    
     var defaultNotificationUnit: ServiceUnit {
        get {
            return cuckoo_manager.getter("defaultNotificationUnit",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.defaultNotificationUnit)
        }
        
    }
    
    
    
     var defaultWalletUnit: ServiceUnit {
        get {
            return cuckoo_manager.getter("defaultWalletUnit",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.defaultWalletUnit)
        }
        
    }
    
    
    
     var defaultSoranetUnit: ServiceUnit {
        get {
            return cuckoo_manager.getter("defaultSoranetUnit",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.defaultSoranetUnit)
        }
        
    }
    
    
    
     var defaultStreamUnit: ServiceUnit {
        get {
            return cuckoo_manager.getter("defaultStreamUnit",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.defaultStreamUnit)
        }
        
    }
    
    
    
     var defaultCurrency: CurrencyItemData {
        get {
            return cuckoo_manager.getter("defaultCurrency",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.defaultCurrency)
        }
        
    }
    
    
    
     var soranetExplorerTemplate: String {
        get {
            return cuckoo_manager.getter("soranetExplorerTemplate",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.soranetExplorerTemplate)
        }
        
    }
    
    
    
     var ethereumExplorerTemplate: String {
        get {
            return cuckoo_manager.getter("ethereumExplorerTemplate",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.ethereumExplorerTemplate)
        }
        
    }
    
    
    
     var supportEmail: String {
        get {
            return cuckoo_manager.getter("supportEmail",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.supportEmail)
        }
        
    }
    
    
    
     var termsURL: URL {
        get {
            return cuckoo_manager.getter("termsURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.termsURL)
        }
        
    }
    
    
    
     var privacyPolicyURL: URL {
        get {
            return cuckoo_manager.getter("privacyPolicyURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.privacyPolicyURL)
        }
        
    }
    
    
    
     var version: String {
        get {
            return cuckoo_manager.getter("version",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.version)
        }
        
    }
    
    
    
     var invitationHostURL: URL {
        get {
            return cuckoo_manager.getter("invitationHostURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.invitationHostURL)
        }
        
    }
    
    
    
     var opensourceURL: URL {
        get {
            return cuckoo_manager.getter("opensourceURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.opensourceURL)
        }
        
    }
    
    
    
     var faqURL: URL {
        get {
            return cuckoo_manager.getter("faqURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.faqURL)
        }
        
    }
    
    
    
     var ethereumMasterContract: Data {
        get {
            return cuckoo_manager.getter("ethereumMasterContract",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.ethereumMasterContract)
        }
        
    }
    
    
    
     var ethereumNodeUrl: URL {
        get {
            return cuckoo_manager.getter("ethereumNodeUrl",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.ethereumNodeUrl)
        }
        
    }
    
    
    
     var ethereumChainId: EthereumChain {
        get {
            return cuckoo_manager.getter("ethereumChainId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.ethereumChainId)
        }
        
    }
    
    
    
     var ethereumPollingTimeInterval: TimeInterval {
        get {
            return cuckoo_manager.getter("ethereumPollingTimeInterval",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.ethereumPollingTimeInterval)
        }
        
    }
    
    
    
     var combinedTransfersHandlingDelay: TimeInterval {
        get {
            return cuckoo_manager.getter("combinedTransfersHandlingDelay",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.combinedTransfersHandlingDelay)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ApplicationConfigProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var projectDecentralizedId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "projectDecentralizedId")
	    }
	    
	    
	    var notificationDecentralizedId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "notificationDecentralizedId")
	    }
	    
	    
	    var notificationOptions: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, UInt8> {
	        return .init(manager: cuckoo_manager, name: "notificationOptions")
	    }
	    
	    
	    var walletDecentralizedId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "walletDecentralizedId")
	    }
	    
	    
	    var didResolverUrl: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "didResolverUrl")
	    }
	    
	    
	    var decentralizedDomain: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "decentralizedDomain")
	    }
	    
	    
	    var defaultProjectUnit: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultProjectUnit")
	    }
	    
	    
	    var defaultNotificationUnit: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultNotificationUnit")
	    }
	    
	    
	    var defaultWalletUnit: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultWalletUnit")
	    }
	    
	    
	    var defaultSoranetUnit: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultSoranetUnit")
	    }
	    
	    
	    var defaultStreamUnit: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultStreamUnit")
	    }
	    
	    
	    var defaultCurrency: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, CurrencyItemData> {
	        return .init(manager: cuckoo_manager, name: "defaultCurrency")
	    }
	    
	    
	    var soranetExplorerTemplate: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "soranetExplorerTemplate")
	    }
	    
	    
	    var ethereumExplorerTemplate: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "ethereumExplorerTemplate")
	    }
	    
	    
	    var supportEmail: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "supportEmail")
	    }
	    
	    
	    var termsURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "termsURL")
	    }
	    
	    
	    var privacyPolicyURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "privacyPolicyURL")
	    }
	    
	    
	    var version: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "version")
	    }
	    
	    
	    var invitationHostURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "invitationHostURL")
	    }
	    
	    
	    var opensourceURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "opensourceURL")
	    }
	    
	    
	    var faqURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "faqURL")
	    }
	    
	    
	    var ethereumMasterContract: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, Data> {
	        return .init(manager: cuckoo_manager, name: "ethereumMasterContract")
	    }
	    
	    
	    var ethereumNodeUrl: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "ethereumNodeUrl")
	    }
	    
	    
	    var ethereumChainId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, EthereumChain> {
	        return .init(manager: cuckoo_manager, name: "ethereumChainId")
	    }
	    
	    
	    var ethereumPollingTimeInterval: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "ethereumPollingTimeInterval")
	    }
	    
	    
	    var combinedTransfersHandlingDelay: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "combinedTransfersHandlingDelay")
	    }
	    
	    
	}

	 struct __VerificationProxy_ApplicationConfigProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var projectDecentralizedId: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "projectDecentralizedId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var notificationDecentralizedId: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "notificationDecentralizedId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var notificationOptions: Cuckoo.VerifyReadOnlyProperty<UInt8> {
	        return .init(manager: cuckoo_manager, name: "notificationOptions", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var walletDecentralizedId: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "walletDecentralizedId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var didResolverUrl: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "didResolverUrl", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var decentralizedDomain: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "decentralizedDomain", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var defaultProjectUnit: Cuckoo.VerifyReadOnlyProperty<ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultProjectUnit", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var defaultNotificationUnit: Cuckoo.VerifyReadOnlyProperty<ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultNotificationUnit", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var defaultWalletUnit: Cuckoo.VerifyReadOnlyProperty<ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultWalletUnit", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var defaultSoranetUnit: Cuckoo.VerifyReadOnlyProperty<ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultSoranetUnit", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var defaultStreamUnit: Cuckoo.VerifyReadOnlyProperty<ServiceUnit> {
	        return .init(manager: cuckoo_manager, name: "defaultStreamUnit", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var defaultCurrency: Cuckoo.VerifyReadOnlyProperty<CurrencyItemData> {
	        return .init(manager: cuckoo_manager, name: "defaultCurrency", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var soranetExplorerTemplate: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "soranetExplorerTemplate", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var ethereumExplorerTemplate: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "ethereumExplorerTemplate", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var supportEmail: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "supportEmail", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var termsURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "termsURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var privacyPolicyURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "privacyPolicyURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var version: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "version", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var invitationHostURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "invitationHostURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var opensourceURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "opensourceURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var faqURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "faqURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var ethereumMasterContract: Cuckoo.VerifyReadOnlyProperty<Data> {
	        return .init(manager: cuckoo_manager, name: "ethereumMasterContract", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var ethereumNodeUrl: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "ethereumNodeUrl", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var ethereumChainId: Cuckoo.VerifyReadOnlyProperty<EthereumChain> {
	        return .init(manager: cuckoo_manager, name: "ethereumChainId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var ethereumPollingTimeInterval: Cuckoo.VerifyReadOnlyProperty<TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "ethereumPollingTimeInterval", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var combinedTransfersHandlingDelay: Cuckoo.VerifyReadOnlyProperty<TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "combinedTransfersHandlingDelay", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ApplicationConfigProtocolStub: ApplicationConfigProtocol {
    
    
     var projectDecentralizedId: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var notificationDecentralizedId: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var notificationOptions: UInt8 {
        get {
            return DefaultValueRegistry.defaultValue(for: (UInt8).self)
        }
        
    }
    
    
     var walletDecentralizedId: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var didResolverUrl: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var decentralizedDomain: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var defaultProjectUnit: ServiceUnit {
        get {
            return DefaultValueRegistry.defaultValue(for: (ServiceUnit).self)
        }
        
    }
    
    
     var defaultNotificationUnit: ServiceUnit {
        get {
            return DefaultValueRegistry.defaultValue(for: (ServiceUnit).self)
        }
        
    }
    
    
     var defaultWalletUnit: ServiceUnit {
        get {
            return DefaultValueRegistry.defaultValue(for: (ServiceUnit).self)
        }
        
    }
    
    
     var defaultSoranetUnit: ServiceUnit {
        get {
            return DefaultValueRegistry.defaultValue(for: (ServiceUnit).self)
        }
        
    }
    
    
     var defaultStreamUnit: ServiceUnit {
        get {
            return DefaultValueRegistry.defaultValue(for: (ServiceUnit).self)
        }
        
    }
    
    
     var defaultCurrency: CurrencyItemData {
        get {
            return DefaultValueRegistry.defaultValue(for: (CurrencyItemData).self)
        }
        
    }
    
    
     var soranetExplorerTemplate: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var ethereumExplorerTemplate: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var supportEmail: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var termsURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var privacyPolicyURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var version: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    
    
     var invitationHostURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var opensourceURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var faqURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var ethereumMasterContract: Data {
        get {
            return DefaultValueRegistry.defaultValue(for: (Data).self)
        }
        
    }
    
    
     var ethereumNodeUrl: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var ethereumChainId: EthereumChain {
        get {
            return DefaultValueRegistry.defaultValue(for: (EthereumChain).self)
        }
        
    }
    
    
     var ethereumPollingTimeInterval: TimeInterval {
        get {
            return DefaultValueRegistry.defaultValue(for: (TimeInterval).self)
        }
        
    }
    
    
     var combinedTransfersHandlingDelay: TimeInterval {
        get {
            return DefaultValueRegistry.defaultValue(for: (TimeInterval).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation


 class MockDataStreamHandling: DataStreamHandling, Cuckoo.ProtocolMock {
    
     typealias MocksType = DataStreamHandling
    
     typealias Stubbing = __StubbingProxy_DataStreamHandling
     typealias Verification = __VerificationProxy_DataStreamHandling

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DataStreamHandling?

     func enableDefaultImplementation(_ stub: DataStreamHandling) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(remoteEvent: Data)  {
        
    return cuckoo_manager.call("didReceive(remoteEvent: Data)",
            parameters: (remoteEvent),
            escapingParameters: (remoteEvent),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(remoteEvent: remoteEvent))
        
    }
    
    
    
     func didReceiveSyncRequest()  {
        
    return cuckoo_manager.call("didReceiveSyncRequest()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveSyncRequest())
        
    }
    

	 struct __StubbingProxy_DataStreamHandling: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(remoteEvent: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Data)> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: remoteEvent) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDataStreamHandling.self, method: "didReceive(remoteEvent: Data)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveSyncRequest() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockDataStreamHandling.self, method: "didReceiveSyncRequest()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DataStreamHandling: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(remoteEvent: M1) -> Cuckoo.__DoNotUse<(Data), Void> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: remoteEvent) { $0 }]
	        return cuckoo_manager.verify("didReceive(remoteEvent: Data)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveSyncRequest() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReceiveSyncRequest()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DataStreamHandlingStub: DataStreamHandling {
    

    

    
     func didReceive(remoteEvent: Data)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveSyncRequest()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockDataStreamProcessing: DataStreamProcessing, Cuckoo.ProtocolMock {
    
     typealias MocksType = DataStreamProcessing
    
     typealias Stubbing = __StubbingProxy_DataStreamProcessing
     typealias Verification = __VerificationProxy_DataStreamProcessing

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DataStreamProcessing?

     func enableDefaultImplementation(_ stub: DataStreamProcessing) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func process(event: DataStreamOneOfEvent)  {
        
    return cuckoo_manager.call("process(event: DataStreamOneOfEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.process(event: event))
        
    }
    
    
    
     func processOutOfSync()  {
        
    return cuckoo_manager.call("processOutOfSync()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processOutOfSync())
        
    }
    

	 struct __StubbingProxy_DataStreamProcessing: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func process<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(DataStreamOneOfEvent)> where M1.MatchedType == DataStreamOneOfEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(DataStreamOneOfEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDataStreamProcessing.self, method: "process(event: DataStreamOneOfEvent)", parameterMatchers: matchers))
	    }
	    
	    func processOutOfSync() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockDataStreamProcessing.self, method: "processOutOfSync()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DataStreamProcessing: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func process<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(DataStreamOneOfEvent), Void> where M1.MatchedType == DataStreamOneOfEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(DataStreamOneOfEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("process(event: DataStreamOneOfEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processOutOfSync() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("processOutOfSync()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DataStreamProcessingStub: DataStreamProcessing {
    

    

    
     func process(event: DataStreamOneOfEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processOutOfSync()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation
import RobinHood
import SoraCrypto
import SoraFoundation
import SoraKeystore


 class MockDataStreamServiceProtocol: DataStreamServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DataStreamServiceProtocol
    
     typealias Stubbing = __StubbingProxy_DataStreamServiceProtocol
     typealias Verification = __VerificationProxy_DataStreamServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DataStreamServiceProtocol?

     func enableDefaultImplementation(_ stub: DataStreamServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var handler: DataStreamHandling {
        get {
            return cuckoo_manager.getter("handler",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.handler)
        }
        
    }
    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func throttle()  {
        
    return cuckoo_manager.call("throttle()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.throttle())
        
    }
    

	 struct __StubbingProxy_DataStreamServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockDataStreamServiceProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var handler: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockDataStreamServiceProtocol, DataStreamHandling> {
	        return .init(manager: cuckoo_manager, name: "handler")
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockDataStreamServiceProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func throttle() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockDataStreamServiceProtocol.self, method: "throttle()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DataStreamServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var handler: Cuckoo.VerifyReadOnlyProperty<DataStreamHandling> {
	        return .init(manager: cuckoo_manager, name: "handler", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func throttle() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("throttle()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DataStreamServiceProtocolStub: DataStreamServiceProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var handler: DataStreamHandling {
        get {
            return DefaultValueRegistry.defaultValue(for: (DataStreamHandling).self)
        }
        
    }
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func throttle()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation
import RobinHood
import SoraCrypto


 class MockDecentralizedResolverOperationFactoryProtocol: DecentralizedResolverOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DecentralizedResolverOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_DecentralizedResolverOperationFactoryProtocol
     typealias Verification = __VerificationProxy_DecentralizedResolverOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DecentralizedResolverOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: DecentralizedResolverOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createDecentralizedDocumentFetchOperation(decentralizedId: String) -> NetworkOperation<DecentralizedDocumentObject> {
        
    return cuckoo_manager.call("createDecentralizedDocumentFetchOperation(decentralizedId: String) -> NetworkOperation<DecentralizedDocumentObject>",
            parameters: (decentralizedId),
            escapingParameters: (decentralizedId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createDecentralizedDocumentFetchOperation(decentralizedId: decentralizedId))
        
    }
    
    
    
     func createDecentralizedDocumentOperation(with documentConfigBlock: @escaping DocumentConfigurationBlock) -> NetworkOperation<Bool> {
        
    return cuckoo_manager.call("createDecentralizedDocumentOperation(with: @escaping DocumentConfigurationBlock) -> NetworkOperation<Bool>",
            parameters: (documentConfigBlock),
            escapingParameters: (documentConfigBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createDecentralizedDocumentOperation(with: documentConfigBlock))
        
    }
    

	 struct __StubbingProxy_DecentralizedResolverOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createDecentralizedDocumentFetchOperation<M1: Cuckoo.Matchable>(decentralizedId: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<DecentralizedDocumentObject>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: decentralizedId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDecentralizedResolverOperationFactoryProtocol.self, method: "createDecentralizedDocumentFetchOperation(decentralizedId: String) -> NetworkOperation<DecentralizedDocumentObject>", parameterMatchers: matchers))
	    }
	    
	    func createDecentralizedDocumentOperation<M1: Cuckoo.Matchable>(with documentConfigBlock: M1) -> Cuckoo.ProtocolStubFunction<(DocumentConfigurationBlock), NetworkOperation<Bool>> where M1.MatchedType == DocumentConfigurationBlock {
	        let matchers: [Cuckoo.ParameterMatcher<(DocumentConfigurationBlock)>] = [wrap(matchable: documentConfigBlock) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDecentralizedResolverOperationFactoryProtocol.self, method: "createDecentralizedDocumentOperation(with: @escaping DocumentConfigurationBlock) -> NetworkOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DecentralizedResolverOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createDecentralizedDocumentFetchOperation<M1: Cuckoo.Matchable>(decentralizedId: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<DecentralizedDocumentObject>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: decentralizedId) { $0 }]
	        return cuckoo_manager.verify("createDecentralizedDocumentFetchOperation(decentralizedId: String) -> NetworkOperation<DecentralizedDocumentObject>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createDecentralizedDocumentOperation<M1: Cuckoo.Matchable>(with documentConfigBlock: M1) -> Cuckoo.__DoNotUse<(DocumentConfigurationBlock), NetworkOperation<Bool>> where M1.MatchedType == DocumentConfigurationBlock {
	        let matchers: [Cuckoo.ParameterMatcher<(DocumentConfigurationBlock)>] = [wrap(matchable: documentConfigBlock) { $0 }]
	        return cuckoo_manager.verify("createDecentralizedDocumentOperation(with: @escaping DocumentConfigurationBlock) -> NetworkOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DecentralizedResolverOperationFactoryProtocolStub: DecentralizedResolverOperationFactoryProtocol {
    

    

    
     func createDecentralizedDocumentFetchOperation(decentralizedId: String) -> NetworkOperation<DecentralizedDocumentObject>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<DecentralizedDocumentObject>).self)
    }
    
     func createDecentralizedDocumentOperation(with documentConfigBlock: @escaping DocumentConfigurationBlock) -> NetworkOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Bool>).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import BigInt
import Foundation
import RobinHood
import web3swift


 class MockEthereumOperationFactoryProtocol: EthereumOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EthereumOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_EthereumOperationFactoryProtocol
     typealias Verification = __VerificationProxy_EthereumOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EthereumOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: EthereumOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createEthBalanceFetchOperation(for accountAddress: Data?) -> BaseOperation<BigUInt> {
        
    return cuckoo_manager.call("createEthBalanceFetchOperation(for: Data?) -> BaseOperation<BigUInt>",
            parameters: (accountAddress),
            escapingParameters: (accountAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createEthBalanceFetchOperation(for: accountAddress))
        
    }
    
    
    
     func createERC20TokenBalanceFetchOperation(from tokenAddressConfig: @escaping EthAddressConfig, for accountAddress: Data?) -> BaseOperation<BigUInt> {
        
    return cuckoo_manager.call("createERC20TokenBalanceFetchOperation(from: @escaping EthAddressConfig, for: Data?) -> BaseOperation<BigUInt>",
            parameters: (tokenAddressConfig, accountAddress),
            escapingParameters: (tokenAddressConfig, accountAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createERC20TokenBalanceFetchOperation(from: tokenAddressConfig, for: accountAddress))
        
    }
    
    
    
     func createXORAddressFetchOperation(from masterContractAddress: Data) -> BaseOperation<Data> {
        
    return cuckoo_manager.call("createXORAddressFetchOperation(from: Data) -> BaseOperation<Data>",
            parameters: (masterContractAddress),
            escapingParameters: (masterContractAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createXORAddressFetchOperation(from: masterContractAddress))
        
    }
    
    
    
     func createGasLimitOperation(for transactionConfig: @escaping EthPreparedTransactionConfig) -> BaseOperation<BigUInt> {
        
    return cuckoo_manager.call("createGasLimitOperation(for: @escaping EthPreparedTransactionConfig) -> BaseOperation<BigUInt>",
            parameters: (transactionConfig),
            escapingParameters: (transactionConfig),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createGasLimitOperation(for: transactionConfig))
        
    }
    
    
    
     func createGasPriceOperation() -> BaseOperation<BigUInt> {
        
    return cuckoo_manager.call("createGasPriceOperation() -> BaseOperation<BigUInt>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createGasPriceOperation())
        
    }
    
    
    
     func createTransactionsCountOperation(for accountAddress: Data?, block: EthereumBlock) -> BaseOperation<BigUInt> {
        
    return cuckoo_manager.call("createTransactionsCountOperation(for: Data?, block: EthereumBlock) -> BaseOperation<BigUInt>",
            parameters: (accountAddress, block),
            escapingParameters: (accountAddress, block),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createTransactionsCountOperation(for: accountAddress, block: block))
        
    }
    
    
    
     func createWithdrawalCheckOperation(for hashConfig: @escaping EthWithdrawHashConfig, masterContractAddress: Data) -> BaseOperation<Bool> {
        
    return cuckoo_manager.call("createWithdrawalCheckOperation(for: @escaping EthWithdrawHashConfig, masterContractAddress: Data) -> BaseOperation<Bool>",
            parameters: (hashConfig, masterContractAddress),
            escapingParameters: (hashConfig, masterContractAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createWithdrawalCheckOperation(for: hashConfig, masterContractAddress: masterContractAddress))
        
    }
    
    
    
     func createWithdrawTransactionOperation(for withdrawInfoConfig: @escaping EthWithdrawInfoConfig, tokenAddressConfig: @escaping EthAddressConfig, masterContractAddress: Data) -> BaseOperation<Data> {
        
    return cuckoo_manager.call("createWithdrawTransactionOperation(for: @escaping EthWithdrawInfoConfig, tokenAddressConfig: @escaping EthAddressConfig, masterContractAddress: Data) -> BaseOperation<Data>",
            parameters: (withdrawInfoConfig, tokenAddressConfig, masterContractAddress),
            escapingParameters: (withdrawInfoConfig, tokenAddressConfig, masterContractAddress),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createWithdrawTransactionOperation(for: withdrawInfoConfig, tokenAddressConfig: tokenAddressConfig, masterContractAddress: masterContractAddress))
        
    }
    
    
    
     func createERC20TransferTransactionOperation(for config: @escaping EthERC20TransferConfig) -> BaseOperation<Data> {
        
    return cuckoo_manager.call("createERC20TransferTransactionOperation(for: @escaping EthERC20TransferConfig) -> BaseOperation<Data>",
            parameters: (config),
            escapingParameters: (config),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createERC20TransferTransactionOperation(for: config))
        
    }
    
    
    
     func createSendTransactionOperation(for transactionInfoConfig: @escaping EthReadyTransactionConfig) -> BaseOperation<Data> {
        
    return cuckoo_manager.call("createSendTransactionOperation(for: @escaping EthReadyTransactionConfig) -> BaseOperation<Data>",
            parameters: (transactionInfoConfig),
            escapingParameters: (transactionInfoConfig),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createSendTransactionOperation(for: transactionInfoConfig))
        
    }
    
    
    
     func createTransactionByHashFetchOperation(_ transactionHash: Data) -> BaseOperation<TransactionDetails?> {
        
    return cuckoo_manager.call("createTransactionByHashFetchOperation(_: Data) -> BaseOperation<TransactionDetails?>",
            parameters: (transactionHash),
            escapingParameters: (transactionHash),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createTransactionByHashFetchOperation(transactionHash))
        
    }
    

	 struct __StubbingProxy_EthereumOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createEthBalanceFetchOperation<M1: Cuckoo.OptionalMatchable>(for accountAddress: M1) -> Cuckoo.ProtocolStubFunction<(Data?), BaseOperation<BigUInt>> where M1.OptionalMatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data?)>] = [wrap(matchable: accountAddress) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createEthBalanceFetchOperation(for: Data?) -> BaseOperation<BigUInt>", parameterMatchers: matchers))
	    }
	    
	    func createERC20TokenBalanceFetchOperation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(from tokenAddressConfig: M1, for accountAddress: M2) -> Cuckoo.ProtocolStubFunction<(EthAddressConfig, Data?), BaseOperation<BigUInt>> where M1.MatchedType == EthAddressConfig, M2.OptionalMatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(EthAddressConfig, Data?)>] = [wrap(matchable: tokenAddressConfig) { $0.0 }, wrap(matchable: accountAddress) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createERC20TokenBalanceFetchOperation(from: @escaping EthAddressConfig, for: Data?) -> BaseOperation<BigUInt>", parameterMatchers: matchers))
	    }
	    
	    func createXORAddressFetchOperation<M1: Cuckoo.Matchable>(from masterContractAddress: M1) -> Cuckoo.ProtocolStubFunction<(Data), BaseOperation<Data>> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: masterContractAddress) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createXORAddressFetchOperation(from: Data) -> BaseOperation<Data>", parameterMatchers: matchers))
	    }
	    
	    func createGasLimitOperation<M1: Cuckoo.Matchable>(for transactionConfig: M1) -> Cuckoo.ProtocolStubFunction<(EthPreparedTransactionConfig), BaseOperation<BigUInt>> where M1.MatchedType == EthPreparedTransactionConfig {
	        let matchers: [Cuckoo.ParameterMatcher<(EthPreparedTransactionConfig)>] = [wrap(matchable: transactionConfig) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createGasLimitOperation(for: @escaping EthPreparedTransactionConfig) -> BaseOperation<BigUInt>", parameterMatchers: matchers))
	    }
	    
	    func createGasPriceOperation() -> Cuckoo.ProtocolStubFunction<(), BaseOperation<BigUInt>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createGasPriceOperation() -> BaseOperation<BigUInt>", parameterMatchers: matchers))
	    }
	    
	    func createTransactionsCountOperation<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for accountAddress: M1, block: M2) -> Cuckoo.ProtocolStubFunction<(Data?, EthereumBlock), BaseOperation<BigUInt>> where M1.OptionalMatchedType == Data, M2.MatchedType == EthereumBlock {
	        let matchers: [Cuckoo.ParameterMatcher<(Data?, EthereumBlock)>] = [wrap(matchable: accountAddress) { $0.0 }, wrap(matchable: block) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createTransactionsCountOperation(for: Data?, block: EthereumBlock) -> BaseOperation<BigUInt>", parameterMatchers: matchers))
	    }
	    
	    func createWithdrawalCheckOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for hashConfig: M1, masterContractAddress: M2) -> Cuckoo.ProtocolStubFunction<(EthWithdrawHashConfig, Data), BaseOperation<Bool>> where M1.MatchedType == EthWithdrawHashConfig, M2.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(EthWithdrawHashConfig, Data)>] = [wrap(matchable: hashConfig) { $0.0 }, wrap(matchable: masterContractAddress) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createWithdrawalCheckOperation(for: @escaping EthWithdrawHashConfig, masterContractAddress: Data) -> BaseOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	    func createWithdrawTransactionOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for withdrawInfoConfig: M1, tokenAddressConfig: M2, masterContractAddress: M3) -> Cuckoo.ProtocolStubFunction<(EthWithdrawInfoConfig, EthAddressConfig, Data), BaseOperation<Data>> where M1.MatchedType == EthWithdrawInfoConfig, M2.MatchedType == EthAddressConfig, M3.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(EthWithdrawInfoConfig, EthAddressConfig, Data)>] = [wrap(matchable: withdrawInfoConfig) { $0.0 }, wrap(matchable: tokenAddressConfig) { $0.1 }, wrap(matchable: masterContractAddress) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createWithdrawTransactionOperation(for: @escaping EthWithdrawInfoConfig, tokenAddressConfig: @escaping EthAddressConfig, masterContractAddress: Data) -> BaseOperation<Data>", parameterMatchers: matchers))
	    }
	    
	    func createERC20TransferTransactionOperation<M1: Cuckoo.Matchable>(for config: M1) -> Cuckoo.ProtocolStubFunction<(EthERC20TransferConfig), BaseOperation<Data>> where M1.MatchedType == EthERC20TransferConfig {
	        let matchers: [Cuckoo.ParameterMatcher<(EthERC20TransferConfig)>] = [wrap(matchable: config) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createERC20TransferTransactionOperation(for: @escaping EthERC20TransferConfig) -> BaseOperation<Data>", parameterMatchers: matchers))
	    }
	    
	    func createSendTransactionOperation<M1: Cuckoo.Matchable>(for transactionInfoConfig: M1) -> Cuckoo.ProtocolStubFunction<(EthReadyTransactionConfig), BaseOperation<Data>> where M1.MatchedType == EthReadyTransactionConfig {
	        let matchers: [Cuckoo.ParameterMatcher<(EthReadyTransactionConfig)>] = [wrap(matchable: transactionInfoConfig) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createSendTransactionOperation(for: @escaping EthReadyTransactionConfig) -> BaseOperation<Data>", parameterMatchers: matchers))
	    }
	    
	    func createTransactionByHashFetchOperation<M1: Cuckoo.Matchable>(_ transactionHash: M1) -> Cuckoo.ProtocolStubFunction<(Data), BaseOperation<TransactionDetails?>> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: transactionHash) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEthereumOperationFactoryProtocol.self, method: "createTransactionByHashFetchOperation(_: Data) -> BaseOperation<TransactionDetails?>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_EthereumOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createEthBalanceFetchOperation<M1: Cuckoo.OptionalMatchable>(for accountAddress: M1) -> Cuckoo.__DoNotUse<(Data?), BaseOperation<BigUInt>> where M1.OptionalMatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data?)>] = [wrap(matchable: accountAddress) { $0 }]
	        return cuckoo_manager.verify("createEthBalanceFetchOperation(for: Data?) -> BaseOperation<BigUInt>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createERC20TokenBalanceFetchOperation<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(from tokenAddressConfig: M1, for accountAddress: M2) -> Cuckoo.__DoNotUse<(EthAddressConfig, Data?), BaseOperation<BigUInt>> where M1.MatchedType == EthAddressConfig, M2.OptionalMatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(EthAddressConfig, Data?)>] = [wrap(matchable: tokenAddressConfig) { $0.0 }, wrap(matchable: accountAddress) { $0.1 }]
	        return cuckoo_manager.verify("createERC20TokenBalanceFetchOperation(from: @escaping EthAddressConfig, for: Data?) -> BaseOperation<BigUInt>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createXORAddressFetchOperation<M1: Cuckoo.Matchable>(from masterContractAddress: M1) -> Cuckoo.__DoNotUse<(Data), BaseOperation<Data>> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: masterContractAddress) { $0 }]
	        return cuckoo_manager.verify("createXORAddressFetchOperation(from: Data) -> BaseOperation<Data>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createGasLimitOperation<M1: Cuckoo.Matchable>(for transactionConfig: M1) -> Cuckoo.__DoNotUse<(EthPreparedTransactionConfig), BaseOperation<BigUInt>> where M1.MatchedType == EthPreparedTransactionConfig {
	        let matchers: [Cuckoo.ParameterMatcher<(EthPreparedTransactionConfig)>] = [wrap(matchable: transactionConfig) { $0 }]
	        return cuckoo_manager.verify("createGasLimitOperation(for: @escaping EthPreparedTransactionConfig) -> BaseOperation<BigUInt>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createGasPriceOperation() -> Cuckoo.__DoNotUse<(), BaseOperation<BigUInt>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("createGasPriceOperation() -> BaseOperation<BigUInt>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createTransactionsCountOperation<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for accountAddress: M1, block: M2) -> Cuckoo.__DoNotUse<(Data?, EthereumBlock), BaseOperation<BigUInt>> where M1.OptionalMatchedType == Data, M2.MatchedType == EthereumBlock {
	        let matchers: [Cuckoo.ParameterMatcher<(Data?, EthereumBlock)>] = [wrap(matchable: accountAddress) { $0.0 }, wrap(matchable: block) { $0.1 }]
	        return cuckoo_manager.verify("createTransactionsCountOperation(for: Data?, block: EthereumBlock) -> BaseOperation<BigUInt>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createWithdrawalCheckOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for hashConfig: M1, masterContractAddress: M2) -> Cuckoo.__DoNotUse<(EthWithdrawHashConfig, Data), BaseOperation<Bool>> where M1.MatchedType == EthWithdrawHashConfig, M2.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(EthWithdrawHashConfig, Data)>] = [wrap(matchable: hashConfig) { $0.0 }, wrap(matchable: masterContractAddress) { $0.1 }]
	        return cuckoo_manager.verify("createWithdrawalCheckOperation(for: @escaping EthWithdrawHashConfig, masterContractAddress: Data) -> BaseOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createWithdrawTransactionOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for withdrawInfoConfig: M1, tokenAddressConfig: M2, masterContractAddress: M3) -> Cuckoo.__DoNotUse<(EthWithdrawInfoConfig, EthAddressConfig, Data), BaseOperation<Data>> where M1.MatchedType == EthWithdrawInfoConfig, M2.MatchedType == EthAddressConfig, M3.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(EthWithdrawInfoConfig, EthAddressConfig, Data)>] = [wrap(matchable: withdrawInfoConfig) { $0.0 }, wrap(matchable: tokenAddressConfig) { $0.1 }, wrap(matchable: masterContractAddress) { $0.2 }]
	        return cuckoo_manager.verify("createWithdrawTransactionOperation(for: @escaping EthWithdrawInfoConfig, tokenAddressConfig: @escaping EthAddressConfig, masterContractAddress: Data) -> BaseOperation<Data>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createERC20TransferTransactionOperation<M1: Cuckoo.Matchable>(for config: M1) -> Cuckoo.__DoNotUse<(EthERC20TransferConfig), BaseOperation<Data>> where M1.MatchedType == EthERC20TransferConfig {
	        let matchers: [Cuckoo.ParameterMatcher<(EthERC20TransferConfig)>] = [wrap(matchable: config) { $0 }]
	        return cuckoo_manager.verify("createERC20TransferTransactionOperation(for: @escaping EthERC20TransferConfig) -> BaseOperation<Data>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createSendTransactionOperation<M1: Cuckoo.Matchable>(for transactionInfoConfig: M1) -> Cuckoo.__DoNotUse<(EthReadyTransactionConfig), BaseOperation<Data>> where M1.MatchedType == EthReadyTransactionConfig {
	        let matchers: [Cuckoo.ParameterMatcher<(EthReadyTransactionConfig)>] = [wrap(matchable: transactionInfoConfig) { $0 }]
	        return cuckoo_manager.verify("createSendTransactionOperation(for: @escaping EthReadyTransactionConfig) -> BaseOperation<Data>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createTransactionByHashFetchOperation<M1: Cuckoo.Matchable>(_ transactionHash: M1) -> Cuckoo.__DoNotUse<(Data), BaseOperation<TransactionDetails?>> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: transactionHash) { $0 }]
	        return cuckoo_manager.verify("createTransactionByHashFetchOperation(_: Data) -> BaseOperation<TransactionDetails?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class EthereumOperationFactoryProtocolStub: EthereumOperationFactoryProtocol {
    

    

    
     func createEthBalanceFetchOperation(for accountAddress: Data?) -> BaseOperation<BigUInt>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<BigUInt>).self)
    }
    
     func createERC20TokenBalanceFetchOperation(from tokenAddressConfig: @escaping EthAddressConfig, for accountAddress: Data?) -> BaseOperation<BigUInt>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<BigUInt>).self)
    }
    
     func createXORAddressFetchOperation(from masterContractAddress: Data) -> BaseOperation<Data>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
    
     func createGasLimitOperation(for transactionConfig: @escaping EthPreparedTransactionConfig) -> BaseOperation<BigUInt>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<BigUInt>).self)
    }
    
     func createGasPriceOperation() -> BaseOperation<BigUInt>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<BigUInt>).self)
    }
    
     func createTransactionsCountOperation(for accountAddress: Data?, block: EthereumBlock) -> BaseOperation<BigUInt>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<BigUInt>).self)
    }
    
     func createWithdrawalCheckOperation(for hashConfig: @escaping EthWithdrawHashConfig, masterContractAddress: Data) -> BaseOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Bool>).self)
    }
    
     func createWithdrawTransactionOperation(for withdrawInfoConfig: @escaping EthWithdrawInfoConfig, tokenAddressConfig: @escaping EthAddressConfig, masterContractAddress: Data) -> BaseOperation<Data>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
    
     func createERC20TransferTransactionOperation(for config: @escaping EthERC20TransferConfig) -> BaseOperation<Data>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
    
     func createSendTransactionOperation(for transactionInfoConfig: @escaping EthReadyTransactionConfig) -> BaseOperation<Data>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
    
     func createTransactionByHashFetchOperation(_ transactionHash: Data) -> BaseOperation<TransactionDetails?>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<TransactionDetails?>).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation
import RobinHood


 class MockProjectFundingOperationFactoryProtocol: ProjectFundingOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProjectFundingOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_ProjectFundingOperationFactoryProtocol
     typealias Verification = __VerificationProxy_ProjectFundingOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProjectFundingOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: ProjectFundingOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func fetchProjectsOperation(_ urlTemplate: String, pagination: OffsetPagination) -> NetworkOperation<[ProjectData]> {
        
    return cuckoo_manager.call("fetchProjectsOperation(_: String, pagination: OffsetPagination) -> NetworkOperation<[ProjectData]>",
            parameters: (urlTemplate, pagination),
            escapingParameters: (urlTemplate, pagination),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchProjectsOperation(urlTemplate, pagination: pagination))
        
    }
    
    
    
     func fetchReferendumsOperation(_ urlTemplate: String) -> NetworkOperation<[ReferendumData]> {
        
    return cuckoo_manager.call("fetchReferendumsOperation(_: String) -> NetworkOperation<[ReferendumData]>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchReferendumsOperation(urlTemplate))
        
    }
    
    
    
     func fetchProjectDetailsOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<ProjectDetailsData?> {
        
    return cuckoo_manager.call("fetchProjectDetailsOperation(_: String, projectId: String) -> NetworkOperation<ProjectDetailsData?>",
            parameters: (urlTemplate, projectId),
            escapingParameters: (urlTemplate, projectId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchProjectDetailsOperation(urlTemplate, projectId: projectId))
        
    }
    
    
    
     func fetchReferendumDetailsOperation(_ urlTemplate: String, referendumId: String) -> NetworkOperation<ReferendumData?> {
        
    return cuckoo_manager.call("fetchReferendumDetailsOperation(_: String, referendumId: String) -> NetworkOperation<ReferendumData?>",
            parameters: (urlTemplate, referendumId),
            escapingParameters: (urlTemplate, referendumId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchReferendumDetailsOperation(urlTemplate, referendumId: referendumId))
        
    }
    
    
    
     func toggleFavoriteOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<Bool> {
        
    return cuckoo_manager.call("toggleFavoriteOperation(_: String, projectId: String) -> NetworkOperation<Bool>",
            parameters: (urlTemplate, projectId),
            escapingParameters: (urlTemplate, projectId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.toggleFavoriteOperation(urlTemplate, projectId: projectId))
        
    }
    
    
    
     func voteOperation(_ urlTemplate: String, vote: ProjectVote) -> NetworkOperation<Bool> {
        
    return cuckoo_manager.call("voteOperation(_: String, vote: ProjectVote) -> NetworkOperation<Bool>",
            parameters: (urlTemplate, vote),
            escapingParameters: (urlTemplate, vote),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.voteOperation(urlTemplate, vote: vote))
        
    }
    
    
    
     func voteInReferendumOperation(_ urlTemplate: String, vote: ReferendumVote) -> NetworkOperation<Void> {
        
    return cuckoo_manager.call("voteInReferendumOperation(_: String, vote: ReferendumVote) -> NetworkOperation<Void>",
            parameters: (urlTemplate, vote),
            escapingParameters: (urlTemplate, vote),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.voteInReferendumOperation(urlTemplate, vote: vote))
        
    }
    
    
    
     func fetchVotesOperation(_ urlTemplate: String) -> NetworkOperation<VotesData?> {
        
    return cuckoo_manager.call("fetchVotesOperation(_: String) -> NetworkOperation<VotesData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchVotesOperation(urlTemplate))
        
    }
    
    
    
     func fetchVotesHistory(_ urlTemplate: String, with info: OffsetPagination) -> NetworkOperation<[VotesHistoryEventData]?> {
        
    return cuckoo_manager.call("fetchVotesHistory(_: String, with: OffsetPagination) -> NetworkOperation<[VotesHistoryEventData]?>",
            parameters: (urlTemplate, info),
            escapingParameters: (urlTemplate, info),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchVotesHistory(urlTemplate, with: info))
        
    }
    

	 struct __StubbingProxy_ProjectFundingOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func fetchProjectsOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, pagination: M2) -> Cuckoo.ProtocolStubFunction<(String, OffsetPagination), NetworkOperation<[ProjectData]>> where M1.MatchedType == String, M2.MatchedType == OffsetPagination {
	        let matchers: [Cuckoo.ParameterMatcher<(String, OffsetPagination)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: pagination) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "fetchProjectsOperation(_: String, pagination: OffsetPagination) -> NetworkOperation<[ProjectData]>", parameterMatchers: matchers))
	    }
	    
	    func fetchReferendumsOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<[ReferendumData]>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "fetchReferendumsOperation(_: String) -> NetworkOperation<[ReferendumData]>", parameterMatchers: matchers))
	    }
	    
	    func fetchProjectDetailsOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, projectId: M2) -> Cuckoo.ProtocolStubFunction<(String, String), NetworkOperation<ProjectDetailsData?>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: projectId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "fetchProjectDetailsOperation(_: String, projectId: String) -> NetworkOperation<ProjectDetailsData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchReferendumDetailsOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, referendumId: M2) -> Cuckoo.ProtocolStubFunction<(String, String), NetworkOperation<ReferendumData?>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: referendumId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "fetchReferendumDetailsOperation(_: String, referendumId: String) -> NetworkOperation<ReferendumData?>", parameterMatchers: matchers))
	    }
	    
	    func toggleFavoriteOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, projectId: M2) -> Cuckoo.ProtocolStubFunction<(String, String), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: projectId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "toggleFavoriteOperation(_: String, projectId: String) -> NetworkOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	    func voteOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, vote: M2) -> Cuckoo.ProtocolStubFunction<(String, ProjectVote), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == ProjectVote {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ProjectVote)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: vote) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "voteOperation(_: String, vote: ProjectVote) -> NetworkOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	    func voteInReferendumOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, vote: M2) -> Cuckoo.ProtocolStubFunction<(String, ReferendumVote), NetworkOperation<Void>> where M1.MatchedType == String, M2.MatchedType == ReferendumVote {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ReferendumVote)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: vote) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "voteInReferendumOperation(_: String, vote: ReferendumVote) -> NetworkOperation<Void>", parameterMatchers: matchers))
	    }
	    
	    func fetchVotesOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<VotesData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "fetchVotesOperation(_: String) -> NetworkOperation<VotesData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchVotesHistory<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with info: M2) -> Cuckoo.ProtocolStubFunction<(String, OffsetPagination), NetworkOperation<[VotesHistoryEventData]?>> where M1.MatchedType == String, M2.MatchedType == OffsetPagination {
	        let matchers: [Cuckoo.ParameterMatcher<(String, OffsetPagination)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectFundingOperationFactoryProtocol.self, method: "fetchVotesHistory(_: String, with: OffsetPagination) -> NetworkOperation<[VotesHistoryEventData]?>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProjectFundingOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func fetchProjectsOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, pagination: M2) -> Cuckoo.__DoNotUse<(String, OffsetPagination), NetworkOperation<[ProjectData]>> where M1.MatchedType == String, M2.MatchedType == OffsetPagination {
	        let matchers: [Cuckoo.ParameterMatcher<(String, OffsetPagination)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: pagination) { $0.1 }]
	        return cuckoo_manager.verify("fetchProjectsOperation(_: String, pagination: OffsetPagination) -> NetworkOperation<[ProjectData]>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchReferendumsOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<[ReferendumData]>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchReferendumsOperation(_: String) -> NetworkOperation<[ReferendumData]>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchProjectDetailsOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, projectId: M2) -> Cuckoo.__DoNotUse<(String, String), NetworkOperation<ProjectDetailsData?>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: projectId) { $0.1 }]
	        return cuckoo_manager.verify("fetchProjectDetailsOperation(_: String, projectId: String) -> NetworkOperation<ProjectDetailsData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchReferendumDetailsOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, referendumId: M2) -> Cuckoo.__DoNotUse<(String, String), NetworkOperation<ReferendumData?>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: referendumId) { $0.1 }]
	        return cuckoo_manager.verify("fetchReferendumDetailsOperation(_: String, referendumId: String) -> NetworkOperation<ReferendumData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func toggleFavoriteOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, projectId: M2) -> Cuckoo.__DoNotUse<(String, String), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: projectId) { $0.1 }]
	        return cuckoo_manager.verify("toggleFavoriteOperation(_: String, projectId: String) -> NetworkOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func voteOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, vote: M2) -> Cuckoo.__DoNotUse<(String, ProjectVote), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == ProjectVote {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ProjectVote)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: vote) { $0.1 }]
	        return cuckoo_manager.verify("voteOperation(_: String, vote: ProjectVote) -> NetworkOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func voteInReferendumOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, vote: M2) -> Cuckoo.__DoNotUse<(String, ReferendumVote), NetworkOperation<Void>> where M1.MatchedType == String, M2.MatchedType == ReferendumVote {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ReferendumVote)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: vote) { $0.1 }]
	        return cuckoo_manager.verify("voteInReferendumOperation(_: String, vote: ReferendumVote) -> NetworkOperation<Void>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchVotesOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<VotesData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchVotesOperation(_: String) -> NetworkOperation<VotesData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchVotesHistory<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with info: M2) -> Cuckoo.__DoNotUse<(String, OffsetPagination), NetworkOperation<[VotesHistoryEventData]?>> where M1.MatchedType == String, M2.MatchedType == OffsetPagination {
	        let matchers: [Cuckoo.ParameterMatcher<(String, OffsetPagination)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return cuckoo_manager.verify("fetchVotesHistory(_: String, with: OffsetPagination) -> NetworkOperation<[VotesHistoryEventData]?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProjectFundingOperationFactoryProtocolStub: ProjectFundingOperationFactoryProtocol {
    

    

    
     func fetchProjectsOperation(_ urlTemplate: String, pagination: OffsetPagination) -> NetworkOperation<[ProjectData]>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<[ProjectData]>).self)
    }
    
     func fetchReferendumsOperation(_ urlTemplate: String) -> NetworkOperation<[ReferendumData]>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<[ReferendumData]>).self)
    }
    
     func fetchProjectDetailsOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<ProjectDetailsData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<ProjectDetailsData?>).self)
    }
    
     func fetchReferendumDetailsOperation(_ urlTemplate: String, referendumId: String) -> NetworkOperation<ReferendumData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<ReferendumData?>).self)
    }
    
     func toggleFavoriteOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Bool>).self)
    }
    
     func voteOperation(_ urlTemplate: String, vote: ProjectVote) -> NetworkOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Bool>).self)
    }
    
     func voteInReferendumOperation(_ urlTemplate: String, vote: ReferendumVote) -> NetworkOperation<Void>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Void>).self)
    }
    
     func fetchVotesOperation(_ urlTemplate: String) -> NetworkOperation<VotesData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<VotesData?>).self)
    }
    
     func fetchVotesHistory(_ urlTemplate: String, with info: OffsetPagination) -> NetworkOperation<[VotesHistoryEventData]?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<[VotesHistoryEventData]?>).self)
    }
    
}



 class MockProjectAccountOperationFactoryProtocol: ProjectAccountOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProjectAccountOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_ProjectAccountOperationFactoryProtocol
     typealias Verification = __VerificationProxy_ProjectAccountOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProjectAccountOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: ProjectAccountOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func registrationOperation(_ urlTemplate: String, with info: RegistrationInfo) -> NetworkOperation<Bool> {
        
    return cuckoo_manager.call("registrationOperation(_: String, with: RegistrationInfo) -> NetworkOperation<Bool>",
            parameters: (urlTemplate, info),
            escapingParameters: (urlTemplate, info),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.registrationOperation(urlTemplate, with: info))
        
    }
    
    
    
     func createUserOperation(_ urlTemplate: String, with info: UserCreationInfo) -> NetworkOperation<VerificationCodeData> {
        
    return cuckoo_manager.call("createUserOperation(_: String, with: UserCreationInfo) -> NetworkOperation<VerificationCodeData>",
            parameters: (urlTemplate, info),
            escapingParameters: (urlTemplate, info),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createUserOperation(urlTemplate, with: info))
        
    }
    
    
    
     func fetchCustomerOperation(_ urlTemplate: String) -> NetworkOperation<UserData?> {
        
    return cuckoo_manager.call("fetchCustomerOperation(_: String) -> NetworkOperation<UserData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCustomerOperation(urlTemplate))
        
    }
    
    
    
     func updateCustomerOperation(_ urlTemplate: String, info: PersonalInfo) -> NetworkOperation<Bool> {
        
    return cuckoo_manager.call("updateCustomerOperation(_: String, info: PersonalInfo) -> NetworkOperation<Bool>",
            parameters: (urlTemplate, info),
            escapingParameters: (urlTemplate, info),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateCustomerOperation(urlTemplate, info: info))
        
    }
    
    
    
     func applyInvitationCodeOperation(_ urlTemplate: String, code: String) -> NetworkOperation<Void> {
        
    return cuckoo_manager.call("applyInvitationCodeOperation(_: String, code: String) -> NetworkOperation<Void>",
            parameters: (urlTemplate, code),
            escapingParameters: (urlTemplate, code),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.applyInvitationCodeOperation(urlTemplate, code: code))
        
    }
    
    
    
     func checkInvitation(_ urlTemplate: String, deviceInfo: DeviceInfo) -> NetworkOperation<InvitationCheckData> {
        
    return cuckoo_manager.call("checkInvitation(_: String, deviceInfo: DeviceInfo) -> NetworkOperation<InvitationCheckData>",
            parameters: (urlTemplate, deviceInfo),
            escapingParameters: (urlTemplate, deviceInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkInvitation(urlTemplate, deviceInfo: deviceInfo))
        
    }
    
    
    
     func fetchActivatedInvitationsOperation(_ urlTemplate: String) -> NetworkOperation<ActivatedInvitationsData?> {
        
    return cuckoo_manager.call("fetchActivatedInvitationsOperation(_: String) -> NetworkOperation<ActivatedInvitationsData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchActivatedInvitationsOperation(urlTemplate))
        
    }
    
    
    
     func fetchReputationOperation(_ urlTemplate: String) -> NetworkOperation<ReputationData?> {
        
    return cuckoo_manager.call("fetchReputationOperation(_: String) -> NetworkOperation<ReputationData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchReputationOperation(urlTemplate))
        
    }
    
    
    
     func fetchActivityFeedOperation(_ urlTemplate: String, with page: OffsetPagination) -> NetworkOperation<ActivityData?> {
        
    return cuckoo_manager.call("fetchActivityFeedOperation(_: String, with: OffsetPagination) -> NetworkOperation<ActivityData?>",
            parameters: (urlTemplate, page),
            escapingParameters: (urlTemplate, page),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchActivityFeedOperation(urlTemplate, with: page))
        
    }
    
    
    
     func sendSmsCodeOperation(_ urlTemplate: String) -> NetworkOperation<VerificationCodeData> {
        
    return cuckoo_manager.call("sendSmsCodeOperation(_: String) -> NetworkOperation<VerificationCodeData>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.sendSmsCodeOperation(urlTemplate))
        
    }
    
    
    
     func verifySmsCodeOperation(_ urlTemplate: String, info: VerificationCodeInfo) -> NetworkOperation<Bool> {
        
    return cuckoo_manager.call("verifySmsCodeOperation(_: String, info: VerificationCodeInfo) -> NetworkOperation<Bool>",
            parameters: (urlTemplate, info),
            escapingParameters: (urlTemplate, info),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.verifySmsCodeOperation(urlTemplate, info: info))
        
    }
    

	 struct __StubbingProxy_ProjectAccountOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func registrationOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with info: M2) -> Cuckoo.ProtocolStubFunction<(String, RegistrationInfo), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == RegistrationInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, RegistrationInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "registrationOperation(_: String, with: RegistrationInfo) -> NetworkOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	    func createUserOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with info: M2) -> Cuckoo.ProtocolStubFunction<(String, UserCreationInfo), NetworkOperation<VerificationCodeData>> where M1.MatchedType == String, M2.MatchedType == UserCreationInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, UserCreationInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "createUserOperation(_: String, with: UserCreationInfo) -> NetworkOperation<VerificationCodeData>", parameterMatchers: matchers))
	    }
	    
	    func fetchCustomerOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<UserData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "fetchCustomerOperation(_: String) -> NetworkOperation<UserData?>", parameterMatchers: matchers))
	    }
	    
	    func updateCustomerOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, info: M2) -> Cuckoo.ProtocolStubFunction<(String, PersonalInfo), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == PersonalInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, PersonalInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "updateCustomerOperation(_: String, info: PersonalInfo) -> NetworkOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	    func applyInvitationCodeOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, code: M2) -> Cuckoo.ProtocolStubFunction<(String, String), NetworkOperation<Void>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: code) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "applyInvitationCodeOperation(_: String, code: String) -> NetworkOperation<Void>", parameterMatchers: matchers))
	    }
	    
	    func checkInvitation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, deviceInfo: M2) -> Cuckoo.ProtocolStubFunction<(String, DeviceInfo), NetworkOperation<InvitationCheckData>> where M1.MatchedType == String, M2.MatchedType == DeviceInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DeviceInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: deviceInfo) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "checkInvitation(_: String, deviceInfo: DeviceInfo) -> NetworkOperation<InvitationCheckData>", parameterMatchers: matchers))
	    }
	    
	    func fetchActivatedInvitationsOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<ActivatedInvitationsData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "fetchActivatedInvitationsOperation(_: String) -> NetworkOperation<ActivatedInvitationsData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchReputationOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<ReputationData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "fetchReputationOperation(_: String) -> NetworkOperation<ReputationData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchActivityFeedOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with page: M2) -> Cuckoo.ProtocolStubFunction<(String, OffsetPagination), NetworkOperation<ActivityData?>> where M1.MatchedType == String, M2.MatchedType == OffsetPagination {
	        let matchers: [Cuckoo.ParameterMatcher<(String, OffsetPagination)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: page) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "fetchActivityFeedOperation(_: String, with: OffsetPagination) -> NetworkOperation<ActivityData?>", parameterMatchers: matchers))
	    }
	    
	    func sendSmsCodeOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<VerificationCodeData>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "sendSmsCodeOperation(_: String) -> NetworkOperation<VerificationCodeData>", parameterMatchers: matchers))
	    }
	    
	    func verifySmsCodeOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, info: M2) -> Cuckoo.ProtocolStubFunction<(String, VerificationCodeInfo), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == VerificationCodeInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, VerificationCodeInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectAccountOperationFactoryProtocol.self, method: "verifySmsCodeOperation(_: String, info: VerificationCodeInfo) -> NetworkOperation<Bool>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProjectAccountOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func registrationOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with info: M2) -> Cuckoo.__DoNotUse<(String, RegistrationInfo), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == RegistrationInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, RegistrationInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return cuckoo_manager.verify("registrationOperation(_: String, with: RegistrationInfo) -> NetworkOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createUserOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with info: M2) -> Cuckoo.__DoNotUse<(String, UserCreationInfo), NetworkOperation<VerificationCodeData>> where M1.MatchedType == String, M2.MatchedType == UserCreationInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, UserCreationInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return cuckoo_manager.verify("createUserOperation(_: String, with: UserCreationInfo) -> NetworkOperation<VerificationCodeData>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchCustomerOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<UserData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchCustomerOperation(_: String) -> NetworkOperation<UserData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateCustomerOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, info: M2) -> Cuckoo.__DoNotUse<(String, PersonalInfo), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == PersonalInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, PersonalInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return cuckoo_manager.verify("updateCustomerOperation(_: String, info: PersonalInfo) -> NetworkOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func applyInvitationCodeOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, code: M2) -> Cuckoo.__DoNotUse<(String, String), NetworkOperation<Void>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: code) { $0.1 }]
	        return cuckoo_manager.verify("applyInvitationCodeOperation(_: String, code: String) -> NetworkOperation<Void>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkInvitation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, deviceInfo: M2) -> Cuckoo.__DoNotUse<(String, DeviceInfo), NetworkOperation<InvitationCheckData>> where M1.MatchedType == String, M2.MatchedType == DeviceInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DeviceInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: deviceInfo) { $0.1 }]
	        return cuckoo_manager.verify("checkInvitation(_: String, deviceInfo: DeviceInfo) -> NetworkOperation<InvitationCheckData>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchActivatedInvitationsOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<ActivatedInvitationsData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchActivatedInvitationsOperation(_: String) -> NetworkOperation<ActivatedInvitationsData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchReputationOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<ReputationData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchReputationOperation(_: String) -> NetworkOperation<ReputationData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchActivityFeedOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, with page: M2) -> Cuckoo.__DoNotUse<(String, OffsetPagination), NetworkOperation<ActivityData?>> where M1.MatchedType == String, M2.MatchedType == OffsetPagination {
	        let matchers: [Cuckoo.ParameterMatcher<(String, OffsetPagination)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: page) { $0.1 }]
	        return cuckoo_manager.verify("fetchActivityFeedOperation(_: String, with: OffsetPagination) -> NetworkOperation<ActivityData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func sendSmsCodeOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<VerificationCodeData>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("sendSmsCodeOperation(_: String) -> NetworkOperation<VerificationCodeData>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func verifySmsCodeOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, info: M2) -> Cuckoo.__DoNotUse<(String, VerificationCodeInfo), NetworkOperation<Bool>> where M1.MatchedType == String, M2.MatchedType == VerificationCodeInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, VerificationCodeInfo)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: info) { $0.1 }]
	        return cuckoo_manager.verify("verifySmsCodeOperation(_: String, info: VerificationCodeInfo) -> NetworkOperation<Bool>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProjectAccountOperationFactoryProtocolStub: ProjectAccountOperationFactoryProtocol {
    

    

    
     func registrationOperation(_ urlTemplate: String, with info: RegistrationInfo) -> NetworkOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Bool>).self)
    }
    
     func createUserOperation(_ urlTemplate: String, with info: UserCreationInfo) -> NetworkOperation<VerificationCodeData>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<VerificationCodeData>).self)
    }
    
     func fetchCustomerOperation(_ urlTemplate: String) -> NetworkOperation<UserData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<UserData?>).self)
    }
    
     func updateCustomerOperation(_ urlTemplate: String, info: PersonalInfo) -> NetworkOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Bool>).self)
    }
    
     func applyInvitationCodeOperation(_ urlTemplate: String, code: String) -> NetworkOperation<Void>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Void>).self)
    }
    
     func checkInvitation(_ urlTemplate: String, deviceInfo: DeviceInfo) -> NetworkOperation<InvitationCheckData>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<InvitationCheckData>).self)
    }
    
     func fetchActivatedInvitationsOperation(_ urlTemplate: String) -> NetworkOperation<ActivatedInvitationsData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<ActivatedInvitationsData?>).self)
    }
    
     func fetchReputationOperation(_ urlTemplate: String) -> NetworkOperation<ReputationData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<ReputationData?>).self)
    }
    
     func fetchActivityFeedOperation(_ urlTemplate: String, with page: OffsetPagination) -> NetworkOperation<ActivityData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<ActivityData?>).self)
    }
    
     func sendSmsCodeOperation(_ urlTemplate: String) -> NetworkOperation<VerificationCodeData>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<VerificationCodeData>).self)
    }
    
     func verifySmsCodeOperation(_ urlTemplate: String, info: VerificationCodeInfo) -> NetworkOperation<Bool>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<Bool>).self)
    }
    
}



 class MockProjectInformationOperationFactoryProtocol: ProjectInformationOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProjectInformationOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_ProjectInformationOperationFactoryProtocol
     typealias Verification = __VerificationProxy_ProjectInformationOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProjectInformationOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: ProjectInformationOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func fetchAnnouncementOperation(_ urlTemplate: String) -> NetworkOperation<AnnouncementData?> {
        
    return cuckoo_manager.call("fetchAnnouncementOperation(_: String) -> NetworkOperation<AnnouncementData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchAnnouncementOperation(urlTemplate))
        
    }
    
    
    
     func fetchHelpOperation(_ urlTemplate: String) -> NetworkOperation<HelpData?> {
        
    return cuckoo_manager.call("fetchHelpOperation(_: String) -> NetworkOperation<HelpData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchHelpOperation(urlTemplate))
        
    }
    
    
    
     func fetchReputationDetailsOperation(_ urlTemplate: String) -> NetworkOperation<ReputationDetailsData?> {
        
    return cuckoo_manager.call("fetchReputationDetailsOperation(_: String) -> NetworkOperation<ReputationDetailsData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchReputationDetailsOperation(urlTemplate))
        
    }
    
    
    
     func fetchCurrencyOperation(_ urlTemplate: String) -> NetworkOperation<CurrencyData?> {
        
    return cuckoo_manager.call("fetchCurrencyOperation(_: String) -> NetworkOperation<CurrencyData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCurrencyOperation(urlTemplate))
        
    }
    
    
    
     func checkSupportedVersionOperation(_ urlTemplate: String, version: String) -> NetworkOperation<SupportedVersionData> {
        
    return cuckoo_manager.call("checkSupportedVersionOperation(_: String, version: String) -> NetworkOperation<SupportedVersionData>",
            parameters: (urlTemplate, version),
            escapingParameters: (urlTemplate, version),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkSupportedVersionOperation(urlTemplate, version: version))
        
    }
    
    
    
     func fetchCountryOperation(_ urlTemplate: String) -> NetworkOperation<CountryData?> {
        
    return cuckoo_manager.call("fetchCountryOperation(_: String) -> NetworkOperation<CountryData?>",
            parameters: (urlTemplate),
            escapingParameters: (urlTemplate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCountryOperation(urlTemplate))
        
    }
    

	 struct __StubbingProxy_ProjectInformationOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func fetchAnnouncementOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<AnnouncementData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectInformationOperationFactoryProtocol.self, method: "fetchAnnouncementOperation(_: String) -> NetworkOperation<AnnouncementData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchHelpOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<HelpData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectInformationOperationFactoryProtocol.self, method: "fetchHelpOperation(_: String) -> NetworkOperation<HelpData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchReputationDetailsOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<ReputationDetailsData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectInformationOperationFactoryProtocol.self, method: "fetchReputationDetailsOperation(_: String) -> NetworkOperation<ReputationDetailsData?>", parameterMatchers: matchers))
	    }
	    
	    func fetchCurrencyOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<CurrencyData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectInformationOperationFactoryProtocol.self, method: "fetchCurrencyOperation(_: String) -> NetworkOperation<CurrencyData?>", parameterMatchers: matchers))
	    }
	    
	    func checkSupportedVersionOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, version: M2) -> Cuckoo.ProtocolStubFunction<(String, String), NetworkOperation<SupportedVersionData>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: version) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectInformationOperationFactoryProtocol.self, method: "checkSupportedVersionOperation(_: String, version: String) -> NetworkOperation<SupportedVersionData>", parameterMatchers: matchers))
	    }
	    
	    func fetchCountryOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.ProtocolStubFunction<(String), NetworkOperation<CountryData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProjectInformationOperationFactoryProtocol.self, method: "fetchCountryOperation(_: String) -> NetworkOperation<CountryData?>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProjectInformationOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func fetchAnnouncementOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<AnnouncementData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchAnnouncementOperation(_: String) -> NetworkOperation<AnnouncementData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchHelpOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<HelpData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchHelpOperation(_: String) -> NetworkOperation<HelpData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchReputationDetailsOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<ReputationDetailsData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchReputationDetailsOperation(_: String) -> NetworkOperation<ReputationDetailsData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchCurrencyOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<CurrencyData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchCurrencyOperation(_: String) -> NetworkOperation<CurrencyData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkSupportedVersionOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ urlTemplate: M1, version: M2) -> Cuckoo.__DoNotUse<(String, String), NetworkOperation<SupportedVersionData>> where M1.MatchedType == String, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String, String)>] = [wrap(matchable: urlTemplate) { $0.0 }, wrap(matchable: version) { $0.1 }]
	        return cuckoo_manager.verify("checkSupportedVersionOperation(_: String, version: String) -> NetworkOperation<SupportedVersionData>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchCountryOperation<M1: Cuckoo.Matchable>(_ urlTemplate: M1) -> Cuckoo.__DoNotUse<(String), NetworkOperation<CountryData?>> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: urlTemplate) { $0 }]
	        return cuckoo_manager.verify("fetchCountryOperation(_: String) -> NetworkOperation<CountryData?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProjectInformationOperationFactoryProtocolStub: ProjectInformationOperationFactoryProtocol {
    

    

    
     func fetchAnnouncementOperation(_ urlTemplate: String) -> NetworkOperation<AnnouncementData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<AnnouncementData?>).self)
    }
    
     func fetchHelpOperation(_ urlTemplate: String) -> NetworkOperation<HelpData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<HelpData?>).self)
    }
    
     func fetchReputationDetailsOperation(_ urlTemplate: String) -> NetworkOperation<ReputationDetailsData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<ReputationDetailsData?>).self)
    }
    
     func fetchCurrencyOperation(_ urlTemplate: String) -> NetworkOperation<CurrencyData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<CurrencyData?>).self)
    }
    
     func checkSupportedVersionOperation(_ urlTemplate: String, version: String) -> NetworkOperation<SupportedVersionData>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<SupportedVersionData>).self)
    }
    
     func fetchCountryOperation(_ urlTemplate: String) -> NetworkOperation<CountryData?>  {
        return DefaultValueRegistry.defaultValue(for: (NetworkOperation<CountryData?>).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation
import Reachability


 class MockReachabilityListenerDelegate: ReachabilityListenerDelegate, Cuckoo.ProtocolMock {
    
     typealias MocksType = ReachabilityListenerDelegate
    
     typealias Stubbing = __StubbingProxy_ReachabilityListenerDelegate
     typealias Verification = __VerificationProxy_ReachabilityListenerDelegate

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ReachabilityListenerDelegate?

     func enableDefaultImplementation(_ stub: ReachabilityListenerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didChangeReachability(by manager: ReachabilityManagerProtocol)  {
        
    return cuckoo_manager.call("didChangeReachability(by: ReachabilityManagerProtocol)",
            parameters: (manager),
            escapingParameters: (manager),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didChangeReachability(by: manager))
        
    }
    

	 struct __StubbingProxy_ReachabilityListenerDelegate: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didChangeReachability<M1: Cuckoo.Matchable>(by manager: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ReachabilityManagerProtocol)> where M1.MatchedType == ReachabilityManagerProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ReachabilityManagerProtocol)>] = [wrap(matchable: manager) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockReachabilityListenerDelegate.self, method: "didChangeReachability(by: ReachabilityManagerProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ReachabilityListenerDelegate: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didChangeReachability<M1: Cuckoo.Matchable>(by manager: M1) -> Cuckoo.__DoNotUse<(ReachabilityManagerProtocol), Void> where M1.MatchedType == ReachabilityManagerProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ReachabilityManagerProtocol)>] = [wrap(matchable: manager) { $0 }]
	        return cuckoo_manager.verify("didChangeReachability(by: ReachabilityManagerProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ReachabilityListenerDelegateStub: ReachabilityListenerDelegate {
    

    

    
     func didChangeReachability(by manager: ReachabilityManagerProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockReachabilityManagerProtocol: ReachabilityManagerProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ReachabilityManagerProtocol
    
     typealias Stubbing = __StubbingProxy_ReachabilityManagerProtocol
     typealias Verification = __VerificationProxy_ReachabilityManagerProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ReachabilityManagerProtocol?

     func enableDefaultImplementation(_ stub: ReachabilityManagerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isReachable: Bool {
        get {
            return cuckoo_manager.getter("isReachable",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isReachable)
        }
        
    }
    

    

    
    
    
     func add(listener: ReachabilityListenerDelegate) throws {
        
    return try cuckoo_manager.callThrows("add(listener: ReachabilityListenerDelegate) throws",
            parameters: (listener),
            escapingParameters: (listener),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(listener: listener))
        
    }
    
    
    
     func remove(listener: ReachabilityListenerDelegate)  {
        
    return cuckoo_manager.call("remove(listener: ReachabilityListenerDelegate)",
            parameters: (listener),
            escapingParameters: (listener),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(listener: listener))
        
    }
    

	 struct __StubbingProxy_ReachabilityManagerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isReachable: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockReachabilityManagerProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isReachable")
	    }
	    
	    
	    func add<M1: Cuckoo.Matchable>(listener: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(ReachabilityListenerDelegate)> where M1.MatchedType == ReachabilityListenerDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ReachabilityListenerDelegate)>] = [wrap(matchable: listener) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockReachabilityManagerProtocol.self, method: "add(listener: ReachabilityListenerDelegate) throws", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(listener: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ReachabilityListenerDelegate)> where M1.MatchedType == ReachabilityListenerDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ReachabilityListenerDelegate)>] = [wrap(matchable: listener) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockReachabilityManagerProtocol.self, method: "remove(listener: ReachabilityListenerDelegate)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ReachabilityManagerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isReachable: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isReachable", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func add<M1: Cuckoo.Matchable>(listener: M1) -> Cuckoo.__DoNotUse<(ReachabilityListenerDelegate), Void> where M1.MatchedType == ReachabilityListenerDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ReachabilityListenerDelegate)>] = [wrap(matchable: listener) { $0 }]
	        return cuckoo_manager.verify("add(listener: ReachabilityListenerDelegate) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(listener: M1) -> Cuckoo.__DoNotUse<(ReachabilityListenerDelegate), Void> where M1.MatchedType == ReachabilityListenerDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ReachabilityListenerDelegate)>] = [wrap(matchable: listener) { $0 }]
	        return cuckoo_manager.verify("remove(listener: ReachabilityListenerDelegate)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ReachabilityManagerProtocolStub: ReachabilityManagerProtocol {
    
    
     var isReachable: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func add(listener: ReachabilityListenerDelegate) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func remove(listener: ReachabilityListenerDelegate)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport
@testable import SoraFoundation

import Foundation


 class MockUserApplicationServiceProtocol: UserApplicationServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UserApplicationServiceProtocol
    
     typealias Stubbing = __StubbingProxy_UserApplicationServiceProtocol
     typealias Verification = __VerificationProxy_UserApplicationServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UserApplicationServiceProtocol?

     func enableDefaultImplementation(_ stub: UserApplicationServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func throttle()  {
        
    return cuckoo_manager.call("throttle()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.throttle())
        
    }
    

	 struct __StubbingProxy_UserApplicationServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUserApplicationServiceProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func throttle() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUserApplicationServiceProtocol.self, method: "throttle()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UserApplicationServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func throttle() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("throttle()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UserApplicationServiceProtocolStub: UserApplicationServiceProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func throttle()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUserApplicationServiceFactoryProtocol: UserApplicationServiceFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UserApplicationServiceFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_UserApplicationServiceFactoryProtocol
     typealias Verification = __VerificationProxy_UserApplicationServiceFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UserApplicationServiceFactoryProtocol?

     func enableDefaultImplementation(_ stub: UserApplicationServiceFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createServices() -> [UserApplicationServiceProtocol] {
        
    return cuckoo_manager.call("createServices() -> [UserApplicationServiceProtocol]",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createServices())
        
    }
    

	 struct __StubbingProxy_UserApplicationServiceFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createServices() -> Cuckoo.ProtocolStubFunction<(), [UserApplicationServiceProtocol]> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUserApplicationServiceFactoryProtocol.self, method: "createServices() -> [UserApplicationServiceProtocol]", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UserApplicationServiceFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createServices() -> Cuckoo.__DoNotUse<(), [UserApplicationServiceProtocol]> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("createServices() -> [UserApplicationServiceProtocol]", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UserApplicationServiceFactoryProtocolStub: UserApplicationServiceFactoryProtocol {
    

    

    
     func createServices() -> [UserApplicationServiceProtocol]  {
        return DefaultValueRegistry.defaultValue(for: ([UserApplicationServiceProtocol]).self)
    }
    
}

