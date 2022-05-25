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
    

    

    
    
    
    public func start(with interval: TimeInterval, runLoop: RunLoop, mode: RunLoop.Mode)  {
        
    return cuckoo_manager.call("start(with: TimeInterval, runLoop: RunLoop, mode: RunLoop.Mode)",
            parameters: (interval, runLoop, mode),
            escapingParameters: (interval, runLoop, mode),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.start(with: interval, runLoop: runLoop, mode: mode))
        
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
	    
	    
	    func start<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(with interval: M1, runLoop: M2, mode: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval, RunLoop, RunLoop.Mode)> where M1.MatchedType == TimeInterval, M2.MatchedType == RunLoop, M3.MatchedType == RunLoop.Mode {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval, RunLoop, RunLoop.Mode)>] = [wrap(matchable: interval) { $0.0 }, wrap(matchable: runLoop) { $0.1 }, wrap(matchable: mode) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCountdownTimerProtocol.self, method: "start(with: TimeInterval, runLoop: RunLoop, mode: RunLoop.Mode)", parameterMatchers: matchers))
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
	    func start<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(with interval: M1, runLoop: M2, mode: M3) -> Cuckoo.__DoNotUse<(TimeInterval, RunLoop, RunLoop.Mode), Void> where M1.MatchedType == TimeInterval, M2.MatchedType == RunLoop, M3.MatchedType == RunLoop.Mode {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval, RunLoop, RunLoop.Mode)>] = [wrap(matchable: interval) { $0.0 }, wrap(matchable: runLoop) { $0.1 }, wrap(matchable: mode) { $0.2 }]
	        return cuckoo_manager.verify("start(with: TimeInterval, runLoop: RunLoop, mode: RunLoop.Mode)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
    

    

    
    public func start(with interval: TimeInterval, runLoop: RunLoop, mode: RunLoop.Mode)   {
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
    
    
    
     var telegramURL: URL {
        get {
            return cuckoo_manager.getter("telegramURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.telegramURL)
        }
        
    }
    
    
    
     var siteURL: URL {
        get {
            return cuckoo_manager.getter("siteURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.siteURL)
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
    
    
    
     var pendingFailureDelay: TimeInterval {
        get {
            return cuckoo_manager.getter("pendingFailureDelay",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.pendingFailureDelay)
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
    
    
    
     var polkaswapURL: URL {
        get {
            return cuckoo_manager.getter("polkaswapURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.polkaswapURL)
        }
        
    }
    
    
    
     var rewardsURL: URL {
        get {
            return cuckoo_manager.getter("rewardsURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.rewardsURL)
        }
        
    }
    
    
    
     var parliamentURL: URL {
        get {
            return cuckoo_manager.getter("parliamentURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.parliamentURL)
        }
        
    }
    
    
    
     var phishingListURL: URL {
        get {
            return cuckoo_manager.getter("phishingListURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.phishingListURL)
        }
        
    }
    
    
    
     var shareURL: URL {
        get {
            return cuckoo_manager.getter("shareURL",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shareURL)
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
	    
	    
	    var defaultCurrency: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, CurrencyItemData> {
	        return .init(manager: cuckoo_manager, name: "defaultCurrency")
	    }
	    
	    
	    var soranetExplorerTemplate: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, String> {
	        return .init(manager: cuckoo_manager, name: "soranetExplorerTemplate")
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
	    
	    
	    var telegramURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "telegramURL")
	    }
	    
	    
	    var siteURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "siteURL")
	    }
	    
	    
	    var faqURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "faqURL")
	    }
	    
	    
	    var pendingFailureDelay: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "pendingFailureDelay")
	    }
	    
	    
	    var combinedTransfersHandlingDelay: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "combinedTransfersHandlingDelay")
	    }
	    
	    
	    var polkaswapURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "polkaswapURL")
	    }
	    
	    
	    var rewardsURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "rewardsURL")
	    }
	    
	    
	    var parliamentURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "parliamentURL")
	    }
	    
	    
	    var phishingListURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "phishingListURL")
	    }
	    
	    
	    var shareURL: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockApplicationConfigProtocol, URL> {
	        return .init(manager: cuckoo_manager, name: "shareURL")
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
	    
	    
	    var defaultCurrency: Cuckoo.VerifyReadOnlyProperty<CurrencyItemData> {
	        return .init(manager: cuckoo_manager, name: "defaultCurrency", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var soranetExplorerTemplate: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "soranetExplorerTemplate", callMatcher: callMatcher, sourceLocation: sourceLocation)
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
	    
	    
	    var telegramURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "telegramURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var siteURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "siteURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var faqURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "faqURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var pendingFailureDelay: Cuckoo.VerifyReadOnlyProperty<TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "pendingFailureDelay", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var combinedTransfersHandlingDelay: Cuckoo.VerifyReadOnlyProperty<TimeInterval> {
	        return .init(manager: cuckoo_manager, name: "combinedTransfersHandlingDelay", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var polkaswapURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "polkaswapURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var rewardsURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "rewardsURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var parliamentURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "parliamentURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var phishingListURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "phishingListURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shareURL: Cuckoo.VerifyReadOnlyProperty<URL> {
	        return .init(manager: cuckoo_manager, name: "shareURL", callMatcher: callMatcher, sourceLocation: sourceLocation)
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
    
    
     var telegramURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var siteURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var faqURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var pendingFailureDelay: TimeInterval {
        get {
            return DefaultValueRegistry.defaultValue(for: (TimeInterval).self)
        }
        
    }
    
    
     var combinedTransfersHandlingDelay: TimeInterval {
        get {
            return DefaultValueRegistry.defaultValue(for: (TimeInterval).self)
        }
        
    }
    
    
     var polkaswapURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var rewardsURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var parliamentURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var phishingListURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
    }
    
    
     var shareURL: URL {
        get {
            return DefaultValueRegistry.defaultValue(for: (URL).self)
        }
        
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

