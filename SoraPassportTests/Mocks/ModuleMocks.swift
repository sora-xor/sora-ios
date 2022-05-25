import Cuckoo
@testable import SoraPassport

import UIKit


public class MockEmptyStateDelegate: EmptyStateDelegate, Cuckoo.ProtocolMock {
    
    public typealias MocksType = EmptyStateDelegate
    
    public typealias Stubbing = __StubbingProxy_EmptyStateDelegate
    public typealias Verification = __VerificationProxy_EmptyStateDelegate

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EmptyStateDelegate?

    public func enableDefaultImplementation(_ stub: EmptyStateDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var shouldDisplayEmptyState: Bool {
        get {
            return cuckoo_manager.getter("shouldDisplayEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisplayEmptyState)
        }
        
    }
    

    

    

	public struct __StubbingProxy_EmptyStateDelegate: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var shouldDisplayEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDelegate, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisplayEmptyState")
	    }
	    
	    
	}

	public struct __VerificationProxy_EmptyStateDelegate: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var shouldDisplayEmptyState: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisplayEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

public class EmptyStateDelegateStub: EmptyStateDelegate {
    
    
    public var shouldDisplayEmptyState: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
}



public class MockEmptyStateDataSource: EmptyStateDataSource, Cuckoo.ProtocolMock {
    
    public typealias MocksType = EmptyStateDataSource
    
    public typealias Stubbing = __StubbingProxy_EmptyStateDataSource
    public typealias Verification = __VerificationProxy_EmptyStateDataSource

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EmptyStateDataSource?

    public func enableDefaultImplementation(_ stub: EmptyStateDataSource) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var viewForEmptyState: UIView? {
        get {
            return cuckoo_manager.getter("viewForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.viewForEmptyState)
        }
        
    }
    
    
    
    public var imageForEmptyState: UIImage? {
        get {
            return cuckoo_manager.getter("imageForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.imageForEmptyState)
        }
        
    }
    
    
    
    public var titleForEmptyState: String? {
        get {
            return cuckoo_manager.getter("titleForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.titleForEmptyState)
        }
        
    }
    
    
    
    public var titleColorForEmptyState: UIColor? {
        get {
            return cuckoo_manager.getter("titleColorForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.titleColorForEmptyState)
        }
        
    }
    
    
    
    public var titleFontForEmptyState: UIFont? {
        get {
            return cuckoo_manager.getter("titleFontForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.titleFontForEmptyState)
        }
        
    }
    
    
    
    public var verticalSpacingForEmptyState: CGFloat? {
        get {
            return cuckoo_manager.getter("verticalSpacingForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.verticalSpacingForEmptyState)
        }
        
    }
    
    
    
    public var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        get {
            return cuckoo_manager.getter("trimStrategyForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.trimStrategyForEmptyState)
        }
        
    }
    

    

    

	public struct __StubbingProxy_EmptyStateDataSource: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var viewForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, UIView?> {
	        return .init(manager: cuckoo_manager, name: "viewForEmptyState")
	    }
	    
	    
	    var imageForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, UIImage?> {
	        return .init(manager: cuckoo_manager, name: "imageForEmptyState")
	    }
	    
	    
	    var titleForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, String?> {
	        return .init(manager: cuckoo_manager, name: "titleForEmptyState")
	    }
	    
	    
	    var titleColorForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, UIColor?> {
	        return .init(manager: cuckoo_manager, name: "titleColorForEmptyState")
	    }
	    
	    
	    var titleFontForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, UIFont?> {
	        return .init(manager: cuckoo_manager, name: "titleFontForEmptyState")
	    }
	    
	    
	    var verticalSpacingForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, CGFloat?> {
	        return .init(manager: cuckoo_manager, name: "verticalSpacingForEmptyState")
	    }
	    
	    
	    var trimStrategyForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateDataSource, EmptyStateView.TrimStrategy> {
	        return .init(manager: cuckoo_manager, name: "trimStrategyForEmptyState")
	    }
	    
	    
	}

	public struct __VerificationProxy_EmptyStateDataSource: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var viewForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "viewForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var imageForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIImage?> {
	        return .init(manager: cuckoo_manager, name: "imageForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var titleForEmptyState: Cuckoo.VerifyReadOnlyProperty<String?> {
	        return .init(manager: cuckoo_manager, name: "titleForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var titleColorForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIColor?> {
	        return .init(manager: cuckoo_manager, name: "titleColorForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var titleFontForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIFont?> {
	        return .init(manager: cuckoo_manager, name: "titleFontForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var verticalSpacingForEmptyState: Cuckoo.VerifyReadOnlyProperty<CGFloat?> {
	        return .init(manager: cuckoo_manager, name: "verticalSpacingForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var trimStrategyForEmptyState: Cuckoo.VerifyReadOnlyProperty<EmptyStateView.TrimStrategy> {
	        return .init(manager: cuckoo_manager, name: "trimStrategyForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

public class EmptyStateDataSourceStub: EmptyStateDataSource {
    
    
    public var viewForEmptyState: UIView? {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
    public var imageForEmptyState: UIImage? {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIImage?).self)
        }
        
    }
    
    
    public var titleForEmptyState: String? {
        get {
            return DefaultValueRegistry.defaultValue(for: (String?).self)
        }
        
    }
    
    
    public var titleColorForEmptyState: UIColor? {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIColor?).self)
        }
        
    }
    
    
    public var titleFontForEmptyState: UIFont? {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIFont?).self)
        }
        
    }
    
    
    public var verticalSpacingForEmptyState: CGFloat? {
        get {
            return DefaultValueRegistry.defaultValue(for: (CGFloat?).self)
        }
        
    }
    
    
    public var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        get {
            return DefaultValueRegistry.defaultValue(for: (EmptyStateView.TrimStrategy).self)
        }
        
    }
    

    

    
}



public class MockEmptyStateViewOwnerProtocol: EmptyStateViewOwnerProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = EmptyStateViewOwnerProtocol
    
    public typealias Stubbing = __StubbingProxy_EmptyStateViewOwnerProtocol
    public typealias Verification = __VerificationProxy_EmptyStateViewOwnerProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EmptyStateViewOwnerProtocol?

    public func enableDefaultImplementation(_ stub: EmptyStateViewOwnerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var emptyStateDelegate: EmptyStateDelegate {
        get {
            return cuckoo_manager.getter("emptyStateDelegate",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.emptyStateDelegate)
        }
        
    }
    
    
    
    public var emptyStateDataSource: EmptyStateDataSource {
        get {
            return cuckoo_manager.getter("emptyStateDataSource",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.emptyStateDataSource)
        }
        
    }
    
    
    
    public var contentViewForEmptyState: UIView {
        get {
            return cuckoo_manager.getter("contentViewForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.contentViewForEmptyState)
        }
        
    }
    
    
    
    public var displayInsetsForEmptyState: UIEdgeInsets {
        get {
            return cuckoo_manager.getter("displayInsetsForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.displayInsetsForEmptyState)
        }
        
    }
    
    
    
    public var appearanceAnimatorForEmptyState: ViewAnimatorProtocol? {
        get {
            return cuckoo_manager.getter("appearanceAnimatorForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.appearanceAnimatorForEmptyState)
        }
        
    }
    
    
    
    public var dismissAnimatorForEmptyState: ViewAnimatorProtocol? {
        get {
            return cuckoo_manager.getter("dismissAnimatorForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.dismissAnimatorForEmptyState)
        }
        
    }
    

    

    
    
    
    public func reloadEmptyState(animated: Bool)  {
        
    return cuckoo_manager.call("reloadEmptyState(animated: Bool)",
            parameters: (animated),
            escapingParameters: (animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reloadEmptyState(animated: animated))
        
    }
    
    
    
    public func updateEmptyState(animated: Bool)  {
        
    return cuckoo_manager.call("updateEmptyState(animated: Bool)",
            parameters: (animated),
            escapingParameters: (animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateEmptyState(animated: animated))
        
    }
    
    
    
    public func updateEmptyStateInsets()  {
        
    return cuckoo_manager.call("updateEmptyStateInsets()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateEmptyStateInsets())
        
    }
    

	public struct __StubbingProxy_EmptyStateViewOwnerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var emptyStateDelegate: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateViewOwnerProtocol, EmptyStateDelegate> {
	        return .init(manager: cuckoo_manager, name: "emptyStateDelegate")
	    }
	    
	    
	    var emptyStateDataSource: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateViewOwnerProtocol, EmptyStateDataSource> {
	        return .init(manager: cuckoo_manager, name: "emptyStateDataSource")
	    }
	    
	    
	    var contentViewForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateViewOwnerProtocol, UIView> {
	        return .init(manager: cuckoo_manager, name: "contentViewForEmptyState")
	    }
	    
	    
	    var displayInsetsForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateViewOwnerProtocol, UIEdgeInsets> {
	        return .init(manager: cuckoo_manager, name: "displayInsetsForEmptyState")
	    }
	    
	    
	    var appearanceAnimatorForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateViewOwnerProtocol, ViewAnimatorProtocol?> {
	        return .init(manager: cuckoo_manager, name: "appearanceAnimatorForEmptyState")
	    }
	    
	    
	    var dismissAnimatorForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateViewOwnerProtocol, ViewAnimatorProtocol?> {
	        return .init(manager: cuckoo_manager, name: "dismissAnimatorForEmptyState")
	    }
	    
	    
	    func reloadEmptyState<M1: Cuckoo.Matchable>(animated: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool)> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: animated) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEmptyStateViewOwnerProtocol.self, method: "reloadEmptyState(animated: Bool)", parameterMatchers: matchers))
	    }
	    
	    func updateEmptyState<M1: Cuckoo.Matchable>(animated: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool)> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: animated) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEmptyStateViewOwnerProtocol.self, method: "updateEmptyState(animated: Bool)", parameterMatchers: matchers))
	    }
	    
	    func updateEmptyStateInsets() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockEmptyStateViewOwnerProtocol.self, method: "updateEmptyStateInsets()", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_EmptyStateViewOwnerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var emptyStateDelegate: Cuckoo.VerifyReadOnlyProperty<EmptyStateDelegate> {
	        return .init(manager: cuckoo_manager, name: "emptyStateDelegate", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var emptyStateDataSource: Cuckoo.VerifyReadOnlyProperty<EmptyStateDataSource> {
	        return .init(manager: cuckoo_manager, name: "emptyStateDataSource", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var contentViewForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIView> {
	        return .init(manager: cuckoo_manager, name: "contentViewForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var displayInsetsForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIEdgeInsets> {
	        return .init(manager: cuckoo_manager, name: "displayInsetsForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var appearanceAnimatorForEmptyState: Cuckoo.VerifyReadOnlyProperty<ViewAnimatorProtocol?> {
	        return .init(manager: cuckoo_manager, name: "appearanceAnimatorForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var dismissAnimatorForEmptyState: Cuckoo.VerifyReadOnlyProperty<ViewAnimatorProtocol?> {
	        return .init(manager: cuckoo_manager, name: "dismissAnimatorForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func reloadEmptyState<M1: Cuckoo.Matchable>(animated: M1) -> Cuckoo.__DoNotUse<(Bool), Void> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: animated) { $0 }]
	        return cuckoo_manager.verify("reloadEmptyState(animated: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateEmptyState<M1: Cuckoo.Matchable>(animated: M1) -> Cuckoo.__DoNotUse<(Bool), Void> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: animated) { $0 }]
	        return cuckoo_manager.verify("updateEmptyState(animated: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateEmptyStateInsets() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("updateEmptyStateInsets()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class EmptyStateViewOwnerProtocolStub: EmptyStateViewOwnerProtocol {
    
    
    public var emptyStateDelegate: EmptyStateDelegate {
        get {
            return DefaultValueRegistry.defaultValue(for: (EmptyStateDelegate).self)
        }
        
    }
    
    
    public var emptyStateDataSource: EmptyStateDataSource {
        get {
            return DefaultValueRegistry.defaultValue(for: (EmptyStateDataSource).self)
        }
        
    }
    
    
    public var contentViewForEmptyState: UIView {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView).self)
        }
        
    }
    
    
    public var displayInsetsForEmptyState: UIEdgeInsets {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIEdgeInsets).self)
        }
        
    }
    
    
    public var appearanceAnimatorForEmptyState: ViewAnimatorProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (ViewAnimatorProtocol?).self)
        }
        
    }
    
    
    public var dismissAnimatorForEmptyState: ViewAnimatorProtocol? {
        get {
            return DefaultValueRegistry.defaultValue(for: (ViewAnimatorProtocol?).self)
        }
        
    }
    

    

    
    public func reloadEmptyState(animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func updateEmptyState(animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    public func updateEmptyStateInsets()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockEmptyStateListViewModelProtocol: EmptyStateListViewModelProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = EmptyStateListViewModelProtocol
    
    public typealias Stubbing = __StubbingProxy_EmptyStateListViewModelProtocol
    public typealias Verification = __VerificationProxy_EmptyStateListViewModelProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EmptyStateListViewModelProtocol?

    public func enableDefaultImplementation(_ stub: EmptyStateListViewModelProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var emptyStateView: UIView {
        get {
            return cuckoo_manager.getter("emptyStateView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.emptyStateView)
        }
        
    }
    
    
    
    public var displayInsetsForEmptyState: UIEdgeInsets {
        get {
            return cuckoo_manager.getter("displayInsetsForEmptyState",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.displayInsetsForEmptyState)
        }
        
    }
    

    

    

	public struct __StubbingProxy_EmptyStateListViewModelProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var emptyStateView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateListViewModelProtocol, UIView> {
	        return .init(manager: cuckoo_manager, name: "emptyStateView")
	    }
	    
	    
	    var displayInsetsForEmptyState: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockEmptyStateListViewModelProtocol, UIEdgeInsets> {
	        return .init(manager: cuckoo_manager, name: "displayInsetsForEmptyState")
	    }
	    
	    
	}

	public struct __VerificationProxy_EmptyStateListViewModelProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var emptyStateView: Cuckoo.VerifyReadOnlyProperty<UIView> {
	        return .init(manager: cuckoo_manager, name: "emptyStateView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var displayInsetsForEmptyState: Cuckoo.VerifyReadOnlyProperty<UIEdgeInsets> {
	        return .init(manager: cuckoo_manager, name: "displayInsetsForEmptyState", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

public class EmptyStateListViewModelProtocolStub: EmptyStateListViewModelProtocol {
    
    
    public var emptyStateView: UIView {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView).self)
        }
        
    }
    
    
    public var displayInsetsForEmptyState: UIEdgeInsets {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIEdgeInsets).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockDeepLinkNavigatorProtocol: DeepLinkNavigatorProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DeepLinkNavigatorProtocol
    
     typealias Stubbing = __StubbingProxy_DeepLinkNavigatorProtocol
     typealias Verification = __VerificationProxy_DeepLinkNavigatorProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DeepLinkNavigatorProtocol?

     func enableDefaultImplementation(_ stub: DeepLinkNavigatorProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func navigate(to invitation: InvitationDeepLink) -> Bool {
        
    return cuckoo_manager.call("navigate(to: InvitationDeepLink) -> Bool",
            parameters: (invitation),
            escapingParameters: (invitation),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.navigate(to: invitation))
        
    }
    

	 struct __StubbingProxy_DeepLinkNavigatorProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func navigate<M1: Cuckoo.Matchable>(to invitation: M1) -> Cuckoo.ProtocolStubFunction<(InvitationDeepLink), Bool> where M1.MatchedType == InvitationDeepLink {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationDeepLink)>] = [wrap(matchable: invitation) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDeepLinkNavigatorProtocol.self, method: "navigate(to: InvitationDeepLink) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DeepLinkNavigatorProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func navigate<M1: Cuckoo.Matchable>(to invitation: M1) -> Cuckoo.__DoNotUse<(InvitationDeepLink), Bool> where M1.MatchedType == InvitationDeepLink {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationDeepLink)>] = [wrap(matchable: invitation) { $0 }]
	        return cuckoo_manager.verify("navigate(to: InvitationDeepLink) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DeepLinkNavigatorProtocolStub: DeepLinkNavigatorProtocol {
    

    

    
     func navigate(to invitation: InvitationDeepLink) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}



 class MockDeepLinkProtocol: DeepLinkProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DeepLinkProtocol
    
     typealias Stubbing = __StubbingProxy_DeepLinkProtocol
     typealias Verification = __VerificationProxy_DeepLinkProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DeepLinkProtocol?

     func enableDefaultImplementation(_ stub: DeepLinkProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func accept(navigator: DeepLinkNavigatorProtocol) -> Bool {
        
    return cuckoo_manager.call("accept(navigator: DeepLinkNavigatorProtocol) -> Bool",
            parameters: (navigator),
            escapingParameters: (navigator),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.accept(navigator: navigator))
        
    }
    

	 struct __StubbingProxy_DeepLinkProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func accept<M1: Cuckoo.Matchable>(navigator: M1) -> Cuckoo.ProtocolStubFunction<(DeepLinkNavigatorProtocol), Bool> where M1.MatchedType == DeepLinkNavigatorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(DeepLinkNavigatorProtocol)>] = [wrap(matchable: navigator) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDeepLinkProtocol.self, method: "accept(navigator: DeepLinkNavigatorProtocol) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DeepLinkProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func accept<M1: Cuckoo.Matchable>(navigator: M1) -> Cuckoo.__DoNotUse<(DeepLinkNavigatorProtocol), Bool> where M1.MatchedType == DeepLinkNavigatorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(DeepLinkNavigatorProtocol)>] = [wrap(matchable: navigator) { $0 }]
	        return cuckoo_manager.verify("accept(navigator: DeepLinkNavigatorProtocol) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DeepLinkProtocolStub: DeepLinkProtocol {
    

    

    
     func accept(navigator: DeepLinkNavigatorProtocol) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockDeepLinkServiceProtocol: DeepLinkServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DeepLinkServiceProtocol
    
     typealias Stubbing = __StubbingProxy_DeepLinkServiceProtocol
     typealias Verification = __VerificationProxy_DeepLinkServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DeepLinkServiceProtocol?

     func enableDefaultImplementation(_ stub: DeepLinkServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func handle(url: URL) -> Bool {
        
    return cuckoo_manager.call("handle(url: URL) -> Bool",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(url: url))
        
    }
    

	 struct __StubbingProxy_DeepLinkServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func handle<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubFunction<(URL), Bool> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDeepLinkServiceProtocol.self, method: "handle(url: URL) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DeepLinkServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Bool> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("handle(url: URL) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DeepLinkServiceProtocolStub: DeepLinkServiceProtocol {
    

    

    
     func handle(url: URL) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation
import SoraKeystore


 class MockInvitationLinkObserver: InvitationLinkObserver, Cuckoo.ProtocolMock {
    
     typealias MocksType = InvitationLinkObserver
    
     typealias Stubbing = __StubbingProxy_InvitationLinkObserver
     typealias Verification = __VerificationProxy_InvitationLinkObserver

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InvitationLinkObserver?

     func enableDefaultImplementation(_ stub: InvitationLinkObserver) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didUpdateInvitationLink(from oldLink: InvitationDeepLink?)  {
        
    return cuckoo_manager.call("didUpdateInvitationLink(from: InvitationDeepLink?)",
            parameters: (oldLink),
            escapingParameters: (oldLink),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didUpdateInvitationLink(from: oldLink))
        
    }
    

	 struct __StubbingProxy_InvitationLinkObserver: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didUpdateInvitationLink<M1: Cuckoo.OptionalMatchable>(from oldLink: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationDeepLink?)> where M1.OptionalMatchedType == InvitationDeepLink {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationDeepLink?)>] = [wrap(matchable: oldLink) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkObserver.self, method: "didUpdateInvitationLink(from: InvitationDeepLink?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InvitationLinkObserver: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didUpdateInvitationLink<M1: Cuckoo.OptionalMatchable>(from oldLink: M1) -> Cuckoo.__DoNotUse<(InvitationDeepLink?), Void> where M1.OptionalMatchedType == InvitationDeepLink {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationDeepLink?)>] = [wrap(matchable: oldLink) { $0 }]
	        return cuckoo_manager.verify("didUpdateInvitationLink(from: InvitationDeepLink?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InvitationLinkObserverStub: InvitationLinkObserver {
    

    

    
     func didUpdateInvitationLink(from oldLink: InvitationDeepLink?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockInvitationLinkServiceProtocol: InvitationLinkServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = InvitationLinkServiceProtocol
    
     typealias Stubbing = __StubbingProxy_InvitationLinkServiceProtocol
     typealias Verification = __VerificationProxy_InvitationLinkServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InvitationLinkServiceProtocol?

     func enableDefaultImplementation(_ stub: InvitationLinkServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var link: InvitationDeepLink? {
        get {
            return cuckoo_manager.getter("link",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.link)
        }
        
    }
    

    

    
    
    
     func add(observer: InvitationLinkObserver)  {
        
    return cuckoo_manager.call("add(observer: InvitationLinkObserver)",
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer))
        
    }
    
    
    
     func remove(observer: InvitationLinkObserver)  {
        
    return cuckoo_manager.call("remove(observer: InvitationLinkObserver)",
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(observer: observer))
        
    }
    
    
    
     func save(code: String)  {
        
    return cuckoo_manager.call("save(code: String)",
            parameters: (code),
            escapingParameters: (code),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.save(code: code))
        
    }
    
    
    
     func clear()  {
        
    return cuckoo_manager.call("clear()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.clear())
        
    }
    
    
    
     func handle(url: URL) -> Bool {
        
    return cuckoo_manager.call("handle(url: URL) -> Bool",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(url: url))
        
    }
    

	 struct __StubbingProxy_InvitationLinkServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var link: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockInvitationLinkServiceProtocol, InvitationDeepLink?> {
	        return .init(manager: cuckoo_manager, name: "link")
	    }
	    
	    
	    func add<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationLinkObserver)> where M1.MatchedType == InvitationLinkObserver {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationLinkObserver)>] = [wrap(matchable: observer) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method: "add(observer: InvitationLinkObserver)", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationLinkObserver)> where M1.MatchedType == InvitationLinkObserver {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationLinkObserver)>] = [wrap(matchable: observer) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method: "remove(observer: InvitationLinkObserver)", parameterMatchers: matchers))
	    }
	    
	    func save<M1: Cuckoo.Matchable>(code: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: code) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method: "save(code: String)", parameterMatchers: matchers))
	    }
	    
	    func clear() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method: "clear()", parameterMatchers: matchers))
	    }
	    
	    func handle<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubFunction<(URL), Bool> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method: "handle(url: URL) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InvitationLinkServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var link: Cuckoo.VerifyReadOnlyProperty<InvitationDeepLink?> {
	        return .init(manager: cuckoo_manager, name: "link", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func add<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(InvitationLinkObserver), Void> where M1.MatchedType == InvitationLinkObserver {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationLinkObserver)>] = [wrap(matchable: observer) { $0 }]
	        return cuckoo_manager.verify("add(observer: InvitationLinkObserver)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(InvitationLinkObserver), Void> where M1.MatchedType == InvitationLinkObserver {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationLinkObserver)>] = [wrap(matchable: observer) { $0 }]
	        return cuckoo_manager.verify("remove(observer: InvitationLinkObserver)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func save<M1: Cuckoo.Matchable>(code: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: code) { $0 }]
	        return cuckoo_manager.verify("save(code: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func clear() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("clear()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Bool> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("handle(url: URL) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InvitationLinkServiceProtocolStub: InvitationLinkServiceProtocol {
    
    
     var link: InvitationDeepLink? {
        get {
            return DefaultValueRegistry.defaultValue(for: (InvitationDeepLink?).self)
        }
        
    }
    

    

    
     func add(observer: InvitationLinkObserver)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func remove(observer: InvitationLinkObserver)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func save(code: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func clear()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func handle(url: URL) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockEventProtocol: EventProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventProtocol
    
     typealias Stubbing = __StubbingProxy_EventProtocol
     typealias Verification = __VerificationProxy_EventProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventProtocol?

     func enableDefaultImplementation(_ stub: EventProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func accept(visitor: EventVisitorProtocol)  {
        
    return cuckoo_manager.call("accept(visitor: EventVisitorProtocol)",
            parameters: (visitor),
            escapingParameters: (visitor),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.accept(visitor: visitor))
        
    }
    

	 struct __StubbingProxy_EventProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func accept<M1: Cuckoo.Matchable>(visitor: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: visitor) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventProtocol.self, method: "accept(visitor: EventVisitorProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_EventProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func accept<M1: Cuckoo.Matchable>(visitor: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: visitor) { $0 }]
	        return cuckoo_manager.verify("accept(visitor: EventVisitorProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class EventProtocolStub: EventProtocol {
    

    

    
     func accept(visitor: EventVisitorProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockEventCenterProtocol: EventCenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventCenterProtocol
    
     typealias Stubbing = __StubbingProxy_EventCenterProtocol
     typealias Verification = __VerificationProxy_EventCenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventCenterProtocol?

     func enableDefaultImplementation(_ stub: EventCenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func notify(with event: EventProtocol)  {
        
    return cuckoo_manager.call("notify(with: EventProtocol)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notify(with: event))
        
    }
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)  {
        
    return cuckoo_manager.call("add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)",
            parameters: (observer, queue),
            escapingParameters: (observer, queue),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer, dispatchIn: queue))
        
    }
    
    
    
     func remove(observer: EventVisitorProtocol)  {
        
    return cuckoo_manager.call("remove(observer: EventVisitorProtocol)",
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(observer: observer))
        
    }
    

	 struct __StubbingProxy_EventCenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func notify<M1: Cuckoo.Matchable>(with event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventProtocol)> where M1.MatchedType == EventProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "notify(with: EventProtocol)", parameterMatchers: matchers))
	    }
	    
	    func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol, DispatchQueue?)> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "remove(observer: EventVisitorProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_EventCenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func notify<M1: Cuckoo.Matchable>(with event: M1) -> Cuckoo.__DoNotUse<(EventProtocol), Void> where M1.MatchedType == EventProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("notify(with: EventProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.__DoNotUse<(EventVisitorProtocol, DispatchQueue?), Void> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
	        return cuckoo_manager.verify("add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
	        return cuckoo_manager.verify("remove(observer: EventVisitorProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class EventCenterProtocolStub: EventCenterProtocol {
    

    

    
     func notify(with event: EventProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func remove(observer: EventVisitorProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockEventVisitorProtocol: EventVisitorProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventVisitorProtocol
    
     typealias Stubbing = __StubbingProxy_EventVisitorProtocol
     typealias Verification = __VerificationProxy_EventVisitorProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventVisitorProtocol?

     func enableDefaultImplementation(_ stub: EventVisitorProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func processProjectVote(event: ProjectVoteEvent)  {
        
    return cuckoo_manager.call("processProjectVote(event: ProjectVoteEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processProjectVote(event: event))
        
    }
    
    
    
     func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)  {
        
    return cuckoo_manager.call("processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processProjectFavoriteToggle(event: event))
        
    }
    
    
    
     func processProjectView(event: ProjectViewEvent)  {
        
    return cuckoo_manager.call("processProjectView(event: ProjectViewEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processProjectView(event: event))
        
    }
    
    
    
     func processInvitationInput(event: InvitationInputEvent)  {
        
    return cuckoo_manager.call("processInvitationInput(event: InvitationInputEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processInvitationInput(event: event))
        
    }
    
    
    
     func processInvitationApplied(event: InvitationAppliedEvent)  {
        
    return cuckoo_manager.call("processInvitationApplied(event: InvitationAppliedEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processInvitationApplied(event: event))
        
    }
    
    
    
     func processWalletUpdate(event: WalletUpdateEvent)  {
        
    return cuckoo_manager.call("processWalletUpdate(event: WalletUpdateEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processWalletUpdate(event: event))
        
    }
    
    
    
     func processReferendumVote(event: ReferendumVoteEvent)  {
        
    return cuckoo_manager.call("processReferendumVote(event: ReferendumVoteEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processReferendumVote(event: event))
        
    }
    
    
    
     func processSelectedAccountChanged(event: SelectedAccountChanged)  {
        
    return cuckoo_manager.call("processSelectedAccountChanged(event: SelectedAccountChanged)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSelectedAccountChanged(event: event))
        
    }
    
    
    
     func processSelectedUsernameChanged(event: SelectedUsernameChanged)  {
        
    return cuckoo_manager.call("processSelectedUsernameChanged(event: SelectedUsernameChanged)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSelectedUsernameChanged(event: event))
        
    }
    
    
    
     func processSelectedConnectionChanged(event: SelectedConnectionChanged)  {
        
    return cuckoo_manager.call("processSelectedConnectionChanged(event: SelectedConnectionChanged)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSelectedConnectionChanged(event: event))
        
    }
    
    
    
     func processBalanceChanged(event: WalletBalanceChanged)  {
        
    return cuckoo_manager.call("processBalanceChanged(event: WalletBalanceChanged)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processBalanceChanged(event: event))
        
    }
    
    
    
     func processStakingChanged(event: WalletStakingInfoChanged)  {
        
    return cuckoo_manager.call("processStakingChanged(event: WalletStakingInfoChanged)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processStakingChanged(event: event))
        
    }
    
    
    
     func processNewTransaction(event: WalletNewTransactionInserted)  {
        
    return cuckoo_manager.call("processNewTransaction(event: WalletNewTransactionInserted)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processNewTransaction(event: event))
        
    }
    
    
    
     func processTypeRegistryPrepared(event: TypeRegistryPrepared)  {
        
    return cuckoo_manager.call("processTypeRegistryPrepared(event: TypeRegistryPrepared)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processTypeRegistryPrepared(event: event))
        
    }
    
    
    
     func processMigration(event: MigrationEvent)  {
        
    return cuckoo_manager.call("processMigration(event: MigrationEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processMigration(event: event))
        
    }
    
    
    
     func processSuccsessMigration(event: MigrationSuccsessEvent)  {
        
    return cuckoo_manager.call("processSuccsessMigration(event: MigrationSuccsessEvent)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSuccsessMigration(event: event))
        
    }
    

	 struct __StubbingProxy_EventVisitorProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func processProjectVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProjectVoteEvent)> where M1.MatchedType == ProjectVoteEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ProjectVoteEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processProjectVote(event: ProjectVoteEvent)", parameterMatchers: matchers))
	    }
	    
	    func processProjectFavoriteToggle<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProjectFavoriteToggleEvent)> where M1.MatchedType == ProjectFavoriteToggleEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ProjectFavoriteToggleEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)", parameterMatchers: matchers))
	    }
	    
	    func processProjectView<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProjectViewEvent)> where M1.MatchedType == ProjectViewEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ProjectViewEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processProjectView(event: ProjectViewEvent)", parameterMatchers: matchers))
	    }
	    
	    func processInvitationInput<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationInputEvent)> where M1.MatchedType == InvitationInputEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationInputEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processInvitationInput(event: InvitationInputEvent)", parameterMatchers: matchers))
	    }
	    
	    func processInvitationApplied<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationAppliedEvent)> where M1.MatchedType == InvitationAppliedEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationAppliedEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processInvitationApplied(event: InvitationAppliedEvent)", parameterMatchers: matchers))
	    }
	    
	    func processWalletUpdate<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletUpdateEvent)> where M1.MatchedType == WalletUpdateEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletUpdateEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processWalletUpdate(event: WalletUpdateEvent)", parameterMatchers: matchers))
	    }
	    
	    func processReferendumVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ReferendumVoteEvent)> where M1.MatchedType == ReferendumVoteEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ReferendumVoteEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processReferendumVote(event: ReferendumVoteEvent)", parameterMatchers: matchers))
	    }
	    
	    func processSelectedAccountChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedAccountChanged)> where M1.MatchedType == SelectedAccountChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedAccountChanged)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processSelectedAccountChanged(event: SelectedAccountChanged)", parameterMatchers: matchers))
	    }
	    
	    func processSelectedUsernameChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedUsernameChanged)> where M1.MatchedType == SelectedUsernameChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedUsernameChanged)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processSelectedUsernameChanged(event: SelectedUsernameChanged)", parameterMatchers: matchers))
	    }
	    
	    func processSelectedConnectionChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedConnectionChanged)> where M1.MatchedType == SelectedConnectionChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedConnectionChanged)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processSelectedConnectionChanged(event: SelectedConnectionChanged)", parameterMatchers: matchers))
	    }
	    
	    func processBalanceChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletBalanceChanged)> where M1.MatchedType == WalletBalanceChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletBalanceChanged)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processBalanceChanged(event: WalletBalanceChanged)", parameterMatchers: matchers))
	    }
	    
	    func processStakingChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletStakingInfoChanged)> where M1.MatchedType == WalletStakingInfoChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletStakingInfoChanged)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processStakingChanged(event: WalletStakingInfoChanged)", parameterMatchers: matchers))
	    }
	    
	    func processNewTransaction<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletNewTransactionInserted)> where M1.MatchedType == WalletNewTransactionInserted {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletNewTransactionInserted)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processNewTransaction(event: WalletNewTransactionInserted)", parameterMatchers: matchers))
	    }
	    
	    func processTypeRegistryPrepared<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TypeRegistryPrepared)> where M1.MatchedType == TypeRegistryPrepared {
	        let matchers: [Cuckoo.ParameterMatcher<(TypeRegistryPrepared)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processTypeRegistryPrepared(event: TypeRegistryPrepared)", parameterMatchers: matchers))
	    }
	    
	    func processMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MigrationEvent)> where M1.MatchedType == MigrationEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(MigrationEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processMigration(event: MigrationEvent)", parameterMatchers: matchers))
	    }
	    
	    func processSuccsessMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MigrationSuccsessEvent)> where M1.MatchedType == MigrationSuccsessEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(MigrationSuccsessEvent)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method: "processSuccsessMigration(event: MigrationSuccsessEvent)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_EventVisitorProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func processProjectVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ProjectVoteEvent), Void> where M1.MatchedType == ProjectVoteEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ProjectVoteEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processProjectVote(event: ProjectVoteEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processProjectFavoriteToggle<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ProjectFavoriteToggleEvent), Void> where M1.MatchedType == ProjectFavoriteToggleEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ProjectFavoriteToggleEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processProjectView<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ProjectViewEvent), Void> where M1.MatchedType == ProjectViewEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ProjectViewEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processProjectView(event: ProjectViewEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processInvitationInput<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(InvitationInputEvent), Void> where M1.MatchedType == InvitationInputEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationInputEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processInvitationInput(event: InvitationInputEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processInvitationApplied<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(InvitationAppliedEvent), Void> where M1.MatchedType == InvitationAppliedEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationAppliedEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processInvitationApplied(event: InvitationAppliedEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processWalletUpdate<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletUpdateEvent), Void> where M1.MatchedType == WalletUpdateEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletUpdateEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processWalletUpdate(event: WalletUpdateEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processReferendumVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ReferendumVoteEvent), Void> where M1.MatchedType == ReferendumVoteEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(ReferendumVoteEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processReferendumVote(event: ReferendumVoteEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processSelectedAccountChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(SelectedAccountChanged), Void> where M1.MatchedType == SelectedAccountChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedAccountChanged)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processSelectedAccountChanged(event: SelectedAccountChanged)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processSelectedUsernameChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(SelectedUsernameChanged), Void> where M1.MatchedType == SelectedUsernameChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedUsernameChanged)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processSelectedUsernameChanged(event: SelectedUsernameChanged)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processSelectedConnectionChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(SelectedConnectionChanged), Void> where M1.MatchedType == SelectedConnectionChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(SelectedConnectionChanged)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processSelectedConnectionChanged(event: SelectedConnectionChanged)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processBalanceChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletBalanceChanged), Void> where M1.MatchedType == WalletBalanceChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletBalanceChanged)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processBalanceChanged(event: WalletBalanceChanged)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processStakingChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletStakingInfoChanged), Void> where M1.MatchedType == WalletStakingInfoChanged {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletStakingInfoChanged)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processStakingChanged(event: WalletStakingInfoChanged)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processNewTransaction<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletNewTransactionInserted), Void> where M1.MatchedType == WalletNewTransactionInserted {
	        let matchers: [Cuckoo.ParameterMatcher<(WalletNewTransactionInserted)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processNewTransaction(event: WalletNewTransactionInserted)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processTypeRegistryPrepared<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(TypeRegistryPrepared), Void> where M1.MatchedType == TypeRegistryPrepared {
	        let matchers: [Cuckoo.ParameterMatcher<(TypeRegistryPrepared)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processTypeRegistryPrepared(event: TypeRegistryPrepared)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(MigrationEvent), Void> where M1.MatchedType == MigrationEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(MigrationEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processMigration(event: MigrationEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func processSuccsessMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(MigrationSuccsessEvent), Void> where M1.MatchedType == MigrationSuccsessEvent {
	        let matchers: [Cuckoo.ParameterMatcher<(MigrationSuccsessEvent)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("processSuccsessMigration(event: MigrationSuccsessEvent)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class EventVisitorProtocolStub: EventVisitorProtocol {
    

    

    
     func processProjectVote(event: ProjectVoteEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processProjectView(event: ProjectViewEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processInvitationInput(event: InvitationInputEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processInvitationApplied(event: InvitationAppliedEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processWalletUpdate(event: WalletUpdateEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processReferendumVote(event: ReferendumVoteEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processSelectedAccountChanged(event: SelectedAccountChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processSelectedUsernameChanged(event: SelectedUsernameChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processSelectedConnectionChanged(event: SelectedConnectionChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processBalanceChanged(event: WalletBalanceChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processStakingChanged(event: WalletStakingInfoChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processNewTransaction(event: WalletNewTransactionInserted)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processTypeRegistryPrepared(event: TypeRegistryPrepared)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processMigration(event: MigrationEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func processSuccsessMigration(event: MigrationSuccsessEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation
import LocalAuthentication


public class MockBiometryAuthProtocol: BiometryAuthProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = BiometryAuthProtocol
    
    public typealias Stubbing = __StubbingProxy_BiometryAuthProtocol
    public typealias Verification = __VerificationProxy_BiometryAuthProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: BiometryAuthProtocol?

    public func enableDefaultImplementation(_ stub: BiometryAuthProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    

    

    
    
    
    public func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    

	public struct __StubbingProxy_BiometryAuthProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var availableBiometryType: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockBiometryAuthProtocol, AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType")
	    }
	    
	    
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuthProtocol.self, method: "authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_BiometryAuthProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var availableBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class BiometryAuthProtocolStub: BiometryAuthProtocol {
    
    
    public var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    

    

    
    public func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockBiometryAuth: BiometryAuth, Cuckoo.ClassMock {
    
    public typealias MocksType = BiometryAuth
    
    public typealias Stubbing = __StubbingProxy_BiometryAuth
    public typealias Verification = __VerificationProxy_BiometryAuth

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: BiometryAuth?

    public func enableDefaultImplementation(_ stub: BiometryAuth) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public override var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    super.availableBiometryType
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    

    

    
    
    
    public override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                super.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock)
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    

	public struct __StubbingProxy_BiometryAuth: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var availableBiometryType: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockBiometryAuth, AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType")
	    }
	    
	    
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ClassStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuth.self, method: "authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_BiometryAuth: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var availableBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class BiometryAuthStub: BiometryAuth {
    
    
    public override var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    

    

    
    public override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockAlertPresentable: AlertPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = AlertPresentable
    
     typealias Stubbing = __StubbingProxy_AlertPresentable
     typealias Verification = __VerificationProxy_AlertPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AlertPresentable?

     func enableDefaultImplementation(_ stub: AlertPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AlertPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AlertPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AlertPresentableStub: AlertPresentable {
    

    

    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockControllerBackedProtocol: ControllerBackedProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ControllerBackedProtocol
    
     typealias Stubbing = __StubbingProxy_ControllerBackedProtocol
     typealias Verification = __VerificationProxy_ControllerBackedProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ControllerBackedProtocol?

     func enableDefaultImplementation(_ stub: ControllerBackedProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ControllerBackedProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockControllerBackedProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockControllerBackedProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	}

	 struct __VerificationProxy_ControllerBackedProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ControllerBackedProtocolStub: ControllerBackedProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockErrorPresentable: ErrorPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = ErrorPresentable
    
     typealias Stubbing = __StubbingProxy_ErrorPresentable
     typealias Verification = __VerificationProxy_ErrorPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ErrorPresentable?

     func enableDefaultImplementation(_ stub: ErrorPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    

	 struct __StubbingProxy_ErrorPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockErrorPresentable.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ErrorPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ErrorPresentableStub: ErrorPresentable {
    

    

    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockInputFieldPresentable: InputFieldPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = InputFieldPresentable
    
     typealias Stubbing = __StubbingProxy_InputFieldPresentable
     typealias Verification = __VerificationProxy_InputFieldPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InputFieldPresentable?

     func enableDefaultImplementation(_ stub: InputFieldPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func requestInput(for viewModel: InputFieldViewModelProtocol, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)",
            parameters: (viewModel, view),
            escapingParameters: (viewModel, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestInput(for: viewModel, from: view))
        
    }
    

	 struct __StubbingProxy_InputFieldPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func requestInput<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for viewModel: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(InputFieldViewModelProtocol, ControllerBackedProtocol?)> where M1.MatchedType == InputFieldViewModelProtocol, M2.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputFieldViewModelProtocol, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInputFieldPresentable.self, method: "requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InputFieldPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func requestInput<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for viewModel: M1, from view: M2) -> Cuckoo.__DoNotUse<(InputFieldViewModelProtocol, ControllerBackedProtocol?), Void> where M1.MatchedType == InputFieldViewModelProtocol, M2.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputFieldViewModelProtocol, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InputFieldPresentableStub: InputFieldPresentable {
    

    

    
     func requestInput(for viewModel: InputFieldViewModelProtocol, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import SoraUI
import UIKit


 class MockLoadableViewProtocol: LoadableViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LoadableViewProtocol
    
     typealias Stubbing = __StubbingProxy_LoadableViewProtocol
     typealias Verification = __VerificationProxy_LoadableViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LoadableViewProtocol?

     func enableDefaultImplementation(_ stub: LoadableViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_LoadableViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLoadableViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLoadableViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LoadableViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LoadableViewProtocolStub: LoadableViewProtocol {
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockSharingPresentable: SharingPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = SharingPresentable
    
     typealias Stubbing = __StubbingProxy_SharingPresentable
     typealias Verification = __VerificationProxy_SharingPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SharingPresentable?

     func enableDefaultImplementation(_ stub: SharingPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)",
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    

	 struct __StubbingProxy_SharingPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSharingPresentable.self, method: "share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SharingPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return cuckoo_manager.verify("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SharingPresentableStub: SharingPresentable {
    

    

    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import SoraUI
import UIKit


 class MockApplicationStatusPresentable: ApplicationStatusPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = ApplicationStatusPresentable
    
     typealias Stubbing = __StubbingProxy_ApplicationStatusPresentable
     typealias Verification = __VerificationProxy_ApplicationStatusPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ApplicationStatusPresentable?

     func enableDefaultImplementation(_ stub: ApplicationStatusPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)  {
        
    return cuckoo_manager.call("presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)",
            parameters: (title, style, animated),
            escapingParameters: (title, style, animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentStatus(title: title, style: style, animated: animated))
        
    }
    
    
    
     func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)  {
        
    return cuckoo_manager.call("dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)",
            parameters: (title, style, animated),
            escapingParameters: (title, style, animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.dismissStatus(title: title, style: style, animated: animated))
        
    }
    

	 struct __StubbingProxy_ApplicationStatusPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func presentStatus<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ApplicationStatusStyle, Bool)> where M1.MatchedType == String, M2.MatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ApplicationStatusStyle, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockApplicationStatusPresentable.self, method: "presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)", parameterMatchers: matchers))
	    }
	    
	    func dismissStatus<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, ApplicationStatusStyle?, Bool)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, ApplicationStatusStyle?, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockApplicationStatusPresentable.self, method: "dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ApplicationStatusPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func presentStatus<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.__DoNotUse<(String, ApplicationStatusStyle, Bool), Void> where M1.MatchedType == String, M2.MatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(String, ApplicationStatusStyle, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return cuckoo_manager.verify("presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func dismissStatus<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.__DoNotUse<(String?, ApplicationStatusStyle?, Bool), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, ApplicationStatusStyle?, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return cuckoo_manager.verify("dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ApplicationStatusPresentableStub: ApplicationStatusPresentable {
    

    

    
     func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import SoraUI
import UIKit


 class MockUnsupportedVersionPresentable: UnsupportedVersionPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = UnsupportedVersionPresentable
    
     typealias Stubbing = __StubbingProxy_UnsupportedVersionPresentable
     typealias Verification = __VerificationProxy_UnsupportedVersionPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UnsupportedVersionPresentable?

     func enableDefaultImplementation(_ stub: UnsupportedVersionPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func presentUnsupportedVersion(for data: SupportedVersionData, on window: UIWindow?, animated: Bool)  {
        
    return cuckoo_manager.call("presentUnsupportedVersion(for: SupportedVersionData, on: UIWindow?, animated: Bool)",
            parameters: (data, window, animated),
            escapingParameters: (data, window, animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentUnsupportedVersion(for: data, on: window, animated: animated))
        
    }
    

	 struct __StubbingProxy_UnsupportedVersionPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func presentUnsupportedVersion<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for data: M1, on window: M2, animated: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(SupportedVersionData, UIWindow?, Bool)> where M1.MatchedType == SupportedVersionData, M2.OptionalMatchedType == UIWindow, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(SupportedVersionData, UIWindow?, Bool)>] = [wrap(matchable: data) { $0.0 }, wrap(matchable: window) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUnsupportedVersionPresentable.self, method: "presentUnsupportedVersion(for: SupportedVersionData, on: UIWindow?, animated: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UnsupportedVersionPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func presentUnsupportedVersion<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for data: M1, on window: M2, animated: M3) -> Cuckoo.__DoNotUse<(SupportedVersionData, UIWindow?, Bool), Void> where M1.MatchedType == SupportedVersionData, M2.OptionalMatchedType == UIWindow, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(SupportedVersionData, UIWindow?, Bool)>] = [wrap(matchable: data) { $0.0 }, wrap(matchable: window) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return cuckoo_manager.verify("presentUnsupportedVersion(for: SupportedVersionData, on: UIWindow?, animated: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UnsupportedVersionPresentableStub: UnsupportedVersionPresentable {
    

    

    
     func presentUnsupportedVersion(for data: SupportedVersionData, on window: UIWindow?, animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation
import SafariServices
import UIKit


 class MockWebPresentable: WebPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = WebPresentable
    
     typealias Stubbing = __StubbingProxy_WebPresentable
     typealias Verification = __VerificationProxy_WebPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: WebPresentable?

     func enableDefaultImplementation(_ stub: WebPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    

	 struct __StubbingProxy_WebPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockWebPresentable.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_WebPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class WebPresentableStub: WebPresentable {
    

    

    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockSelectionListViewProtocol: SelectionListViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SelectionListViewProtocol
    
     typealias Stubbing = __StubbingProxy_SelectionListViewProtocol
     typealias Verification = __VerificationProxy_SelectionListViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SelectionListViewProtocol?

     func enableDefaultImplementation(_ stub: SelectionListViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReload()  {
        
    return cuckoo_manager.call("didReload()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReload())
        
    }
    

	 struct __StubbingProxy_SelectionListViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockSelectionListViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockSelectionListViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReload() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectionListViewProtocol.self, method: "didReload()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SelectionListViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReload() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReload()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SelectionListViewProtocolStub: SelectionListViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReload()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockSelectionListPresenterProtocol: SelectionListPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SelectionListPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_SelectionListPresenterProtocol
     typealias Verification = __VerificationProxy_SelectionListPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SelectionListPresenterProtocol?

     func enableDefaultImplementation(_ stub: SelectionListPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var numberOfItems: Int {
        get {
            return cuckoo_manager.getter("numberOfItems",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.numberOfItems)
        }
        
    }
    

    

    
    
    
     func item(at index: Int) -> SelectableViewModelProtocol {
        
    return cuckoo_manager.call("item(at: Int) -> SelectableViewModelProtocol",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.item(at: index))
        
    }
    
    
    
     func selectItem(at index: Int)  {
        
    return cuckoo_manager.call("selectItem(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectItem(at: index))
        
    }
    

	 struct __StubbingProxy_SelectionListPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var numberOfItems: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockSelectionListPresenterProtocol, Int> {
	        return .init(manager: cuckoo_manager, name: "numberOfItems")
	    }
	    
	    
	    func item<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubFunction<(Int), SelectableViewModelProtocol> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectionListPresenterProtocol.self, method: "item(at: Int) -> SelectableViewModelProtocol", parameterMatchers: matchers))
	    }
	    
	    func selectItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSelectionListPresenterProtocol.self, method: "selectItem(at: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SelectionListPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var numberOfItems: Cuckoo.VerifyReadOnlyProperty<Int> {
	        return .init(manager: cuckoo_manager, name: "numberOfItems", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func item<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), SelectableViewModelProtocol> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("item(at: Int) -> SelectableViewModelProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("selectItem(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SelectionListPresenterProtocolStub: SelectionListPresenterProtocol {
    
    
     var numberOfItems: Int {
        get {
            return DefaultValueRegistry.defaultValue(for: (Int).self)
        }
        
    }
    

    

    
     func item(at index: Int) -> SelectableViewModelProtocol  {
        return DefaultValueRegistry.defaultValue(for: (SelectableViewModelProtocol).self)
    }
    
     func selectItem(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockWebPresentingViewProtocol: WebPresentingViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = WebPresentingViewProtocol
    
     typealias Stubbing = __StubbingProxy_WebPresentingViewProtocol
     typealias Verification = __VerificationProxy_WebPresentingViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: WebPresentingViewProtocol?

     func enableDefaultImplementation(_ stub: WebPresentingViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_WebPresentingViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockWebPresentingViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockWebPresentingViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockWebPresentingViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockWebPresentingViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockWebPresentingViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockWebPresentingViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_WebPresentingViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class WebPresentingViewProtocolStub: WebPresentingViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport


 class MockAboutViewProtocol: AboutViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AboutViewProtocol
    
     typealias Stubbing = __StubbingProxy_AboutViewProtocol
     typealias Verification = __VerificationProxy_AboutViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AboutViewProtocol?

     func enableDefaultImplementation(_ stub: AboutViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReceive(optionViewModels: [AboutOptionViewModelProtocol])  {
        
    return cuckoo_manager.call("didReceive(optionViewModels: [AboutOptionViewModelProtocol])",
            parameters: (optionViewModels),
            escapingParameters: (optionViewModels),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(optionViewModels: optionViewModels))
        
    }
    

	 struct __StubbingProxy_AboutViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAboutViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAboutViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(optionViewModels: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([AboutOptionViewModelProtocol])> where M1.MatchedType == [AboutOptionViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([AboutOptionViewModelProtocol])>] = [wrap(matchable: optionViewModels) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAboutViewProtocol.self, method: "didReceive(optionViewModels: [AboutOptionViewModelProtocol])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AboutViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(optionViewModels: M1) -> Cuckoo.__DoNotUse<([AboutOptionViewModelProtocol]), Void> where M1.MatchedType == [AboutOptionViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([AboutOptionViewModelProtocol])>] = [wrap(matchable: optionViewModels) { $0 }]
	        return cuckoo_manager.verify("didReceive(optionViewModels: [AboutOptionViewModelProtocol])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AboutViewProtocolStub: AboutViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReceive(optionViewModels: [AboutOptionViewModelProtocol])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAboutPresenterProtocol: AboutPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AboutPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AboutPresenterProtocol
     typealias Verification = __VerificationProxy_AboutPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AboutPresenterProtocol?

     func enableDefaultImplementation(_ stub: AboutPresenterProtocol) {
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
    
    
    
     func activateOption(_ option: AboutOption)  {
        
    return cuckoo_manager.call("activateOption(_: AboutOption)",
            parameters: (option),
            escapingParameters: (option),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateOption(option))
        
    }
    

	 struct __StubbingProxy_AboutPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAboutPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateOption<M1: Cuckoo.Matchable>(_ option: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AboutOption)> where M1.MatchedType == AboutOption {
	        let matchers: [Cuckoo.ParameterMatcher<(AboutOption)>] = [wrap(matchable: option) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAboutPresenterProtocol.self, method: "activateOption(_: AboutOption)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AboutPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func activateOption<M1: Cuckoo.Matchable>(_ option: M1) -> Cuckoo.__DoNotUse<(AboutOption), Void> where M1.MatchedType == AboutOption {
	        let matchers: [Cuckoo.ParameterMatcher<(AboutOption)>] = [wrap(matchable: option) { $0 }]
	        return cuckoo_manager.verify("activateOption(_: AboutOption)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AboutPresenterProtocolStub: AboutPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateOption(_ option: AboutOption)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAboutWireframeProtocol: AboutWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AboutWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AboutWireframeProtocol
     typealias Verification = __VerificationProxy_AboutWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AboutWireframeProtocol?

     func enableDefaultImplementation(_ stub: AboutWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AboutWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAboutWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAboutWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAboutWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AboutWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AboutWireframeProtocolStub: AboutWireframeProtocol {
    

    

    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport


 class MockAccountConfirmViewProtocol: AccountConfirmViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmViewProtocol
     typealias Verification = __VerificationProxy_AccountConfirmViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmViewProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReceive(words: [String], afterConfirmationFail: Bool)  {
        
    return cuckoo_manager.call("didReceive(words: [String], afterConfirmationFail: Bool)",
            parameters: (words, afterConfirmationFail),
            escapingParameters: (words, afterConfirmationFail),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(words: words, afterConfirmationFail: afterConfirmationFail))
        
    }
    

	 struct __StubbingProxy_AccountConfirmViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountConfirmViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountConfirmViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.ProtocolStubNoReturnFunction<([String], Bool)> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmViewProtocol.self, method: "didReceive(words: [String], afterConfirmationFail: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.__DoNotUse<([String], Bool), Void> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(words: [String], afterConfirmationFail: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmViewProtocolStub: AccountConfirmViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReceive(words: [String], afterConfirmationFail: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmPresenterProtocol: AccountConfirmPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmPresenterProtocol
     typealias Verification = __VerificationProxy_AccountConfirmPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmPresenterProtocol) {
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
    
    
    
     func requestWords()  {
        
    return cuckoo_manager.call("requestWords()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestWords())
        
    }
    
    
    
     func confirm(words: [String])  {
        
    return cuckoo_manager.call("confirm(words: [String])",
            parameters: (words),
            escapingParameters: (words),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.confirm(words: words))
        
    }
    
    
    
     func skip()  {
        
    return cuckoo_manager.call("skip()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.skip())
        
    }
    

	 struct __StubbingProxy_AccountConfirmPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func requestWords() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "requestWords()", parameterMatchers: matchers))
	    }
	    
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "confirm(words: [String])", parameterMatchers: matchers))
	    }
	    
	    func skip() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmPresenterProtocol.self, method: "skip()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func requestWords() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("requestWords()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return cuckoo_manager.verify("confirm(words: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func skip() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("skip()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmPresenterProtocolStub: AccountConfirmPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func requestWords()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func confirm(words: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func skip()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmInteractorInputProtocol: AccountConfirmInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountConfirmInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func requestWords()  {
        
    return cuckoo_manager.call("requestWords()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestWords())
        
    }
    
    
    
     func confirm(words: [String])  {
        
    return cuckoo_manager.call("confirm(words: [String])",
            parameters: (words),
            escapingParameters: (words),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.confirm(words: words))
        
    }
    
    
    
     func skipConfirmation()  {
        
    return cuckoo_manager.call("skipConfirmation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.skipConfirmation())
        
    }
    

	 struct __StubbingProxy_AccountConfirmInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func requestWords() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorInputProtocol.self, method: "requestWords()", parameterMatchers: matchers))
	    }
	    
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorInputProtocol.self, method: "confirm(words: [String])", parameterMatchers: matchers))
	    }
	    
	    func skipConfirmation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorInputProtocol.self, method: "skipConfirmation()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func requestWords() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("requestWords()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func confirm<M1: Cuckoo.Matchable>(words: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: words) { $0 }]
	        return cuckoo_manager.verify("confirm(words: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func skipConfirmation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("skipConfirmation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmInteractorInputProtocolStub: AccountConfirmInteractorInputProtocol {
    

    

    
     func requestWords()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func confirm(words: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func skipConfirmation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmInteractorOutputProtocol: AccountConfirmInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountConfirmInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(words: [String], afterConfirmationFail: Bool)  {
        
    return cuckoo_manager.call("didReceive(words: [String], afterConfirmationFail: Bool)",
            parameters: (words, afterConfirmationFail),
            escapingParameters: (words, afterConfirmationFail),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(words: words, afterConfirmationFail: afterConfirmationFail))
        
    }
    
    
    
     func didCompleteConfirmation()  {
        
    return cuckoo_manager.call("didCompleteConfirmation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteConfirmation())
        
    }
    
    
    
     func didReceive(error: Error)  {
        
    return cuckoo_manager.call("didReceive(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(error: error))
        
    }
    

	 struct __StubbingProxy_AccountConfirmInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.ProtocolStubNoReturnFunction<([String], Bool)> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorOutputProtocol.self, method: "didReceive(words: [String], afterConfirmationFail: Bool)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteConfirmation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorOutputProtocol.self, method: "didCompleteConfirmation()", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmInteractorOutputProtocol.self, method: "didReceive(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(words: M1, afterConfirmationFail: M2) -> Cuckoo.__DoNotUse<([String], Bool), Void> where M1.MatchedType == [String], M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<([String], Bool)>] = [wrap(matchable: words) { $0.0 }, wrap(matchable: afterConfirmationFail) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(words: [String], afterConfirmationFail: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteConfirmation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteConfirmation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceive(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmInteractorOutputProtocolStub: AccountConfirmInteractorOutputProtocol {
    

    

    
     func didReceive(words: [String], afterConfirmationFail: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteConfirmation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountConfirmWireframeProtocol: AccountConfirmWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountConfirmWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountConfirmWireframeProtocol
     typealias Verification = __VerificationProxy_AccountConfirmWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountConfirmWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountConfirmWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: AccountConfirmViewProtocol?)  {
        
    return cuckoo_manager.call("proceed(from: AccountConfirmViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    

	 struct __StubbingProxy_AccountConfirmWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountConfirmViewProtocol?)> where M1.OptionalMatchedType == AccountConfirmViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountConfirmViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "proceed(from: AccountConfirmViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountConfirmWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountConfirmWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountConfirmViewProtocol?), Void> where M1.OptionalMatchedType == AccountConfirmViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountConfirmViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("proceed(from: AccountConfirmViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountConfirmWireframeProtocolStub: AccountConfirmWireframeProtocol {
    

    

    
     func proceed(from view: AccountConfirmViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import IrohaCrypto
import SoraFoundation


 class MockAccountCreateViewProtocol: AccountCreateViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateViewProtocol
     typealias Verification = __VerificationProxy_AccountCreateViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateViewProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(mnemonic: [String])  {
        
    return cuckoo_manager.call("set(mnemonic: [String])",
            parameters: (mnemonic),
            escapingParameters: (mnemonic),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(mnemonic: mnemonic))
        
    }
    

	 struct __StubbingProxy_AccountCreateViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountCreateViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountCreateViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(mnemonic: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: mnemonic) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "set(mnemonic: [String])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(mnemonic: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: mnemonic) { $0 }]
	        return cuckoo_manager.verify("set(mnemonic: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateViewProtocolStub: AccountCreateViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(mnemonic: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreatePresenterProtocol: AccountCreatePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreatePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreatePresenterProtocol
     typealias Verification = __VerificationProxy_AccountCreatePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreatePresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountCreatePresenterProtocol) {
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
    
    
    
     func activateInfo()  {
        
    return cuckoo_manager.call("activateInfo()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateInfo())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    
    
    
     func share()  {
        
    return cuckoo_manager.call("share()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share())
        
    }
    

	 struct __StubbingProxy_AccountCreatePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateInfo() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "activateInfo()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	    func share() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "share()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreatePresenterProtocol: Cuckoo.VerificationProxy {
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
	    func activateInfo() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateInfo()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func share() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("share()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreatePresenterProtocolStub: AccountCreatePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateInfo()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func share()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateInteractorInputProtocol: AccountCreateInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountCreateInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateInteractorInputProtocol) {
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
    

	 struct __StubbingProxy_AccountCreateInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    
	}
}

 class AccountCreateInteractorInputProtocolStub: AccountCreateInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateInteractorOutputProtocol: AccountCreateInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountCreateInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(metadata: AccountCreationMetadata)  {
        
    return cuckoo_manager.call("didReceive(metadata: AccountCreationMetadata)",
            parameters: (metadata),
            escapingParameters: (metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(metadata: metadata))
        
    }
    
    
    
     func didReceiveMnemonicGeneration(error: Error)  {
        
    return cuckoo_manager.call("didReceiveMnemonicGeneration(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveMnemonicGeneration(error: error))
        
    }
    

	 struct __StubbingProxy_AccountCreateInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreationMetadata)> where M1.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceive(metadata: AccountCreationMetadata)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveMnemonicGeneration<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceiveMnemonicGeneration(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.__DoNotUse<(AccountCreationMetadata), Void> where M1.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return cuckoo_manager.verify("didReceive(metadata: AccountCreationMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveMnemonicGeneration<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveMnemonicGeneration(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateInteractorOutputProtocolStub: AccountCreateInteractorOutputProtocol {
    

    

    
     func didReceive(metadata: AccountCreationMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveMnemonicGeneration(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateWireframeProtocol: AccountCreateWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateWireframeProtocol
     typealias Verification = __VerificationProxy_AccountCreateWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func confirm(from view: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)  {
        
    return cuckoo_manager.call("confirm(from: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)",
            parameters: (view, request, metadata),
            escapingParameters: (view, request, metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.confirm(from: view, request: request, metadata: metadata))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    

	 struct __StubbingProxy_AccountCreateWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func confirm<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, request: M2, metadata: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata)> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == AccountCreationRequest, M3.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: request) { $0.1 }, wrap(matchable: metadata) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "confirm(from: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func confirm<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(from view: M1, request: M2, metadata: M3) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == AccountCreationRequest, M3.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, AccountCreationRequest, AccountCreationMetadata)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: request) { $0.1 }, wrap(matchable: metadata) { $0.2 }]
	        return cuckoo_manager.verify("confirm(from: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateWireframeProtocolStub: AccountCreateWireframeProtocol {
    

    

    
     func confirm(from view: AccountCreateViewProtocol?, request: AccountCreationRequest, metadata: AccountCreationMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import IrohaCrypto
import SoraFoundation


 class MockAccountImportViewProtocol: AccountImportViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportViewProtocol
     typealias Verification = __VerificationProxy_AccountImportViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportViewProtocol?

     func enableDefaultImplementation(_ stub: AccountImportViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func setSource(type: AccountImportSource)  {
        
    return cuckoo_manager.call("setSource(type: AccountImportSource)",
            parameters: (type),
            escapingParameters: (type),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSource(type: type))
        
    }
    
    
    
     func setSource(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setSource(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSource(viewModel: viewModel))
        
    }
    
    
    
     func setName(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setName(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setName(viewModel: viewModel))
        
    }
    
    
    
     func setPassword(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setPassword(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setPassword(viewModel: viewModel))
        
    }
    
    
    
     func setDerivationPath(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setDerivationPath(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setDerivationPath(viewModel: viewModel))
        
    }
    
    
    
     func setUploadWarning(message: String)  {
        
    return cuckoo_manager.call("setUploadWarning(message: String)",
            parameters: (message),
            escapingParameters: (message),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setUploadWarning(message: message))
        
    }
    

	 struct __StubbingProxy_AccountImportViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountImportViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountImportViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func setSource<M1: Cuckoo.Matchable>(type: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportSource)> where M1.MatchedType == AccountImportSource {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSource)>] = [wrap(matchable: type) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setSource(type: AccountImportSource)", parameterMatchers: matchers))
	    }
	    
	    func setSource<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setSource(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setName<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setName(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setPassword<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setPassword(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setDerivationPath(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func setUploadWarning<M1: Cuckoo.Matchable>(message: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: message) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportViewProtocol.self, method: "setUploadWarning(message: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func setSource<M1: Cuckoo.Matchable>(type: M1) -> Cuckoo.__DoNotUse<(AccountImportSource), Void> where M1.MatchedType == AccountImportSource {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSource)>] = [wrap(matchable: type) { $0 }]
	        return cuckoo_manager.verify("setSource(type: AccountImportSource)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSource<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setSource(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setName<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setName(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setPassword<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setPassword(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setDerivationPath(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setUploadWarning<M1: Cuckoo.Matchable>(message: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: message) { $0 }]
	        return cuckoo_manager.verify("setUploadWarning(message: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportViewProtocolStub: AccountImportViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func setSource(type: AccountImportSource)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSource(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setName(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setPassword(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setDerivationPath(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setUploadWarning(message: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportPresenterProtocol: AccountImportPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportPresenterProtocol
     typealias Verification = __VerificationProxy_AccountImportPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportPresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountImportPresenterProtocol) {
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
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    
    
    
     func activateURL(_ url: URL)  {
        
    return cuckoo_manager.call("activateURL(_: URL)",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateURL(url))
        
    }
    

	 struct __StubbingProxy_AccountImportPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	    func activateURL<M1: Cuckoo.Matchable>(_ url: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(URL)> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportPresenterProtocol.self, method: "activateURL(_: URL)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateURL<M1: Cuckoo.Matchable>(_ url: M1) -> Cuckoo.__DoNotUse<(URL), Void> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("activateURL(_: URL)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportPresenterProtocolStub: AccountImportPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateURL(_ url: URL)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportInteractorInputProtocol: AccountImportInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountImportInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountImportInteractorInputProtocol) {
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
    
    
    
     func importAccountWithMnemonic(request: AccountImportMnemonicRequest)  {
        
    return cuckoo_manager.call("importAccountWithMnemonic(request: AccountImportMnemonicRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.importAccountWithMnemonic(request: request))
        
    }
    
    
    
     func importAccountWithSeed(request: AccountImportSeedRequest)  {
        
    return cuckoo_manager.call("importAccountWithSeed(request: AccountImportSeedRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.importAccountWithSeed(request: request))
        
    }
    
    
    
     func importAccountWithKeystore(request: AccountImportKeystoreRequest)  {
        
    return cuckoo_manager.call("importAccountWithKeystore(request: AccountImportKeystoreRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.importAccountWithKeystore(request: request))
        
    }
    
    
    
     func deriveMetadataFromKeystore(_ keystore: String)  {
        
    return cuckoo_manager.call("deriveMetadataFromKeystore(_: String)",
            parameters: (keystore),
            escapingParameters: (keystore),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.deriveMetadataFromKeystore(keystore))
        
    }
    

	 struct __StubbingProxy_AccountImportInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func importAccountWithMnemonic<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportMnemonicRequest)> where M1.MatchedType == AccountImportMnemonicRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMnemonicRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "importAccountWithMnemonic(request: AccountImportMnemonicRequest)", parameterMatchers: matchers))
	    }
	    
	    func importAccountWithSeed<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportSeedRequest)> where M1.MatchedType == AccountImportSeedRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSeedRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "importAccountWithSeed(request: AccountImportSeedRequest)", parameterMatchers: matchers))
	    }
	    
	    func importAccountWithKeystore<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportKeystoreRequest)> where M1.MatchedType == AccountImportKeystoreRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportKeystoreRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "importAccountWithKeystore(request: AccountImportKeystoreRequest)", parameterMatchers: matchers))
	    }
	    
	    func deriveMetadataFromKeystore<M1: Cuckoo.Matchable>(_ keystore: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: keystore) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorInputProtocol.self, method: "deriveMetadataFromKeystore(_: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    func importAccountWithMnemonic<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountImportMnemonicRequest), Void> where M1.MatchedType == AccountImportMnemonicRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMnemonicRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("importAccountWithMnemonic(request: AccountImportMnemonicRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func importAccountWithSeed<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountImportSeedRequest), Void> where M1.MatchedType == AccountImportSeedRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportSeedRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("importAccountWithSeed(request: AccountImportSeedRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func importAccountWithKeystore<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountImportKeystoreRequest), Void> where M1.MatchedType == AccountImportKeystoreRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportKeystoreRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("importAccountWithKeystore(request: AccountImportKeystoreRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func deriveMetadataFromKeystore<M1: Cuckoo.Matchable>(_ keystore: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: keystore) { $0 }]
	        return cuckoo_manager.verify("deriveMetadataFromKeystore(_: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportInteractorInputProtocolStub: AccountImportInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func importAccountWithMnemonic(request: AccountImportMnemonicRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func importAccountWithSeed(request: AccountImportSeedRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func importAccountWithKeystore(request: AccountImportKeystoreRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func deriveMetadataFromKeystore(_ keystore: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportInteractorOutputProtocol: AccountImportInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountImportInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountImportInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceiveAccountImport(metadata: AccountImportMetadata)  {
        
    return cuckoo_manager.call("didReceiveAccountImport(metadata: AccountImportMetadata)",
            parameters: (metadata),
            escapingParameters: (metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveAccountImport(metadata: metadata))
        
    }
    
    
    
     func didCompleteAccountImport()  {
        
    return cuckoo_manager.call("didCompleteAccountImport()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteAccountImport())
        
    }
    
    
    
     func didReceiveAccountImport(error: Error)  {
        
    return cuckoo_manager.call("didReceiveAccountImport(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveAccountImport(error: error))
        
    }
    
    
    
     func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)  {
        
    return cuckoo_manager.call("didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)",
            parameters: (text, preferredInfo),
            escapingParameters: (text, preferredInfo),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSuggestKeystore(text: text, preferredInfo: preferredInfo))
        
    }
    

	 struct __StubbingProxy_AccountImportInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportMetadata)> where M1.MatchedType == AccountImportMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didReceiveAccountImport(metadata: AccountImportMetadata)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteAccountImport() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didCompleteAccountImport()", parameterMatchers: matchers))
	    }
	    
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didReceiveAccountImport(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didSuggestKeystore<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(text: M1, preferredInfo: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(String, AccountImportPreferredInfo?)> where M1.MatchedType == String, M2.OptionalMatchedType == AccountImportPreferredInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, AccountImportPreferredInfo?)>] = [wrap(matchable: text) { $0.0 }, wrap(matchable: preferredInfo) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportInteractorOutputProtocol.self, method: "didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.__DoNotUse<(AccountImportMetadata), Void> where M1.MatchedType == AccountImportMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return cuckoo_manager.verify("didReceiveAccountImport(metadata: AccountImportMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteAccountImport() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteAccountImport()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveAccountImport<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveAccountImport(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didSuggestKeystore<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(text: M1, preferredInfo: M2) -> Cuckoo.__DoNotUse<(String, AccountImportPreferredInfo?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == AccountImportPreferredInfo {
	        let matchers: [Cuckoo.ParameterMatcher<(String, AccountImportPreferredInfo?)>] = [wrap(matchable: text) { $0.0 }, wrap(matchable: preferredInfo) { $0.1 }]
	        return cuckoo_manager.verify("didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportInteractorOutputProtocolStub: AccountImportInteractorOutputProtocol {
    

    

    
     func didReceiveAccountImport(metadata: AccountImportMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteAccountImport()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveAccountImport(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountImportWireframeProtocol: AccountImportWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountImportWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountImportWireframeProtocol
     typealias Verification = __VerificationProxy_AccountImportWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountImportWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountImportWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: AccountImportViewProtocol?)  {
        
    return cuckoo_manager.call("proceed(from: AccountImportViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    

	 struct __StubbingProxy_AccountImportWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountImportViewProtocol?)> where M1.OptionalMatchedType == AccountImportViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "proceed(from: AccountImportViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountImportWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountImportWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountImportViewProtocol?), Void> where M1.OptionalMatchedType == AccountImportViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountImportViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("proceed(from: AccountImportViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountImportWireframeProtocolStub: AccountImportWireframeProtocol {
    

    

    
     func proceed(from view: AccountImportViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport


 class MockFriendsViewProtocol: FriendsViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = FriendsViewProtocol
    
     typealias Stubbing = __StubbingProxy_FriendsViewProtocol
     typealias Verification = __VerificationProxy_FriendsViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: FriendsViewProtocol?

     func enableDefaultImplementation(_ stub: FriendsViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didReceive(friendsViewModel: FriendsInvitationViewModelProtocol)  {
        
    return cuckoo_manager.call("didReceive(friendsViewModel: FriendsInvitationViewModelProtocol)",
            parameters: (friendsViewModel),
            escapingParameters: (friendsViewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(friendsViewModel: friendsViewModel))
        
    }
    
    
    
     func didReceive(rewardsViewModels: [RewardsViewModelProtocol])  {
        
    return cuckoo_manager.call("didReceive(rewardsViewModels: [RewardsViewModelProtocol])",
            parameters: (rewardsViewModels),
            escapingParameters: (rewardsViewModels),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(rewardsViewModels: rewardsViewModels))
        
    }
    
    
    
     func didChange(applyInviteTitle: String)  {
        
    return cuckoo_manager.call("didChange(applyInviteTitle: String)",
            parameters: (applyInviteTitle),
            escapingParameters: (applyInviteTitle),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didChange(applyInviteTitle: applyInviteTitle))
        
    }
    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_FriendsViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockFriendsViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockFriendsViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockFriendsViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockFriendsViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(friendsViewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FriendsInvitationViewModelProtocol)> where M1.MatchedType == FriendsInvitationViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(FriendsInvitationViewModelProtocol)>] = [wrap(matchable: friendsViewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method: "didReceive(friendsViewModel: FriendsInvitationViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didReceive<M1: Cuckoo.Matchable>(rewardsViewModels: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([RewardsViewModelProtocol])> where M1.MatchedType == [RewardsViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([RewardsViewModelProtocol])>] = [wrap(matchable: rewardsViewModels) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method: "didReceive(rewardsViewModels: [RewardsViewModelProtocol])", parameterMatchers: matchers))
	    }
	    
	    func didChange<M1: Cuckoo.Matchable>(applyInviteTitle: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: applyInviteTitle) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method: "didChange(applyInviteTitle: String)", parameterMatchers: matchers))
	    }
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_FriendsViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(friendsViewModel: M1) -> Cuckoo.__DoNotUse<(FriendsInvitationViewModelProtocol), Void> where M1.MatchedType == FriendsInvitationViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(FriendsInvitationViewModelProtocol)>] = [wrap(matchable: friendsViewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(friendsViewModel: FriendsInvitationViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(rewardsViewModels: M1) -> Cuckoo.__DoNotUse<([RewardsViewModelProtocol]), Void> where M1.MatchedType == [RewardsViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([RewardsViewModelProtocol])>] = [wrap(matchable: rewardsViewModels) { $0 }]
	        return cuckoo_manager.verify("didReceive(rewardsViewModels: [RewardsViewModelProtocol])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didChange<M1: Cuckoo.Matchable>(applyInviteTitle: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: applyInviteTitle) { $0 }]
	        return cuckoo_manager.verify("didChange(applyInviteTitle: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class FriendsViewProtocolStub: FriendsViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didReceive(friendsViewModel: FriendsInvitationViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceive(rewardsViewModels: [RewardsViewModelProtocol])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didChange(applyInviteTitle: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockFriendsPresenterProtocol: FriendsPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = FriendsPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_FriendsPresenterProtocol
     typealias Verification = __VerificationProxy_FriendsPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: FriendsPresenterProtocol?

     func enableDefaultImplementation(_ stub: FriendsPresenterProtocol) {
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
    
    
    
     func viewDidAppear()  {
        
    return cuckoo_manager.call("viewDidAppear()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.viewDidAppear())
        
    }
    
    
    
     func didSelectAction(_ action: FriendsPresenter.InvitationActionType)  {
        
    return cuckoo_manager.call("didSelectAction(_: FriendsPresenter.InvitationActionType)",
            parameters: (action),
            escapingParameters: (action),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSelectAction(action))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_FriendsPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func viewDidAppear() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method: "viewDidAppear()", parameterMatchers: matchers))
	    }
	    
	    func didSelectAction<M1: Cuckoo.Matchable>(_ action: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FriendsPresenter.InvitationActionType)> where M1.MatchedType == FriendsPresenter.InvitationActionType {
	        let matchers: [Cuckoo.ParameterMatcher<(FriendsPresenter.InvitationActionType)>] = [wrap(matchable: action) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method: "didSelectAction(_: FriendsPresenter.InvitationActionType)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_FriendsPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func viewDidAppear() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("viewDidAppear()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didSelectAction<M1: Cuckoo.Matchable>(_ action: M1) -> Cuckoo.__DoNotUse<(FriendsPresenter.InvitationActionType), Void> where M1.MatchedType == FriendsPresenter.InvitationActionType {
	        let matchers: [Cuckoo.ParameterMatcher<(FriendsPresenter.InvitationActionType)>] = [wrap(matchable: action) { $0 }]
	        return cuckoo_manager.verify("didSelectAction(_: FriendsPresenter.InvitationActionType)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class FriendsPresenterProtocolStub: FriendsPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func viewDidAppear()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didSelectAction(_ action: FriendsPresenter.InvitationActionType)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockFriendsInteractorInputProtocol: FriendsInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = FriendsInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_FriendsInteractorInputProtocol
     typealias Verification = __VerificationProxy_FriendsInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: FriendsInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: FriendsInteractorInputProtocol) {
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
    
    
    
     func refreshUser()  {
        
    return cuckoo_manager.call("refreshUser()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.refreshUser())
        
    }
    
    
    
     func refreshInvitedUsers()  {
        
    return cuckoo_manager.call("refreshInvitedUsers()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.refreshInvitedUsers())
        
    }
    
    
    
     func apply(invitationCode: String)  {
        
    return cuckoo_manager.call("apply(invitationCode: String)",
            parameters: (invitationCode),
            escapingParameters: (invitationCode),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.apply(invitationCode: invitationCode))
        
    }
    

	 struct __StubbingProxy_FriendsInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func refreshUser() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorInputProtocol.self, method: "refreshUser()", parameterMatchers: matchers))
	    }
	    
	    func refreshInvitedUsers() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorInputProtocol.self, method: "refreshInvitedUsers()", parameterMatchers: matchers))
	    }
	    
	    func apply<M1: Cuckoo.Matchable>(invitationCode: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: invitationCode) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorInputProtocol.self, method: "apply(invitationCode: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_FriendsInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    func refreshUser() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("refreshUser()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func refreshInvitedUsers() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("refreshInvitedUsers()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func apply<M1: Cuckoo.Matchable>(invitationCode: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: invitationCode) { $0 }]
	        return cuckoo_manager.verify("apply(invitationCode: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class FriendsInteractorInputProtocolStub: FriendsInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func refreshUser()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func refreshInvitedUsers()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func apply(invitationCode: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockFriendsInteractorOutputProtocol: FriendsInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = FriendsInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_FriendsInteractorOutputProtocol
     typealias Verification = __VerificationProxy_FriendsInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: FriendsInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: FriendsInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didLoad(user: UserData)  {
        
    return cuckoo_manager.call("didLoad(user: UserData)",
            parameters: (user),
            escapingParameters: (user),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(user: user))
        
    }
    
    
    
     func didReceiveUserDataProvider(error: Error)  {
        
    return cuckoo_manager.call("didReceiveUserDataProvider(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveUserDataProvider(error: error))
        
    }
    
    
    
     func didLoad(invitationsData: ActivatedInvitationsData)  {
        
    return cuckoo_manager.call("didLoad(invitationsData: ActivatedInvitationsData)",
            parameters: (invitationsData),
            escapingParameters: (invitationsData),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(invitationsData: invitationsData))
        
    }
    
    
    
     func didReceiveInvitedUsersDataProvider(error: Error)  {
        
    return cuckoo_manager.call("didReceiveInvitedUsersDataProvider(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveInvitedUsersDataProvider(error: error))
        
    }
    

	 struct __StubbingProxy_FriendsInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didLoad<M1: Cuckoo.Matchable>(user: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UserData)> where M1.MatchedType == UserData {
	        let matchers: [Cuckoo.ParameterMatcher<(UserData)>] = [wrap(matchable: user) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method: "didLoad(user: UserData)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveUserDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method: "didReceiveUserDataProvider(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didLoad<M1: Cuckoo.Matchable>(invitationsData: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ActivatedInvitationsData)> where M1.MatchedType == ActivatedInvitationsData {
	        let matchers: [Cuckoo.ParameterMatcher<(ActivatedInvitationsData)>] = [wrap(matchable: invitationsData) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method: "didLoad(invitationsData: ActivatedInvitationsData)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveInvitedUsersDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method: "didReceiveInvitedUsersDataProvider(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_FriendsInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(user: M1) -> Cuckoo.__DoNotUse<(UserData), Void> where M1.MatchedType == UserData {
	        let matchers: [Cuckoo.ParameterMatcher<(UserData)>] = [wrap(matchable: user) { $0 }]
	        return cuckoo_manager.verify("didLoad(user: UserData)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveUserDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveUserDataProvider(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(invitationsData: M1) -> Cuckoo.__DoNotUse<(ActivatedInvitationsData), Void> where M1.MatchedType == ActivatedInvitationsData {
	        let matchers: [Cuckoo.ParameterMatcher<(ActivatedInvitationsData)>] = [wrap(matchable: invitationsData) { $0 }]
	        return cuckoo_manager.verify("didLoad(invitationsData: ActivatedInvitationsData)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveInvitedUsersDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveInvitedUsersDataProvider(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class FriendsInteractorOutputProtocolStub: FriendsInteractorOutputProtocol {
    

    

    
     func didLoad(user: UserData)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveUserDataProvider(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didLoad(invitationsData: ActivatedInvitationsData)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveInvitedUsersDataProvider(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockFriendsWireframeProtocol: FriendsWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = FriendsWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_FriendsWireframeProtocol
     typealias Verification = __VerificationProxy_FriendsWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: FriendsWireframeProtocol?

     func enableDefaultImplementation(_ stub: FriendsWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)",
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
     func requestInput(for viewModel: InputFieldViewModelProtocol, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)",
            parameters: (viewModel, view),
            escapingParameters: (viewModel, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.requestInput(for: viewModel, from: view))
        
    }
    

	 struct __StubbingProxy_FriendsWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method: "share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	    func requestInput<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for viewModel: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(InputFieldViewModelProtocol, ControllerBackedProtocol?)> where M1.MatchedType == InputFieldViewModelProtocol, M2.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputFieldViewModelProtocol, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method: "requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_FriendsWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
	        let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
	        return cuckoo_manager.verify("share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func requestInput<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for viewModel: M1, from view: M2) -> Cuckoo.__DoNotUse<(InputFieldViewModelProtocol, ControllerBackedProtocol?), Void> where M1.MatchedType == InputFieldViewModelProtocol, M2.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputFieldViewModelProtocol, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: view) { $0.1 }]
	        return cuckoo_manager.verify("requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class FriendsWireframeProtocolStub: FriendsWireframeProtocol {
    

    

    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
     func requestInput(for viewModel: InputFieldViewModelProtocol, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport


 class MockLanguageSelectionViewProtocol: LanguageSelectionViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LanguageSelectionViewProtocol
    
     typealias Stubbing = __StubbingProxy_LanguageSelectionViewProtocol
     typealias Verification = __VerificationProxy_LanguageSelectionViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LanguageSelectionViewProtocol?

     func enableDefaultImplementation(_ stub: LanguageSelectionViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReload()  {
        
    return cuckoo_manager.call("didReload()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReload())
        
    }
    

	 struct __StubbingProxy_LanguageSelectionViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLanguageSelectionViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLanguageSelectionViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReload() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionViewProtocol.self, method: "didReload()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LanguageSelectionViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReload() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReload()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LanguageSelectionViewProtocolStub: LanguageSelectionViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReload()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockLanguageSelectionPresenterProtocol: LanguageSelectionPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LanguageSelectionPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_LanguageSelectionPresenterProtocol
     typealias Verification = __VerificationProxy_LanguageSelectionPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LanguageSelectionPresenterProtocol?

     func enableDefaultImplementation(_ stub: LanguageSelectionPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var numberOfItems: Int {
        get {
            return cuckoo_manager.getter("numberOfItems",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.numberOfItems)
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
    
    
    
     func item(at index: Int) -> SelectableViewModelProtocol {
        
    return cuckoo_manager.call("item(at: Int) -> SelectableViewModelProtocol",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.item(at: index))
        
    }
    
    
    
     func selectItem(at index: Int)  {
        
    return cuckoo_manager.call("selectItem(at: Int)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectItem(at: index))
        
    }
    

	 struct __StubbingProxy_LanguageSelectionPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var numberOfItems: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLanguageSelectionPresenterProtocol, Int> {
	        return .init(manager: cuckoo_manager, name: "numberOfItems")
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func item<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubFunction<(Int), SelectableViewModelProtocol> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionPresenterProtocol.self, method: "item(at: Int) -> SelectableViewModelProtocol", parameterMatchers: matchers))
	    }
	    
	    func selectItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Int)> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionPresenterProtocol.self, method: "selectItem(at: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LanguageSelectionPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var numberOfItems: Cuckoo.VerifyReadOnlyProperty<Int> {
	        return .init(manager: cuckoo_manager, name: "numberOfItems", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func item<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), SelectableViewModelProtocol> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("item(at: Int) -> SelectableViewModelProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectItem<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(Int), Void> where M1.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(Int)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("selectItem(at: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LanguageSelectionPresenterProtocolStub: LanguageSelectionPresenterProtocol {
    
    
     var numberOfItems: Int {
        get {
            return DefaultValueRegistry.defaultValue(for: (Int).self)
        }
        
    }
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func item(at index: Int) -> SelectableViewModelProtocol  {
        return DefaultValueRegistry.defaultValue(for: (SelectableViewModelProtocol).self)
    }
    
     func selectItem(at index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockLanguageSelectionInteractorInputProtocol: LanguageSelectionInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LanguageSelectionInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_LanguageSelectionInteractorInputProtocol
     typealias Verification = __VerificationProxy_LanguageSelectionInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LanguageSelectionInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: LanguageSelectionInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func load()  {
        
    return cuckoo_manager.call("load()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.load())
        
    }
    
    
    
     func select(language: Language)  {
        
    return cuckoo_manager.call("select(language: Language)",
            parameters: (language),
            escapingParameters: (language),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.select(language: language))
        
    }
    

	 struct __StubbingProxy_LanguageSelectionInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func load() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionInteractorInputProtocol.self, method: "load()", parameterMatchers: matchers))
	    }
	    
	    func select<M1: Cuckoo.Matchable>(language: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Language)> where M1.MatchedType == Language {
	        let matchers: [Cuckoo.ParameterMatcher<(Language)>] = [wrap(matchable: language) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionInteractorInputProtocol.self, method: "select(language: Language)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LanguageSelectionInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func load() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("load()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func select<M1: Cuckoo.Matchable>(language: M1) -> Cuckoo.__DoNotUse<(Language), Void> where M1.MatchedType == Language {
	        let matchers: [Cuckoo.ParameterMatcher<(Language)>] = [wrap(matchable: language) { $0 }]
	        return cuckoo_manager.verify("select(language: Language)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LanguageSelectionInteractorInputProtocolStub: LanguageSelectionInteractorInputProtocol {
    

    

    
     func load()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func select(language: Language)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockLanguageSelectionInteractorOutputProtocol: LanguageSelectionInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LanguageSelectionInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_LanguageSelectionInteractorOutputProtocol
     typealias Verification = __VerificationProxy_LanguageSelectionInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LanguageSelectionInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: LanguageSelectionInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didLoad(selectedLanguage: Language)  {
        
    return cuckoo_manager.call("didLoad(selectedLanguage: Language)",
            parameters: (selectedLanguage),
            escapingParameters: (selectedLanguage),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(selectedLanguage: selectedLanguage))
        
    }
    
    
    
     func didLoad(languages: [Language])  {
        
    return cuckoo_manager.call("didLoad(languages: [Language])",
            parameters: (languages),
            escapingParameters: (languages),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(languages: languages))
        
    }
    

	 struct __StubbingProxy_LanguageSelectionInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didLoad<M1: Cuckoo.Matchable>(selectedLanguage: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Language)> where M1.MatchedType == Language {
	        let matchers: [Cuckoo.ParameterMatcher<(Language)>] = [wrap(matchable: selectedLanguage) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionInteractorOutputProtocol.self, method: "didLoad(selectedLanguage: Language)", parameterMatchers: matchers))
	    }
	    
	    func didLoad<M1: Cuckoo.Matchable>(languages: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([Language])> where M1.MatchedType == [Language] {
	        let matchers: [Cuckoo.ParameterMatcher<([Language])>] = [wrap(matchable: languages) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockLanguageSelectionInteractorOutputProtocol.self, method: "didLoad(languages: [Language])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LanguageSelectionInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(selectedLanguage: M1) -> Cuckoo.__DoNotUse<(Language), Void> where M1.MatchedType == Language {
	        let matchers: [Cuckoo.ParameterMatcher<(Language)>] = [wrap(matchable: selectedLanguage) { $0 }]
	        return cuckoo_manager.verify("didLoad(selectedLanguage: Language)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(languages: M1) -> Cuckoo.__DoNotUse<([Language]), Void> where M1.MatchedType == [Language] {
	        let matchers: [Cuckoo.ParameterMatcher<([Language])>] = [wrap(matchable: languages) { $0 }]
	        return cuckoo_manager.verify("didLoad(languages: [Language])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LanguageSelectionInteractorOutputProtocolStub: LanguageSelectionInteractorOutputProtocol {
    

    

    
     func didLoad(selectedLanguage: Language)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didLoad(languages: [Language])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockLanguageSelectionWireframeProtocol: LanguageSelectionWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LanguageSelectionWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_LanguageSelectionWireframeProtocol
     typealias Verification = __VerificationProxy_LanguageSelectionWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LanguageSelectionWireframeProtocol?

     func enableDefaultImplementation(_ stub: LanguageSelectionWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    

	 struct __StubbingProxy_LanguageSelectionWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	}

	 struct __VerificationProxy_LanguageSelectionWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	}
}

 class LanguageSelectionWireframeProtocolStub: LanguageSelectionWireframeProtocol {
    

    

    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockChildPresenterProtocol: ChildPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ChildPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_ChildPresenterProtocol
     typealias Verification = __VerificationProxy_ChildPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ChildPresenterProtocol?

     func enableDefaultImplementation(_ stub: ChildPresenterProtocol) {
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
    

	 struct __StubbingProxy_ChildPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockChildPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ChildPresenterProtocol: Cuckoo.VerificationProxy {
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
	    
	}
}

 class ChildPresenterProtocolStub: ChildPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockInvitationHandlePresenterProtocol: InvitationHandlePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = InvitationHandlePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_InvitationHandlePresenterProtocol
     typealias Verification = __VerificationProxy_InvitationHandlePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InvitationHandlePresenterProtocol?

     func enableDefaultImplementation(_ stub: InvitationHandlePresenterProtocol) {
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
    
    
    
     func navigate(to invitation: InvitationDeepLink) -> Bool {
        
    return cuckoo_manager.call("navigate(to: InvitationDeepLink) -> Bool",
            parameters: (invitation),
            escapingParameters: (invitation),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.navigate(to: invitation))
        
    }
    

	 struct __StubbingProxy_InvitationHandlePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandlePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func navigate<M1: Cuckoo.Matchable>(to invitation: M1) -> Cuckoo.ProtocolStubFunction<(InvitationDeepLink), Bool> where M1.MatchedType == InvitationDeepLink {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationDeepLink)>] = [wrap(matchable: invitation) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandlePresenterProtocol.self, method: "navigate(to: InvitationDeepLink) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InvitationHandlePresenterProtocol: Cuckoo.VerificationProxy {
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
	    func navigate<M1: Cuckoo.Matchable>(to invitation: M1) -> Cuckoo.__DoNotUse<(InvitationDeepLink), Bool> where M1.MatchedType == InvitationDeepLink {
	        let matchers: [Cuckoo.ParameterMatcher<(InvitationDeepLink)>] = [wrap(matchable: invitation) { $0 }]
	        return cuckoo_manager.verify("navigate(to: InvitationDeepLink) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InvitationHandlePresenterProtocolStub: InvitationHandlePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func navigate(to invitation: InvitationDeepLink) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}



 class MockInvitationHandleInteractorInputProtocol: InvitationHandleInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = InvitationHandleInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_InvitationHandleInteractorInputProtocol
     typealias Verification = __VerificationProxy_InvitationHandleInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InvitationHandleInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: InvitationHandleInteractorInputProtocol) {
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
    
    
    
     func refresh()  {
        
    return cuckoo_manager.call("refresh()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.refresh())
        
    }
    
    
    
     func apply(invitationCode: String)  {
        
    return cuckoo_manager.call("apply(invitationCode: String)",
            parameters: (invitationCode),
            escapingParameters: (invitationCode),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.apply(invitationCode: invitationCode))
        
    }
    

	 struct __StubbingProxy_InvitationHandleInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func refresh() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorInputProtocol.self, method: "refresh()", parameterMatchers: matchers))
	    }
	    
	    func apply<M1: Cuckoo.Matchable>(invitationCode: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: invitationCode) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorInputProtocol.self, method: "apply(invitationCode: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InvitationHandleInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    func refresh() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("refresh()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func apply<M1: Cuckoo.Matchable>(invitationCode: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: invitationCode) { $0 }]
	        return cuckoo_manager.verify("apply(invitationCode: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InvitationHandleInteractorInputProtocolStub: InvitationHandleInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func refresh()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func apply(invitationCode: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockInvitationHandleInteractorOutputProtocol: InvitationHandleInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = InvitationHandleInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_InvitationHandleInteractorOutputProtocol
     typealias Verification = __VerificationProxy_InvitationHandleInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InvitationHandleInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: InvitationHandleInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(userData: UserData)  {
        
    return cuckoo_manager.call("didReceive(userData: UserData)",
            parameters: (userData),
            escapingParameters: (userData),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(userData: userData))
        
    }
    
    
    
     func didReceiveUserDataProvider(error: Error)  {
        
    return cuckoo_manager.call("didReceiveUserDataProvider(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveUserDataProvider(error: error))
        
    }
    
    
    
     func didApply(invitationCode: String)  {
        
    return cuckoo_manager.call("didApply(invitationCode: String)",
            parameters: (invitationCode),
            escapingParameters: (invitationCode),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didApply(invitationCode: invitationCode))
        
    }
    
    
    
     func didReceiveInvitationApplication(error: Error, of code: String)  {
        
    return cuckoo_manager.call("didReceiveInvitationApplication(error: Error, of: String)",
            parameters: (error, code),
            escapingParameters: (error, code),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveInvitationApplication(error: error, of: code))
        
    }
    

	 struct __StubbingProxy_InvitationHandleInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(userData: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UserData)> where M1.MatchedType == UserData {
	        let matchers: [Cuckoo.ParameterMatcher<(UserData)>] = [wrap(matchable: userData) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorOutputProtocol.self, method: "didReceive(userData: UserData)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveUserDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorOutputProtocol.self, method: "didReceiveUserDataProvider(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didApply<M1: Cuckoo.Matchable>(invitationCode: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: invitationCode) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorOutputProtocol.self, method: "didApply(invitationCode: String)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveInvitationApplication<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, of code: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, String)> where M1.MatchedType == Error, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, String)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: code) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleInteractorOutputProtocol.self, method: "didReceiveInvitationApplication(error: Error, of: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InvitationHandleInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(userData: M1) -> Cuckoo.__DoNotUse<(UserData), Void> where M1.MatchedType == UserData {
	        let matchers: [Cuckoo.ParameterMatcher<(UserData)>] = [wrap(matchable: userData) { $0 }]
	        return cuckoo_manager.verify("didReceive(userData: UserData)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveUserDataProvider<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveUserDataProvider(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didApply<M1: Cuckoo.Matchable>(invitationCode: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: invitationCode) { $0 }]
	        return cuckoo_manager.verify("didApply(invitationCode: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveInvitationApplication<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, of code: M2) -> Cuckoo.__DoNotUse<(Error, String), Void> where M1.MatchedType == Error, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, String)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: code) { $0.1 }]
	        return cuckoo_manager.verify("didReceiveInvitationApplication(error: Error, of: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InvitationHandleInteractorOutputProtocolStub: InvitationHandleInteractorOutputProtocol {
    

    

    
     func didReceive(userData: UserData)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveUserDataProvider(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didApply(invitationCode: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveInvitationApplication(error: Error, of code: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockInvitationHandleWireframeProtocol: InvitationHandleWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = InvitationHandleWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_InvitationHandleWireframeProtocol
     typealias Verification = __VerificationProxy_InvitationHandleWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: InvitationHandleWireframeProtocol?

     func enableDefaultImplementation(_ stub: InvitationHandleWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    

	 struct __StubbingProxy_InvitationHandleWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockInvitationHandleWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_InvitationHandleWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class InvitationHandleWireframeProtocolStub: InvitationHandleWireframeProtocol {
    

    

    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import CommonWallet
import UIKit


 class MockMainTabBarViewProtocol: MainTabBarViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = MainTabBarViewProtocol
    
     typealias Stubbing = __StubbingProxy_MainTabBarViewProtocol
     typealias Verification = __VerificationProxy_MainTabBarViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: MainTabBarViewProtocol?

     func enableDefaultImplementation(_ stub: MainTabBarViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReplaceView(for newView: UIViewController, for index: Int)  {
        
    return cuckoo_manager.call("didReplaceView(for: UIViewController, for: Int)",
            parameters: (newView, index),
            escapingParameters: (newView, index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReplaceView(for: newView, for: index))
        
    }
    

	 struct __StubbingProxy_MainTabBarViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockMainTabBarViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockMainTabBarViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReplaceView<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for newView: M1, for index: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UIViewController, Int)> where M1.MatchedType == UIViewController, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(UIViewController, Int)>] = [wrap(matchable: newView) { $0.0 }, wrap(matchable: index) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarViewProtocol.self, method: "didReplaceView(for: UIViewController, for: Int)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_MainTabBarViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReplaceView<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for newView: M1, for index: M2) -> Cuckoo.__DoNotUse<(UIViewController, Int), Void> where M1.MatchedType == UIViewController, M2.MatchedType == Int {
	        let matchers: [Cuckoo.ParameterMatcher<(UIViewController, Int)>] = [wrap(matchable: newView) { $0.0 }, wrap(matchable: index) { $0.1 }]
	        return cuckoo_manager.verify("didReplaceView(for: UIViewController, for: Int)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class MainTabBarViewProtocolStub: MainTabBarViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReplaceView(for newView: UIViewController, for index: Int)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockMainTabBarPresenterProtocol: MainTabBarPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = MainTabBarPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_MainTabBarPresenterProtocol
     typealias Verification = __VerificationProxy_MainTabBarPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: MainTabBarPresenterProtocol?

     func enableDefaultImplementation(_ stub: MainTabBarPresenterProtocol) {
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
    
    
    
     func viewDidAppear()  {
        
    return cuckoo_manager.call("viewDidAppear()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.viewDidAppear())
        
    }
    

	 struct __StubbingProxy_MainTabBarPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func viewDidAppear() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarPresenterProtocol.self, method: "viewDidAppear()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_MainTabBarPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func viewDidAppear() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("viewDidAppear()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class MainTabBarPresenterProtocolStub: MainTabBarPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func viewDidAppear()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockMainTabBarInteractorInputProtocol: MainTabBarInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = MainTabBarInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_MainTabBarInteractorInputProtocol
     typealias Verification = __VerificationProxy_MainTabBarInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: MainTabBarInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: MainTabBarInteractorInputProtocol) {
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
    

	 struct __StubbingProxy_MainTabBarInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_MainTabBarInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    
	}
}

 class MainTabBarInteractorInputProtocolStub: MainTabBarInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockMainTabBarInteractorOutputProtocol: MainTabBarInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = MainTabBarInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_MainTabBarInteractorOutputProtocol
     typealias Verification = __VerificationProxy_MainTabBarInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: MainTabBarInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: MainTabBarInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReloadSelectedAccount()  {
        
    return cuckoo_manager.call("didReloadSelectedAccount()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReloadSelectedAccount())
        
    }
    
    
    
     func didReloadSelectedNetwork()  {
        
    return cuckoo_manager.call("didReloadSelectedNetwork()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReloadSelectedNetwork())
        
    }
    
    
    
     func didUpdateWalletInfo()  {
        
    return cuckoo_manager.call("didUpdateWalletInfo()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didUpdateWalletInfo())
        
    }
    
    
    
     func didRequestImportAccount()  {
        
    return cuckoo_manager.call("didRequestImportAccount()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRequestImportAccount())
        
    }
    
    
    
     func didRequestMigration(with service: MigrationServiceProtocol)  {
        
    return cuckoo_manager.call("didRequestMigration(with: MigrationServiceProtocol)",
            parameters: (service),
            escapingParameters: (service),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRequestMigration(with: service))
        
    }
    
    
    
     func didEndMigration()  {
        
    return cuckoo_manager.call("didEndMigration()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didEndMigration())
        
    }
    
    
    
     func didEndTransaction()  {
        
    return cuckoo_manager.call("didEndTransaction()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didEndTransaction())
        
    }
    

	 struct __StubbingProxy_MainTabBarInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReloadSelectedAccount() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didReloadSelectedAccount()", parameterMatchers: matchers))
	    }
	    
	    func didReloadSelectedNetwork() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didReloadSelectedNetwork()", parameterMatchers: matchers))
	    }
	    
	    func didUpdateWalletInfo() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didUpdateWalletInfo()", parameterMatchers: matchers))
	    }
	    
	    func didRequestImportAccount() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didRequestImportAccount()", parameterMatchers: matchers))
	    }
	    
	    func didRequestMigration<M1: Cuckoo.Matchable>(with service: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MigrationServiceProtocol)> where M1.MatchedType == MigrationServiceProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MigrationServiceProtocol)>] = [wrap(matchable: service) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didRequestMigration(with: MigrationServiceProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didEndMigration() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didEndMigration()", parameterMatchers: matchers))
	    }
	    
	    func didEndTransaction() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarInteractorOutputProtocol.self, method: "didEndTransaction()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_MainTabBarInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReloadSelectedAccount() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReloadSelectedAccount()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReloadSelectedNetwork() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReloadSelectedNetwork()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didUpdateWalletInfo() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didUpdateWalletInfo()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didRequestImportAccount() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didRequestImportAccount()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didRequestMigration<M1: Cuckoo.Matchable>(with service: M1) -> Cuckoo.__DoNotUse<(MigrationServiceProtocol), Void> where M1.MatchedType == MigrationServiceProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MigrationServiceProtocol)>] = [wrap(matchable: service) { $0 }]
	        return cuckoo_manager.verify("didRequestMigration(with: MigrationServiceProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didEndMigration() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didEndMigration()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didEndTransaction() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didEndTransaction()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class MainTabBarInteractorOutputProtocolStub: MainTabBarInteractorOutputProtocol {
    

    

    
     func didReloadSelectedAccount()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReloadSelectedNetwork()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didUpdateWalletInfo()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didRequestImportAccount()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didRequestMigration(with service: MigrationServiceProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didEndMigration()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didEndTransaction()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockMainTabBarWireframeProtocol: MainTabBarWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = MainTabBarWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_MainTabBarWireframeProtocol
     typealias Verification = __VerificationProxy_MainTabBarWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: MainTabBarWireframeProtocol?

     func enableDefaultImplementation(_ stub: MainTabBarWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var walletContext: CommonWalletContextProtocol {
        get {
            return cuckoo_manager.getter("walletContext",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.walletContext)
        }
        
        set {
            cuckoo_manager.setter("walletContext",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.walletContext = newValue)
        }
        
    }
    

    

    
    
    
     func showNewWalletView(on view: MainTabBarViewProtocol?)  {
        
    return cuckoo_manager.call("showNewWalletView(on: MainTabBarViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showNewWalletView(on: view))
        
    }
    
    
    
     func reloadWalletContent()  {
        
    return cuckoo_manager.call("reloadWalletContent()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reloadWalletContent())
        
    }
    
    
    
     func presentAccountImport(on view: MainTabBarViewProtocol?)  {
        
    return cuckoo_manager.call("presentAccountImport(on: MainTabBarViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentAccountImport(on: view))
        
    }
    
    
    
     func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol)  {
        
    return cuckoo_manager.call("presentClaim(on: MainTabBarViewProtocol?, with: MigrationServiceProtocol)",
            parameters: (view, service),
            escapingParameters: (view, service),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentClaim(on: view, with: service))
        
    }
    
    
    
     func removeClaim(on view: MainTabBarViewProtocol?)  {
        
    return cuckoo_manager.call("removeClaim(on: MainTabBarViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeClaim(on: view))
        
    }
    
    
    
     func showTransactionSuccess(on view: MainTabBarViewProtocol?)  {
        
    return cuckoo_manager.call("showTransactionSuccess(on: MainTabBarViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showTransactionSuccess(on: view))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_MainTabBarWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var walletContext: Cuckoo.ProtocolToBeStubbedProperty<MockMainTabBarWireframeProtocol, CommonWalletContextProtocol> {
	        return .init(manager: cuckoo_manager, name: "walletContext")
	    }
	    
	    
	    func showNewWalletView<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MainTabBarViewProtocol?)> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "showNewWalletView(on: MainTabBarViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func reloadWalletContent() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "reloadWalletContent()", parameterMatchers: matchers))
	    }
	    
	    func presentAccountImport<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MainTabBarViewProtocol?)> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "presentAccountImport(on: MainTabBarViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentClaim<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(on view: M1, with service: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(MainTabBarViewProtocol?, MigrationServiceProtocol)> where M1.OptionalMatchedType == MainTabBarViewProtocol, M2.MatchedType == MigrationServiceProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?, MigrationServiceProtocol)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: service) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "presentClaim(on: MainTabBarViewProtocol?, with: MigrationServiceProtocol)", parameterMatchers: matchers))
	    }
	    
	    func removeClaim<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MainTabBarViewProtocol?)> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "removeClaim(on: MainTabBarViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showTransactionSuccess<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MainTabBarViewProtocol?)> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "showTransactionSuccess(on: MainTabBarViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockMainTabBarWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_MainTabBarWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var walletContext: Cuckoo.VerifyProperty<CommonWalletContextProtocol> {
	        return .init(manager: cuckoo_manager, name: "walletContext", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func showNewWalletView<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.__DoNotUse<(MainTabBarViewProtocol?), Void> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showNewWalletView(on: MainTabBarViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func reloadWalletContent() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("reloadWalletContent()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentAccountImport<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.__DoNotUse<(MainTabBarViewProtocol?), Void> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("presentAccountImport(on: MainTabBarViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentClaim<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(on view: M1, with service: M2) -> Cuckoo.__DoNotUse<(MainTabBarViewProtocol?, MigrationServiceProtocol), Void> where M1.OptionalMatchedType == MainTabBarViewProtocol, M2.MatchedType == MigrationServiceProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?, MigrationServiceProtocol)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: service) { $0.1 }]
	        return cuckoo_manager.verify("presentClaim(on: MainTabBarViewProtocol?, with: MigrationServiceProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func removeClaim<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.__DoNotUse<(MainTabBarViewProtocol?), Void> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("removeClaim(on: MainTabBarViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showTransactionSuccess<M1: Cuckoo.OptionalMatchable>(on view: M1) -> Cuckoo.__DoNotUse<(MainTabBarViewProtocol?), Void> where M1.OptionalMatchedType == MainTabBarViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(MainTabBarViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showTransactionSuccess(on: MainTabBarViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class MainTabBarWireframeProtocolStub: MainTabBarWireframeProtocol {
    
    
     var walletContext: CommonWalletContextProtocol {
        get {
            return DefaultValueRegistry.defaultValue(for: (CommonWalletContextProtocol).self)
        }
        
        set { }
        
    }
    

    

    
     func showNewWalletView(on view: MainTabBarViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func reloadWalletContent()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentAccountImport(on view: MainTabBarViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func removeClaim(on view: MainTabBarViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showTransactionSuccess(on view: MainTabBarViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport


 class MockNetworkAvailabilityLayerInteractorInputProtocol: NetworkAvailabilityLayerInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkAvailabilityLayerInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkAvailabilityLayerInteractorInputProtocol
     typealias Verification = __VerificationProxy_NetworkAvailabilityLayerInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkAvailabilityLayerInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: NetworkAvailabilityLayerInteractorInputProtocol) {
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
    

	 struct __StubbingProxy_NetworkAvailabilityLayerInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkAvailabilityLayerInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkAvailabilityLayerInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    
	}
}

 class NetworkAvailabilityLayerInteractorInputProtocolStub: NetworkAvailabilityLayerInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockNetworkAvailabilityLayerInteractorOutputProtocol: NetworkAvailabilityLayerInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = NetworkAvailabilityLayerInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_NetworkAvailabilityLayerInteractorOutputProtocol
     typealias Verification = __VerificationProxy_NetworkAvailabilityLayerInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: NetworkAvailabilityLayerInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: NetworkAvailabilityLayerInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didDecideUnreachableStatusPresentation()  {
        
    return cuckoo_manager.call("didDecideUnreachableStatusPresentation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideUnreachableStatusPresentation())
        
    }
    
    
    
     func didDecideReachableStatusPresentation()  {
        
    return cuckoo_manager.call("didDecideReachableStatusPresentation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideReachableStatusPresentation())
        
    }
    

	 struct __StubbingProxy_NetworkAvailabilityLayerInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didDecideUnreachableStatusPresentation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkAvailabilityLayerInteractorOutputProtocol.self, method: "didDecideUnreachableStatusPresentation()", parameterMatchers: matchers))
	    }
	    
	    func didDecideReachableStatusPresentation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockNetworkAvailabilityLayerInteractorOutputProtocol.self, method: "didDecideReachableStatusPresentation()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_NetworkAvailabilityLayerInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didDecideUnreachableStatusPresentation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideUnreachableStatusPresentation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideReachableStatusPresentation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideReachableStatusPresentation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class NetworkAvailabilityLayerInteractorOutputProtocolStub: NetworkAvailabilityLayerInteractorOutputProtocol {
    

    

    
     func didDecideUnreachableStatusPresentation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideReachableStatusPresentation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockOnboardingMainViewProtocol: OnboardingMainViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainViewProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainViewProtocol
     typealias Verification = __VerificationProxy_OnboardingMainViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainViewProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_OnboardingMainViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainViewProtocolStub: OnboardingMainViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainPresenterProtocol: OnboardingMainPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainPresenterProtocol
     typealias Verification = __VerificationProxy_OnboardingMainPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainPresenterProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainPresenterProtocol) {
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
    
    
    
     func activateSignup()  {
        
    return cuckoo_manager.call("activateSignup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateSignup())
        
    }
    
    
    
     func activateAccountRestore()  {
        
    return cuckoo_manager.call("activateAccountRestore()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAccountRestore())
        
    }
    

	 struct __StubbingProxy_OnboardingMainPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateSignup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateSignup()", parameterMatchers: matchers))
	    }
	    
	    func activateAccountRestore() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateAccountRestore()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func activateSignup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateSignup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAccountRestore() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAccountRestore()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainPresenterProtocolStub: OnboardingMainPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateSignup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAccountRestore()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainInteractorInputProtocol: OnboardingMainInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainInteractorInputProtocol
     typealias Verification = __VerificationProxy_OnboardingMainInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainInteractorInputProtocol) {
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
    

	 struct __StubbingProxy_OnboardingMainInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    
	}
}

 class OnboardingMainInteractorInputProtocolStub: OnboardingMainInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainInteractorOutputProtocol: OnboardingMainInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainInteractorOutputProtocol
     typealias Verification = __VerificationProxy_OnboardingMainInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didSuggestKeystoreImport()  {
        
    return cuckoo_manager.call("didSuggestKeystoreImport()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSuggestKeystoreImport())
        
    }
    

	 struct __StubbingProxy_OnboardingMainInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didSuggestKeystoreImport() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainInteractorOutputProtocol.self, method: "didSuggestKeystoreImport()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didSuggestKeystoreImport() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didSuggestKeystoreImport()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainInteractorOutputProtocolStub: OnboardingMainInteractorOutputProtocol {
    

    

    
     func didSuggestKeystoreImport()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainWireframeProtocol: OnboardingMainWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainWireframeProtocol
     typealias Verification = __VerificationProxy_OnboardingMainWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainWireframeProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showSignup(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showSignup(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSignup(from: view))
        
    }
    
    
    
     func showAccountRestore(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showAccountRestore(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAccountRestore(from: view))
        
    }
    
    
    
     func showKeystoreImport(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showKeystoreImport(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showKeystoreImport(from: view))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func presentUnsupportedVersion(for data: SupportedVersionData, on window: UIWindow?, animated: Bool)  {
        
    return cuckoo_manager.call("presentUnsupportedVersion(for: SupportedVersionData, on: UIWindow?, animated: Bool)",
            parameters: (data, window, animated),
            escapingParameters: (data, window, animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentUnsupportedVersion(for: data, on: window, animated: animated))
        
    }
    

	 struct __StubbingProxy_OnboardingMainWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showSignup(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAccountRestore<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showAccountRestore(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showKeystoreImport<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showKeystoreImport(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentUnsupportedVersion<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for data: M1, on window: M2, animated: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(SupportedVersionData, UIWindow?, Bool)> where M1.MatchedType == SupportedVersionData, M2.OptionalMatchedType == UIWindow, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(SupportedVersionData, UIWindow?, Bool)>] = [wrap(matchable: data) { $0.0 }, wrap(matchable: window) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "presentUnsupportedVersion(for: SupportedVersionData, on: UIWindow?, animated: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showSignup(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAccountRestore<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAccountRestore(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showKeystoreImport<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showKeystoreImport(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentUnsupportedVersion<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(for data: M1, on window: M2, animated: M3) -> Cuckoo.__DoNotUse<(SupportedVersionData, UIWindow?, Bool), Void> where M1.MatchedType == SupportedVersionData, M2.OptionalMatchedType == UIWindow, M3.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(SupportedVersionData, UIWindow?, Bool)>] = [wrap(matchable: data) { $0.0 }, wrap(matchable: window) { $0.1 }, wrap(matchable: animated) { $0.2 }]
	        return cuckoo_manager.verify("presentUnsupportedVersion(for: SupportedVersionData, on: UIWindow?, animated: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainWireframeProtocolStub: OnboardingMainWireframeProtocol {
    

    

    
     func showSignup(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAccountRestore(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showKeystoreImport(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentUnsupportedVersion(for data: SupportedVersionData, on window: UIWindow?, animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation
import SoraFoundation


 class MockPersonalUpdateViewProtocol: PersonalUpdateViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PersonalUpdateViewProtocol
    
     typealias Stubbing = __StubbingProxy_PersonalUpdateViewProtocol
     typealias Verification = __VerificationProxy_PersonalUpdateViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PersonalUpdateViewProtocol?

     func enableDefaultImplementation(_ stub: PersonalUpdateViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReceive(viewModels: [InputViewModelProtocol])  {
        
    return cuckoo_manager.call("didReceive(viewModels: [InputViewModelProtocol])",
            parameters: (viewModels),
            escapingParameters: (viewModels),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(viewModels: viewModels))
        
    }
    
    
    
     func didStartSaving()  {
        
    return cuckoo_manager.call("didStartSaving()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartSaving())
        
    }
    
    
    
     func didCompleteSaving(success: Bool)  {
        
    return cuckoo_manager.call("didCompleteSaving(success: Bool)",
            parameters: (success),
            escapingParameters: (success),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteSaving(success: success))
        
    }
    

	 struct __StubbingProxy_PersonalUpdateViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPersonalUpdateViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPersonalUpdateViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(viewModels: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([InputViewModelProtocol])> where M1.MatchedType == [InputViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([InputViewModelProtocol])>] = [wrap(matchable: viewModels) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateViewProtocol.self, method: "didReceive(viewModels: [InputViewModelProtocol])", parameterMatchers: matchers))
	    }
	    
	    func didStartSaving() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateViewProtocol.self, method: "didStartSaving()", parameterMatchers: matchers))
	    }
	    
	    func didCompleteSaving<M1: Cuckoo.Matchable>(success: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool)> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: success) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateViewProtocol.self, method: "didCompleteSaving(success: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PersonalUpdateViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(viewModels: M1) -> Cuckoo.__DoNotUse<([InputViewModelProtocol]), Void> where M1.MatchedType == [InputViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([InputViewModelProtocol])>] = [wrap(matchable: viewModels) { $0 }]
	        return cuckoo_manager.verify("didReceive(viewModels: [InputViewModelProtocol])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartSaving() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartSaving()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteSaving<M1: Cuckoo.Matchable>(success: M1) -> Cuckoo.__DoNotUse<(Bool), Void> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: success) { $0 }]
	        return cuckoo_manager.verify("didCompleteSaving(success: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PersonalUpdateViewProtocolStub: PersonalUpdateViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReceive(viewModels: [InputViewModelProtocol])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartSaving()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteSaving(success: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPersonalUpdatePresenterProtocol: PersonalUpdatePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PersonalUpdatePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_PersonalUpdatePresenterProtocol
     typealias Verification = __VerificationProxy_PersonalUpdatePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PersonalUpdatePresenterProtocol?

     func enableDefaultImplementation(_ stub: PersonalUpdatePresenterProtocol) {
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
    
    
    
     func save()  {
        
    return cuckoo_manager.call("save()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.save())
        
    }
    

	 struct __StubbingProxy_PersonalUpdatePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdatePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func save() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdatePresenterProtocol.self, method: "save()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PersonalUpdatePresenterProtocol: Cuckoo.VerificationProxy {
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
	    func save() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("save()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PersonalUpdatePresenterProtocolStub: PersonalUpdatePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func save()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPersonalUpdateInteractorInputProtocol: PersonalUpdateInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PersonalUpdateInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_PersonalUpdateInteractorInputProtocol
     typealias Verification = __VerificationProxy_PersonalUpdateInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PersonalUpdateInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: PersonalUpdateInteractorInputProtocol) {
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
    
    
    
     func update(username: String?)  {
        
    return cuckoo_manager.call("update(username: String?)",
            parameters: (username),
            escapingParameters: (username),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.update(username: username))
        
    }
    

	 struct __StubbingProxy_PersonalUpdateInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func update<M1: Cuckoo.OptionalMatchable>(username: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String?)> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: username) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateInteractorInputProtocol.self, method: "update(username: String?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PersonalUpdateInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    func update<M1: Cuckoo.OptionalMatchable>(username: M1) -> Cuckoo.__DoNotUse<(String?), Void> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: username) { $0 }]
	        return cuckoo_manager.verify("update(username: String?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PersonalUpdateInteractorInputProtocolStub: PersonalUpdateInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func update(username: String?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPersonalUpdateInteractorOutputProtocol: PersonalUpdateInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PersonalUpdateInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_PersonalUpdateInteractorOutputProtocol
     typealias Verification = __VerificationProxy_PersonalUpdateInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PersonalUpdateInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: PersonalUpdateInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(username: String?)  {
        
    return cuckoo_manager.call("didReceive(username: String?)",
            parameters: (username),
            escapingParameters: (username),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(username: username))
        
    }
    
    
    
     func didUpdate(username: String?)  {
        
    return cuckoo_manager.call("didUpdate(username: String?)",
            parameters: (username),
            escapingParameters: (username),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didUpdate(username: username))
        
    }
    

	 struct __StubbingProxy_PersonalUpdateInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.OptionalMatchable>(username: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String?)> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: username) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateInteractorOutputProtocol.self, method: "didReceive(username: String?)", parameterMatchers: matchers))
	    }
	    
	    func didUpdate<M1: Cuckoo.OptionalMatchable>(username: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String?)> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: username) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateInteractorOutputProtocol.self, method: "didUpdate(username: String?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PersonalUpdateInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.OptionalMatchable>(username: M1) -> Cuckoo.__DoNotUse<(String?), Void> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: username) { $0 }]
	        return cuckoo_manager.verify("didReceive(username: String?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didUpdate<M1: Cuckoo.OptionalMatchable>(username: M1) -> Cuckoo.__DoNotUse<(String?), Void> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: username) { $0 }]
	        return cuckoo_manager.verify("didUpdate(username: String?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PersonalUpdateInteractorOutputProtocolStub: PersonalUpdateInteractorOutputProtocol {
    

    

    
     func didReceive(username: String?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didUpdate(username: String?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPersonalUpdateWireframeProtocol: PersonalUpdateWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PersonalUpdateWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_PersonalUpdateWireframeProtocol
     typealias Verification = __VerificationProxy_PersonalUpdateWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PersonalUpdateWireframeProtocol?

     func enableDefaultImplementation(_ stub: PersonalUpdateWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func close(view: PersonalUpdateViewProtocol?)  {
        
    return cuckoo_manager.call("close(view: PersonalUpdateViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.close(view: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_PersonalUpdateWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PersonalUpdateViewProtocol?)> where M1.OptionalMatchedType == PersonalUpdateViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PersonalUpdateViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateWireframeProtocol.self, method: "close(view: PersonalUpdateViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPersonalUpdateWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PersonalUpdateWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func close<M1: Cuckoo.OptionalMatchable>(view: M1) -> Cuckoo.__DoNotUse<(PersonalUpdateViewProtocol?), Void> where M1.OptionalMatchedType == PersonalUpdateViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PersonalUpdateViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("close(view: PersonalUpdateViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PersonalUpdateWireframeProtocolStub: PersonalUpdateWireframeProtocol {
    

    

    
     func close(view: PersonalUpdateViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockPinSetupViewProtocol: PinSetupViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupViewProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupViewProtocol
     typealias Verification = __VerificationProxy_PinSetupViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupViewProtocol?

     func enableDefaultImplementation(_ stub: PinSetupViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)",
            parameters: (biometryType, completionBlock),
            escapingParameters: (biometryType, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didRequestBiometryUsage(biometryType: biometryType, completionBlock: completionBlock))
        
    }
    
    
    
     func didChangeAccessoryState(enabled: Bool)  {
        
    return cuckoo_manager.call("didChangeAccessoryState(enabled: Bool)",
            parameters: (enabled),
            escapingParameters: (enabled),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didChangeAccessoryState(enabled: enabled))
        
    }
    
    
    
     func didReceiveWrongPincode()  {
        
    return cuckoo_manager.call("didReceiveWrongPincode()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveWrongPincode())
        
    }
    

	 struct __StubbingProxy_PinSetupViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPinSetupViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPinSetupViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didRequestBiometryUsage<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(biometryType: M1, completionBlock: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(AvailableBiometryType, (Bool) -> Void)> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: biometryType) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupViewProtocol.self, method: "didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func didChangeAccessoryState<M1: Cuckoo.Matchable>(enabled: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool)> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: enabled) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupViewProtocol.self, method: "didChangeAccessoryState(enabled: Bool)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveWrongPincode() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupViewProtocol.self, method: "didReceiveWrongPincode()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didRequestBiometryUsage<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(biometryType: M1, completionBlock: M2) -> Cuckoo.__DoNotUse<(AvailableBiometryType, (Bool) -> Void), Void> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: biometryType) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return cuckoo_manager.verify("didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didChangeAccessoryState<M1: Cuckoo.Matchable>(enabled: M1) -> Cuckoo.__DoNotUse<(Bool), Void> where M1.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: enabled) { $0 }]
	        return cuckoo_manager.verify("didChangeAccessoryState(enabled: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveWrongPincode() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didReceiveWrongPincode()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupViewProtocolStub: PinSetupViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didChangeAccessoryState(enabled: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveWrongPincode()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupPresenterProtocol: PinSetupPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupPresenterProtocol
     typealias Verification = __VerificationProxy_PinSetupPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupPresenterProtocol?

     func enableDefaultImplementation(_ stub: PinSetupPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isChangeMode: Bool {
        get {
            return cuckoo_manager.getter("isChangeMode",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isChangeMode)
        }
        
    }
    

    

    
    
    
     func start()  {
        
    return cuckoo_manager.call("start()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.start())
        
    }
    
    
    
     func cancel()  {
        
    return cuckoo_manager.call("cancel()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cancel())
        
    }
    
    
    
     func activateBiometricAuth()  {
        
    return cuckoo_manager.call("activateBiometricAuth()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateBiometricAuth())
        
    }
    
    
    
     func submit(pin: String)  {
        
    return cuckoo_manager.call("submit(pin: String)",
            parameters: (pin),
            escapingParameters: (pin),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.submit(pin: pin))
        
    }
    

	 struct __StubbingProxy_PinSetupPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isChangeMode: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockPinSetupPresenterProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isChangeMode")
	    }
	    
	    
	    func start() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "start()", parameterMatchers: matchers))
	    }
	    
	    func cancel() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "cancel()", parameterMatchers: matchers))
	    }
	    
	    func activateBiometricAuth() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "activateBiometricAuth()", parameterMatchers: matchers))
	    }
	    
	    func submit<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupPresenterProtocol.self, method: "submit(pin: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isChangeMode: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isChangeMode", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func start() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("start()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cancel() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("cancel()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateBiometricAuth() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateBiometricAuth()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func submit<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return cuckoo_manager.verify("submit(pin: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupPresenterProtocolStub: PinSetupPresenterProtocol {
    
    
     var isChangeMode: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func start()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func cancel()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateBiometricAuth()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func submit(pin: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupInteractorInputProtocol: PinSetupInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupInteractorInputProtocol
     typealias Verification = __VerificationProxy_PinSetupInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: PinSetupInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func process(pin: String)  {
        
    return cuckoo_manager.call("process(pin: String)",
            parameters: (pin),
            escapingParameters: (pin),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.process(pin: pin))
        
    }
    
    
    
     func change(pin: String)  {
        
    return cuckoo_manager.call("change(pin: String)",
            parameters: (pin),
            escapingParameters: (pin),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.change(pin: pin))
        
    }
    

	 struct __StubbingProxy_PinSetupInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func process<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorInputProtocol.self, method: "process(pin: String)", parameterMatchers: matchers))
	    }
	    
	    func change<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorInputProtocol.self, method: "change(pin: String)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func process<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return cuckoo_manager.verify("process(pin: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func change<M1: Cuckoo.Matchable>(pin: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: pin) { $0 }]
	        return cuckoo_manager.verify("change(pin: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupInteractorInputProtocolStub: PinSetupInteractorInputProtocol {
    

    

    
     func process(pin: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func change(pin: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupInteractorOutputProtocol: PinSetupInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupInteractorOutputProtocol
     typealias Verification = __VerificationProxy_PinSetupInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: PinSetupInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didSavePin()  {
        
    return cuckoo_manager.call("didSavePin()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSavePin())
        
    }
    
    
    
     func didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)",
            parameters: (type, completionBlock),
            escapingParameters: (type, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartWaitingBiometryDecision(type: type, completionBlock: completionBlock))
        
    }
    
    
    
     func didChangeState(from: PinSetupInteractor.PinSetupState)  {
        
    return cuckoo_manager.call("didChangeState(from: PinSetupInteractor.PinSetupState)",
            parameters: (from),
            escapingParameters: (from),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didChangeState(from: from))
        
    }
    
    
    
     func didReceiveConfigError(_ error: Error)  {
        
    return cuckoo_manager.call("didReceiveConfigError(_: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveConfigError(error))
        
    }
    

	 struct __StubbingProxy_PinSetupInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didSavePin() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didSavePin()", parameterMatchers: matchers))
	    }
	    
	    func didStartWaitingBiometryDecision<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(type: M1, completionBlock: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(AvailableBiometryType, (Bool) -> Void)> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: type) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func didChangeState<M1: Cuckoo.Matchable>(from: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupInteractor.PinSetupState)> where M1.MatchedType == PinSetupInteractor.PinSetupState {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupInteractor.PinSetupState)>] = [wrap(matchable: from) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didChangeState(from: PinSetupInteractor.PinSetupState)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveConfigError<M1: Cuckoo.Matchable>(_ error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupInteractorOutputProtocol.self, method: "didReceiveConfigError(_: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didSavePin() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didSavePin()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStartWaitingBiometryDecision<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(type: M1, completionBlock: M2) -> Cuckoo.__DoNotUse<(AvailableBiometryType, (Bool) -> Void), Void> where M1.MatchedType == AvailableBiometryType, M2.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AvailableBiometryType, (Bool) -> Void)>] = [wrap(matchable: type) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return cuckoo_manager.verify("didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didChangeState<M1: Cuckoo.Matchable>(from: M1) -> Cuckoo.__DoNotUse<(PinSetupInteractor.PinSetupState), Void> where M1.MatchedType == PinSetupInteractor.PinSetupState {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupInteractor.PinSetupState)>] = [wrap(matchable: from) { $0 }]
	        return cuckoo_manager.verify("didChangeState(from: PinSetupInteractor.PinSetupState)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveConfigError<M1: Cuckoo.Matchable>(_ error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveConfigError(_: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupInteractorOutputProtocolStub: PinSetupInteractorOutputProtocol {
    

    

    
     func didSavePin()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didChangeState(from: PinSetupInteractor.PinSetupState)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveConfigError(_ error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockPinSetupWireframeProtocol: PinSetupWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = PinSetupWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_PinSetupWireframeProtocol
     typealias Verification = __VerificationProxy_PinSetupWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: PinSetupWireframeProtocol?

     func enableDefaultImplementation(_ stub: PinSetupWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func dismiss(from view: PinSetupViewProtocol?)  {
        
    return cuckoo_manager.call("dismiss(from: PinSetupViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.dismiss(from: view))
        
    }
    
    
    
     func showMain(from view: PinSetupViewProtocol?)  {
        
    return cuckoo_manager.call("showMain(from: PinSetupViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showMain(from: view))
        
    }
    
    
    
     func showSignup(from view: PinSetupViewProtocol?)  {
        
    return cuckoo_manager.call("showSignup(from: PinSetupViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSignup(from: view))
        
    }
    
    
    
     func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void)  {
        
    return cuckoo_manager.call("showPinUpdatedNotify(from: PinSetupViewProtocol?, completionBlock: @escaping () -> Void)",
            parameters: (view, completionBlock),
            escapingParameters: (view, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showPinUpdatedNotify(from: view, completionBlock: completionBlock))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    

	 struct __StubbingProxy_PinSetupWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func dismiss<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupViewProtocol?)> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "dismiss(from: PinSetupViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showMain<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupViewProtocol?)> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "showMain(from: PinSetupViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupViewProtocol?)> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "showSignup(from: PinSetupViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showPinUpdatedNotify<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, completionBlock: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(PinSetupViewProtocol?, () -> Void)> where M1.OptionalMatchedType == PinSetupViewProtocol, M2.MatchedType == () -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?, () -> Void)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "showPinUpdatedNotify(from: PinSetupViewProtocol?, completionBlock: @escaping () -> Void)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockPinSetupWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_PinSetupWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func dismiss<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(PinSetupViewProtocol?), Void> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("dismiss(from: PinSetupViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showMain<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(PinSetupViewProtocol?), Void> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showMain(from: PinSetupViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(PinSetupViewProtocol?), Void> where M1.OptionalMatchedType == PinSetupViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showSignup(from: PinSetupViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showPinUpdatedNotify<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, completionBlock: M2) -> Cuckoo.__DoNotUse<(PinSetupViewProtocol?, () -> Void), Void> where M1.OptionalMatchedType == PinSetupViewProtocol, M2.MatchedType == () -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(PinSetupViewProtocol?, () -> Void)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return cuckoo_manager.verify("showPinUpdatedNotify(from: PinSetupViewProtocol?, completionBlock: @escaping () -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class PinSetupWireframeProtocolStub: PinSetupWireframeProtocol {
    

    

    
     func dismiss(from view: PinSetupViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showMain(from view: PinSetupViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showSignup(from view: PinSetupViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import Foundation


 class MockProfileViewProtocol: ProfileViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileViewProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileViewProtocol
     typealias Verification = __VerificationProxy_ProfileViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileViewProtocol?

     func enableDefaultImplementation(_ stub: ProfileViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])  {
        
    return cuckoo_manager.call("didLoad(optionViewModels: [ProfileOptionViewModelProtocol])",
            parameters: (optionViewModels),
            escapingParameters: (optionViewModels),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didLoad(optionViewModels: optionViewModels))
        
    }
    

	 struct __StubbingProxy_ProfileViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockProfileViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockProfileViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didLoad<M1: Cuckoo.Matchable>(optionViewModels: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ProfileOptionViewModelProtocol])> where M1.MatchedType == [ProfileOptionViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([ProfileOptionViewModelProtocol])>] = [wrap(matchable: optionViewModels) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileViewProtocol.self, method: "didLoad(optionViewModels: [ProfileOptionViewModelProtocol])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didLoad<M1: Cuckoo.Matchable>(optionViewModels: M1) -> Cuckoo.__DoNotUse<([ProfileOptionViewModelProtocol]), Void> where M1.MatchedType == [ProfileOptionViewModelProtocol] {
	        let matchers: [Cuckoo.ParameterMatcher<([ProfileOptionViewModelProtocol])>] = [wrap(matchable: optionViewModels) { $0 }]
	        return cuckoo_manager.verify("didLoad(optionViewModels: [ProfileOptionViewModelProtocol])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileViewProtocolStub: ProfileViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfilePresenterProtocol: ProfilePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfilePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_ProfilePresenterProtocol
     typealias Verification = __VerificationProxy_ProfilePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfilePresenterProtocol?

     func enableDefaultImplementation(_ stub: ProfilePresenterProtocol) {
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
    
    
    
     func activateOption(at index: UInt)  {
        
    return cuckoo_manager.call("activateOption(at: UInt)",
            parameters: (index),
            escapingParameters: (index),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateOption(at: index))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_ProfilePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func activateOption<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UInt)> where M1.MatchedType == UInt {
	        let matchers: [Cuckoo.ParameterMatcher<(UInt)>] = [wrap(matchable: index) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "activateOption(at: UInt)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfilePresenterProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfilePresenterProtocol: Cuckoo.VerificationProxy {
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
	    func activateOption<M1: Cuckoo.Matchable>(at index: M1) -> Cuckoo.__DoNotUse<(UInt), Void> where M1.MatchedType == UInt {
	        let matchers: [Cuckoo.ParameterMatcher<(UInt)>] = [wrap(matchable: index) { $0 }]
	        return cuckoo_manager.verify("activateOption(at: UInt)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfilePresenterProtocolStub: ProfilePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateOption(at index: UInt)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfileInteractorInputProtocol: ProfileInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileInteractorInputProtocol
     typealias Verification = __VerificationProxy_ProfileInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: ProfileInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func logoutAndClean()  {
        
    return cuckoo_manager.call("logoutAndClean()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.logoutAndClean())
        
    }
    

	 struct __StubbingProxy_ProfileInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func logoutAndClean() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileInteractorInputProtocol.self, method: "logoutAndClean()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func logoutAndClean() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("logoutAndClean()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileInteractorInputProtocolStub: ProfileInteractorInputProtocol {
    

    

    
     func logoutAndClean()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfileInteractorOutputProtocol: ProfileInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileInteractorOutputProtocol
     typealias Verification = __VerificationProxy_ProfileInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: ProfileInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func restart()  {
        
    return cuckoo_manager.call("restart()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.restart())
        
    }
    

	 struct __StubbingProxy_ProfileInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func restart() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileInteractorOutputProtocol.self, method: "restart()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func restart() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("restart()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileInteractorOutputProtocolStub: ProfileInteractorOutputProtocol {
    

    

    
     func restart()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockProfileWireframeProtocol: ProfileWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ProfileWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_ProfileWireframeProtocol
     typealias Verification = __VerificationProxy_ProfileWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ProfileWireframeProtocol?

     func enableDefaultImplementation(_ stub: ProfileWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showPersonalDetailsView(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showPersonalDetailsView(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showPersonalDetailsView(from: view))
        
    }
    
    
    
     func showFriendsView(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showFriendsView(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showFriendsView(from: view))
        
    }
    
    
    
     func showPassphraseView(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showPassphraseView(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showPassphraseView(from: view))
        
    }
    
    
    
     func showChangePin(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showChangePin(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showChangePin(from: view))
        
    }
    
    
    
     func showLanguageSelection(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showLanguageSelection(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showLanguageSelection(from: view))
        
    }
    
    
    
     func showFaq(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showFaq(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showFaq(from: view))
        
    }
    
    
    
     func showAbout(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showAbout(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAbout(from: view))
        
    }
    
    
    
     func showDisclaimer(from view: ProfileViewProtocol?)  {
        
    return cuckoo_manager.call("showDisclaimer(from: ProfileViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showDisclaimer(from: view))
        
    }
    
    
    
     func showLogout(from view: ProfileViewProtocol?, completionBlock: (() -> Void)?)  {
        
    return cuckoo_manager.call("showLogout(from: ProfileViewProtocol?, completionBlock: (() -> Void)?)",
            parameters: (view, completionBlock),
            escapingParameters: (view, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showLogout(from: view, completionBlock: completionBlock))
        
    }
    
    
    
     func switchBiometry(toValue: Bool, from view: ProfileViewProtocol?, successBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("switchBiometry(toValue: Bool, from: ProfileViewProtocol?, successBlock: @escaping (Bool) -> Void)",
            parameters: (toValue, view, successBlock),
            escapingParameters: (toValue, view, successBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.switchBiometry(toValue: toValue, from: view, successBlock: successBlock))
        
    }
    
    
    
     func showRoot()  {
        
    return cuckoo_manager.call("showRoot()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showRoot())
        
    }
    
    
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool",
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    

	 struct __StubbingProxy_ProfileWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showPersonalDetailsView<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showPersonalDetailsView(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showFriendsView<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showFriendsView(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showPassphraseView<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showPassphraseView(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showChangePin<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showChangePin(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showLanguageSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showLanguageSelection(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showFaq<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showFaq(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAbout<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showAbout(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showDisclaimer<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?)> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showDisclaimer(from: ProfileViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showLogout<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable>(from view: M1, completionBlock: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ProfileViewProtocol?, (() -> Void)?)> where M1.OptionalMatchedType == ProfileViewProtocol, M2.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?, (() -> Void)?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showLogout(from: ProfileViewProtocol?, completionBlock: (() -> Void)?)", parameterMatchers: matchers))
	    }
	    
	    func switchBiometry<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(toValue: M1, from view: M2, successBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool, ProfileViewProtocol?, (Bool) -> Void)> where M1.MatchedType == Bool, M2.OptionalMatchedType == ProfileViewProtocol, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool, ProfileViewProtocol?, (Bool) -> Void)>] = [wrap(matchable: toValue) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: successBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "switchBiometry(toValue: Bool, from: ProfileViewProtocol?, successBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func showRoot() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showRoot()", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockProfileWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ProfileWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showPersonalDetailsView<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showPersonalDetailsView(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showFriendsView<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showFriendsView(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showPassphraseView<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showPassphraseView(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showChangePin<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showChangePin(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showLanguageSelection<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showLanguageSelection(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showFaq<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showFaq(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAbout<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAbout(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showDisclaimer<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?), Void> where M1.OptionalMatchedType == ProfileViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showDisclaimer(from: ProfileViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showLogout<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable>(from view: M1, completionBlock: M2) -> Cuckoo.__DoNotUse<(ProfileViewProtocol?, (() -> Void)?), Void> where M1.OptionalMatchedType == ProfileViewProtocol, M2.OptionalMatchedType == (() -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(ProfileViewProtocol?, (() -> Void)?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: completionBlock) { $0.1 }]
	        return cuckoo_manager.verify("showLogout(from: ProfileViewProtocol?, completionBlock: (() -> Void)?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func switchBiometry<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(toValue: M1, from view: M2, successBlock: M3) -> Cuckoo.__DoNotUse<(Bool, ProfileViewProtocol?, (Bool) -> Void), Void> where M1.MatchedType == Bool, M2.OptionalMatchedType == ProfileViewProtocol, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(Bool, ProfileViewProtocol?, (Bool) -> Void)>] = [wrap(matchable: toValue) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: successBlock) { $0.2 }]
	        return cuckoo_manager.verify("switchBiometry(toValue: Bool, from: ProfileViewProtocol?, successBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showRoot() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("showRoot()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
	        return cuckoo_manager.verify("present(error: Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ProfileWireframeProtocolStub: ProfileWireframeProtocol {
    

    

    
     func showPersonalDetailsView(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showFriendsView(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showPassphraseView(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showChangePin(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showLanguageSelection(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showFaq(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAbout(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showDisclaimer(from view: ProfileViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showLogout(from view: ProfileViewProtocol?, completionBlock: (() -> Void)?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func switchBiometry(toValue: Bool, from view: ProfileViewProtocol?, successBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showRoot()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockRootPresenterProtocol: RootPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_RootPresenterProtocol
     typealias Verification = __VerificationProxy_RootPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootPresenterProtocol?

     func enableDefaultImplementation(_ stub: RootPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func loadOnLaunch()  {
        
    return cuckoo_manager.call("loadOnLaunch()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.loadOnLaunch())
        
    }
    

	 struct __StubbingProxy_RootPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func loadOnLaunch() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootPresenterProtocol.self, method: "loadOnLaunch()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func loadOnLaunch() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("loadOnLaunch()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootPresenterProtocolStub: RootPresenterProtocol {
    

    

    
     func loadOnLaunch()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRootWireframeProtocol: RootWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_RootWireframeProtocol
     typealias Verification = __VerificationProxy_RootWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootWireframeProtocol?

     func enableDefaultImplementation(_ stub: RootWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showLocalAuthentication(on view: UIWindow)  {
        
    return cuckoo_manager.call("showLocalAuthentication(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showLocalAuthentication(on: view))
        
    }
    
    
    
     func showOnboarding(on view: UIWindow)  {
        
    return cuckoo_manager.call("showOnboarding(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showOnboarding(on: view))
        
    }
    
    
    
     func showBroken(on view: UIWindow)  {
        
    return cuckoo_manager.call("showBroken(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showBroken(on: view))
        
    }
    
    
    
     func showPincodeSetup(on view: UIWindow)  {
        
    return cuckoo_manager.call("showPincodeSetup(on: UIWindow)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showPincodeSetup(on: view))
        
    }
    

	 struct __StubbingProxy_RootWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showLocalAuthentication<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showLocalAuthentication(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	    func showOnboarding<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showOnboarding(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	    func showBroken<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showBroken(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	    func showPincodeSetup<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UIWindow)> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRootWireframeProtocol.self, method: "showPincodeSetup(on: UIWindow)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showLocalAuthentication<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showLocalAuthentication(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showOnboarding<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showOnboarding(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showBroken<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showBroken(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showPincodeSetup<M1: Cuckoo.Matchable>(on view: M1) -> Cuckoo.__DoNotUse<(UIWindow), Void> where M1.MatchedType == UIWindow {
	        let matchers: [Cuckoo.ParameterMatcher<(UIWindow)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showPincodeSetup(on: UIWindow)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootWireframeProtocolStub: RootWireframeProtocol {
    

    

    
     func showLocalAuthentication(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showOnboarding(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showBroken(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showPincodeSetup(on view: UIWindow)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRootInteractorInputProtocol: RootInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_RootInteractorInputProtocol
     typealias Verification = __VerificationProxy_RootInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: RootInteractorInputProtocol) {
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
    
    
    
     func decideModuleSynchroniously()  {
        
    return cuckoo_manager.call("decideModuleSynchroniously()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.decideModuleSynchroniously())
        
    }
    

	 struct __StubbingProxy_RootInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func decideModuleSynchroniously() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorInputProtocol.self, method: "decideModuleSynchroniously()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    func decideModuleSynchroniously() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("decideModuleSynchroniously()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootInteractorInputProtocolStub: RootInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func decideModuleSynchroniously()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockRootInteractorOutputProtocol: RootInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RootInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_RootInteractorOutputProtocol
     typealias Verification = __VerificationProxy_RootInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RootInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: RootInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didDecideOnboarding()  {
        
    return cuckoo_manager.call("didDecideOnboarding()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideOnboarding())
        
    }
    
    
    
     func didDecideLocalAuthentication()  {
        
    return cuckoo_manager.call("didDecideLocalAuthentication()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideLocalAuthentication())
        
    }
    
    
    
     func didDecideBroken()  {
        
    return cuckoo_manager.call("didDecideBroken()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideBroken())
        
    }
    
    
    
     func didDecidePincodeSetup()  {
        
    return cuckoo_manager.call("didDecidePincodeSetup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecidePincodeSetup())
        
    }
    

	 struct __StubbingProxy_RootInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didDecideOnboarding() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecideOnboarding()", parameterMatchers: matchers))
	    }
	    
	    func didDecideLocalAuthentication() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecideLocalAuthentication()", parameterMatchers: matchers))
	    }
	    
	    func didDecideBroken() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecideBroken()", parameterMatchers: matchers))
	    }
	    
	    func didDecidePincodeSetup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRootInteractorOutputProtocol.self, method: "didDecidePincodeSetup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RootInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didDecideOnboarding() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideOnboarding()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideLocalAuthentication() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideLocalAuthentication()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideBroken() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideBroken()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecidePincodeSetup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecidePincodeSetup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RootInteractorOutputProtocolStub: RootInteractorOutputProtocol {
    

    

    
     func didDecideOnboarding()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideLocalAuthentication()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideBroken()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecidePincodeSetup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockSecurityLayerInteractorInputProtocol: SecurityLayerInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SecurityLayerInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_SecurityLayerInteractorInputProtocol
     typealias Verification = __VerificationProxy_SecurityLayerInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecurityLayerInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: SecurityLayerInteractorInputProtocol) {
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
    

	 struct __StubbingProxy_SecurityLayerInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SecurityLayerInteractorInputProtocol: Cuckoo.VerificationProxy {
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
	    
	}
}

 class SecurityLayerInteractorInputProtocolStub: SecurityLayerInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockSecurityLayerInteractorOutputProtocol: SecurityLayerInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SecurityLayerInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_SecurityLayerInteractorOutputProtocol
     typealias Verification = __VerificationProxy_SecurityLayerInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecurityLayerInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: SecurityLayerInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didDecideSecurePresentation()  {
        
    return cuckoo_manager.call("didDecideSecurePresentation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideSecurePresentation())
        
    }
    
    
    
     func didDecideUnsecurePresentation()  {
        
    return cuckoo_manager.call("didDecideUnsecurePresentation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideUnsecurePresentation())
        
    }
    
    
    
     func didDecideRequestAuthorization()  {
        
    return cuckoo_manager.call("didDecideRequestAuthorization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didDecideRequestAuthorization())
        
    }
    

	 struct __StubbingProxy_SecurityLayerInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didDecideSecurePresentation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerInteractorOutputProtocol.self, method: "didDecideSecurePresentation()", parameterMatchers: matchers))
	    }
	    
	    func didDecideUnsecurePresentation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerInteractorOutputProtocol.self, method: "didDecideUnsecurePresentation()", parameterMatchers: matchers))
	    }
	    
	    func didDecideRequestAuthorization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerInteractorOutputProtocol.self, method: "didDecideRequestAuthorization()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SecurityLayerInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didDecideSecurePresentation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideSecurePresentation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideUnsecurePresentation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideUnsecurePresentation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didDecideRequestAuthorization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didDecideRequestAuthorization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SecurityLayerInteractorOutputProtocolStub: SecurityLayerInteractorOutputProtocol {
    

    

    
     func didDecideSecurePresentation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideUnsecurePresentation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didDecideRequestAuthorization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockSecurityLayerWireframProtocol: SecurityLayerWireframProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SecurityLayerWireframProtocol
    
     typealias Stubbing = __StubbingProxy_SecurityLayerWireframProtocol
     typealias Verification = __VerificationProxy_SecurityLayerWireframProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecurityLayerWireframProtocol?

     func enableDefaultImplementation(_ stub: SecurityLayerWireframProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showSecuringOverlay()  {
        
    return cuckoo_manager.call("showSecuringOverlay()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSecuringOverlay())
        
    }
    
    
    
     func hideSecuringOverlay()  {
        
    return cuckoo_manager.call("hideSecuringOverlay()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.hideSecuringOverlay())
        
    }
    
    
    
     func showAuthorization()  {
        
    return cuckoo_manager.call("showAuthorization()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAuthorization())
        
    }
    

	 struct __StubbingProxy_SecurityLayerWireframProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showSecuringOverlay() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerWireframProtocol.self, method: "showSecuringOverlay()", parameterMatchers: matchers))
	    }
	    
	    func hideSecuringOverlay() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerWireframProtocol.self, method: "hideSecuringOverlay()", parameterMatchers: matchers))
	    }
	    
	    func showAuthorization() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecurityLayerWireframProtocol.self, method: "showAuthorization()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SecurityLayerWireframProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showSecuringOverlay() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("showSecuringOverlay()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func hideSecuringOverlay() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("hideSecuringOverlay()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAuthorization() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("showAuthorization()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SecurityLayerWireframProtocolStub: SecurityLayerWireframProtocol {
    

    

    
     func showSecuringOverlay()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func hideSecuringOverlay()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAuthorization()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import SoraPassport

import UIKit


 class MockUnsupportedVersionViewProtocol: UnsupportedVersionViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UnsupportedVersionViewProtocol
    
     typealias Stubbing = __StubbingProxy_UnsupportedVersionViewProtocol
     typealias Verification = __VerificationProxy_UnsupportedVersionViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UnsupportedVersionViewProtocol?

     func enableDefaultImplementation(_ stub: UnsupportedVersionViewProtocol) {
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
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func didReceive(viewModel: UnsupportedVersionViewModel)  {
        
    return cuckoo_manager.call("didReceive(viewModel: UnsupportedVersionViewModel)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(viewModel: viewModel))
        
    }
    

	 struct __StubbingProxy_UnsupportedVersionViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockUnsupportedVersionViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockUnsupportedVersionViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(UnsupportedVersionViewModel)> where M1.MatchedType == UnsupportedVersionViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(UnsupportedVersionViewModel)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUnsupportedVersionViewProtocol.self, method: "didReceive(viewModel: UnsupportedVersionViewModel)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UnsupportedVersionViewProtocol: Cuckoo.VerificationProxy {
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
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(UnsupportedVersionViewModel), Void> where M1.MatchedType == UnsupportedVersionViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(UnsupportedVersionViewModel)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("didReceive(viewModel: UnsupportedVersionViewModel)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UnsupportedVersionViewProtocolStub: UnsupportedVersionViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func didReceive(viewModel: UnsupportedVersionViewModel)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUnsupportedVersionPresenterProtocol: UnsupportedVersionPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UnsupportedVersionPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_UnsupportedVersionPresenterProtocol
     typealias Verification = __VerificationProxy_UnsupportedVersionPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UnsupportedVersionPresenterProtocol?

     func enableDefaultImplementation(_ stub: UnsupportedVersionPresenterProtocol) {
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
    
    
    
     func performAction()  {
        
    return cuckoo_manager.call("performAction()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.performAction())
        
    }
    

	 struct __StubbingProxy_UnsupportedVersionPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUnsupportedVersionPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func performAction() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUnsupportedVersionPresenterProtocol.self, method: "performAction()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UnsupportedVersionPresenterProtocol: Cuckoo.VerificationProxy {
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
	    func performAction() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("performAction()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UnsupportedVersionPresenterProtocolStub: UnsupportedVersionPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func performAction()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUnsupportedVersionInteractorInputProtocol: UnsupportedVersionInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UnsupportedVersionInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_UnsupportedVersionInteractorInputProtocol
     typealias Verification = __VerificationProxy_UnsupportedVersionInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UnsupportedVersionInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: UnsupportedVersionInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    

	 struct __StubbingProxy_UnsupportedVersionInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	}

	 struct __VerificationProxy_UnsupportedVersionInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	}
}

 class UnsupportedVersionInteractorInputProtocolStub: UnsupportedVersionInteractorInputProtocol {
    

    

    
}



 class MockUnsupportedVersionInteractorOutputProtocol: UnsupportedVersionInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UnsupportedVersionInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_UnsupportedVersionInteractorOutputProtocol
     typealias Verification = __VerificationProxy_UnsupportedVersionInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UnsupportedVersionInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: UnsupportedVersionInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    

	 struct __StubbingProxy_UnsupportedVersionInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	}

	 struct __VerificationProxy_UnsupportedVersionInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	}
}

 class UnsupportedVersionInteractorOutputProtocolStub: UnsupportedVersionInteractorOutputProtocol {
    

    

    
}



 class MockUnsupportedVersionWireframeProtocol: UnsupportedVersionWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UnsupportedVersionWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_UnsupportedVersionWireframeProtocol
     typealias Verification = __VerificationProxy_UnsupportedVersionWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UnsupportedVersionWireframeProtocol?

     func enableDefaultImplementation(_ stub: UnsupportedVersionWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_UnsupportedVersionWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUnsupportedVersionWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUnsupportedVersionWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UnsupportedVersionWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UnsupportedVersionWireframeProtocolStub: UnsupportedVersionWireframeProtocol {
    

    

    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}

