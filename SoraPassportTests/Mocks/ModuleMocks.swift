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
        
    return cuckoo_manager.call(
    """
    reloadEmptyState(animated: Bool)
    """,
            parameters: (animated),
            escapingParameters: (animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reloadEmptyState(animated: animated))
        
    }
    
    
    
    
    
    public func updateEmptyState(animated: Bool)  {
        
    return cuckoo_manager.call(
    """
    updateEmptyState(animated: Bool)
    """,
            parameters: (animated),
            escapingParameters: (animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateEmptyState(animated: animated))
        
    }
    
    
    
    
    
    public func updateEmptyStateInsets()  {
        
    return cuckoo_manager.call(
    """
    updateEmptyStateInsets()
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockEmptyStateViewOwnerProtocol.self, method:
    """
    reloadEmptyState(animated: Bool)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func updateEmptyState<M1: Cuckoo.Matchable>(animated: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Bool)> where M1.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: animated) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEmptyStateViewOwnerProtocol.self, method:
    """
    updateEmptyState(animated: Bool)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func updateEmptyStateInsets() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockEmptyStateViewOwnerProtocol.self, method:
    """
    updateEmptyStateInsets()
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    reloadEmptyState(animated: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func updateEmptyState<M1: Cuckoo.Matchable>(animated: M1) -> Cuckoo.__DoNotUse<(Bool), Void> where M1.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(Bool)>] = [wrap(matchable: animated) { $0 }]
            return cuckoo_manager.verify(
    """
    updateEmptyState(animated: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func updateEmptyStateInsets() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    updateEmptyStateInsets()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    navigate(to: InvitationDeepLink) -> Bool
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockDeepLinkNavigatorProtocol.self, method:
    """
    navigate(to: InvitationDeepLink) -> Bool
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    navigate(to: InvitationDeepLink) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    accept(navigator: DeepLinkNavigatorProtocol) -> Bool
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockDeepLinkProtocol.self, method:
    """
    accept(navigator: DeepLinkNavigatorProtocol) -> Bool
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    accept(navigator: DeepLinkNavigatorProtocol) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    handle(url: URL) -> Bool
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockDeepLinkServiceProtocol.self, method:
    """
    handle(url: URL) -> Bool
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    handle(url: URL) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    didUpdateInvitationLink(from: InvitationDeepLink?)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkObserver.self, method:
    """
    didUpdateInvitationLink(from: InvitationDeepLink?)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    didUpdateInvitationLink(from: InvitationDeepLink?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    add(observer: InvitationLinkObserver)
    """,
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer))
        
    }
    
    
    
    
    
     func remove(observer: InvitationLinkObserver)  {
        
    return cuckoo_manager.call(
    """
    remove(observer: InvitationLinkObserver)
    """,
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(observer: observer))
        
    }
    
    
    
    
    
     func save(code: String)  {
        
    return cuckoo_manager.call(
    """
    save(code: String)
    """,
            parameters: (code),
            escapingParameters: (code),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.save(code: code))
        
    }
    
    
    
    
    
     func clear()  {
        
    return cuckoo_manager.call(
    """
    clear()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.clear())
        
    }
    
    
    
    
    
     func handle(url: URL) -> Bool {
        
    return cuckoo_manager.call(
    """
    handle(url: URL) -> Bool
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method:
    """
    add(observer: InvitationLinkObserver)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationLinkObserver)> where M1.MatchedType == InvitationLinkObserver {
            let matchers: [Cuckoo.ParameterMatcher<(InvitationLinkObserver)>] = [wrap(matchable: observer) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method:
    """
    remove(observer: InvitationLinkObserver)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func save<M1: Cuckoo.Matchable>(code: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: code) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method:
    """
    save(code: String)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func clear() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method:
    """
    clear()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func handle<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.ProtocolStubFunction<(URL), Bool> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockInvitationLinkServiceProtocol.self, method:
    """
    handle(url: URL) -> Bool
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    add(observer: InvitationLinkObserver)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(InvitationLinkObserver), Void> where M1.MatchedType == InvitationLinkObserver {
            let matchers: [Cuckoo.ParameterMatcher<(InvitationLinkObserver)>] = [wrap(matchable: observer) { $0 }]
            return cuckoo_manager.verify(
    """
    remove(observer: InvitationLinkObserver)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func save<M1: Cuckoo.Matchable>(code: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: code) { $0 }]
            return cuckoo_manager.verify(
    """
    save(code: String)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func clear() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    clear()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func handle<M1: Cuckoo.Matchable>(url: M1) -> Cuckoo.__DoNotUse<(URL), Bool> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
            return cuckoo_manager.verify(
    """
    handle(url: URL) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    accept(visitor: EventVisitorProtocol)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockEventProtocol.self, method:
    """
    accept(visitor: EventVisitorProtocol)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    accept(visitor: EventVisitorProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    notify(with: EventProtocol)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notify(with: event))
        
    }
    
    
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)  {
        
    return cuckoo_manager.call(
    """
    add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)
    """,
            parameters: (observer, queue),
            escapingParameters: (observer, queue),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer, dispatchIn: queue))
        
    }
    
    
    
    
    
     func remove(observer: EventVisitorProtocol)  {
        
    return cuckoo_manager.call(
    """
    remove(observer: EventVisitorProtocol)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method:
    """
    notify(with: EventProtocol)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol, DispatchQueue?)> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method:
    """
    add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method:
    """
    remove(observer: EventVisitorProtocol)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    notify(with: EventProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.__DoNotUse<(EventVisitorProtocol, DispatchQueue?), Void> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
            return cuckoo_manager.verify(
    """
    add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
            return cuckoo_manager.verify(
    """
    remove(observer: EventVisitorProtocol)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    processProjectVote(event: ProjectVoteEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processProjectVote(event: event))
        
    }
    
    
    
    
    
     func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)  {
        
    return cuckoo_manager.call(
    """
    processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processProjectFavoriteToggle(event: event))
        
    }
    
    
    
    
    
     func processProjectView(event: ProjectViewEvent)  {
        
    return cuckoo_manager.call(
    """
    processProjectView(event: ProjectViewEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processProjectView(event: event))
        
    }
    
    
    
    
    
     func processInvitationInput(event: InvitationInputEvent)  {
        
    return cuckoo_manager.call(
    """
    processInvitationInput(event: InvitationInputEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processInvitationInput(event: event))
        
    }
    
    
    
    
    
     func processInvitationApplied(event: InvitationAppliedEvent)  {
        
    return cuckoo_manager.call(
    """
    processInvitationApplied(event: InvitationAppliedEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processInvitationApplied(event: event))
        
    }
    
    
    
    
    
     func processWalletUpdate(event: WalletUpdateEvent)  {
        
    return cuckoo_manager.call(
    """
    processWalletUpdate(event: WalletUpdateEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processWalletUpdate(event: event))
        
    }
    
    
    
    
    
     func processReferendumVote(event: ReferendumVoteEvent)  {
        
    return cuckoo_manager.call(
    """
    processReferendumVote(event: ReferendumVoteEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processReferendumVote(event: event))
        
    }
    
    
    
    
    
     func processSelectedAccountChanged(event: SelectedAccountChanged)  {
        
    return cuckoo_manager.call(
    """
    processSelectedAccountChanged(event: SelectedAccountChanged)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSelectedAccountChanged(event: event))
        
    }
    
    
    
    
    
     func processSelectedUsernameChanged(event: SelectedUsernameChanged)  {
        
    return cuckoo_manager.call(
    """
    processSelectedUsernameChanged(event: SelectedUsernameChanged)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSelectedUsernameChanged(event: event))
        
    }
    
    
    
    
    
     func processBalanceChanged(event: WalletBalanceChanged)  {
        
    return cuckoo_manager.call(
    """
    processBalanceChanged(event: WalletBalanceChanged)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processBalanceChanged(event: event))
        
    }
    
    
    
    
    
     func processStakingChanged(event: WalletStakingInfoChanged)  {
        
    return cuckoo_manager.call(
    """
    processStakingChanged(event: WalletStakingInfoChanged)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processStakingChanged(event: event))
        
    }
    
    
    
    
    
     func processNewTransaction(event: WalletNewTransactionInserted)  {
        
    return cuckoo_manager.call(
    """
    processNewTransaction(event: WalletNewTransactionInserted)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processNewTransaction(event: event))
        
    }
    
    
    
    
    
     func processNewTransactionCreated(event: NewTransactionCreatedEvent)  {
        
    return cuckoo_manager.call(
    """
    processNewTransactionCreated(event: NewTransactionCreatedEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processNewTransactionCreated(event: event))
        
    }
    
    
    
    
    
     func processTypeRegistryPrepared(event: TypeRegistryPrepared)  {
        
    return cuckoo_manager.call(
    """
    processTypeRegistryPrepared(event: TypeRegistryPrepared)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processTypeRegistryPrepared(event: event))
        
    }
    
    
    
    
    
     func processMigration(event: MigrationEvent)  {
        
    return cuckoo_manager.call(
    """
    processMigration(event: MigrationEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processMigration(event: event))
        
    }
    
    
    
    
    
     func processSuccsessMigration(event: MigrationSuccsessEvent)  {
        
    return cuckoo_manager.call(
    """
    processSuccsessMigration(event: MigrationSuccsessEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processSuccsessMigration(event: event))
        
    }
    
    
    
    
    
     func processChainSyncDidStart(event: ChainSyncDidStart)  {
        
    return cuckoo_manager.call(
    """
    processChainSyncDidStart(event: ChainSyncDidStart)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processChainSyncDidStart(event: event))
        
    }
    
    
    
    
    
     func processChainSyncDidComplete(event: ChainSyncDidComplete)  {
        
    return cuckoo_manager.call(
    """
    processChainSyncDidComplete(event: ChainSyncDidComplete)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processChainSyncDidComplete(event: event))
        
    }
    
    
    
    
    
     func processChainSyncDidFail(event: ChainSyncDidFail)  {
        
    return cuckoo_manager.call(
    """
    processChainSyncDidFail(event: ChainSyncDidFail)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processChainSyncDidFail(event: event))
        
    }
    
    
    
    
    
     func processChainsUpdated(event: ChainsUpdatedEvent)  {
        
    return cuckoo_manager.call(
    """
    processChainsUpdated(event: ChainsUpdatedEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processChainsUpdated(event: event))
        
    }
    
    
    
    
    
     func processFailedNodeConnection(event: FailedNodeConnectionEvent)  {
        
    return cuckoo_manager.call(
    """
    processFailedNodeConnection(event: FailedNodeConnectionEvent)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processFailedNodeConnection(event: event))
        
    }
    
    
    
    
    
     func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)  {
        
    return cuckoo_manager.call(
    """
    processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processRuntimeCommonTypesSyncCompleted(event: event))
        
    }
    
    
    
    
    
     func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)  {
        
    return cuckoo_manager.call(
    """
    processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processRuntimeChainTypesSyncCompleted(event: event))
        
    }
    
    
    
    
    
     func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)  {
        
    return cuckoo_manager.call(
    """
    processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processRuntimeChainMetadataSyncCompleted(event: event))
        
    }
    
    
    
    
    
     func processRuntimeCoderReady(event: RuntimeCoderCreated)  {
        
    return cuckoo_manager.call(
    """
    processRuntimeCoderReady(event: RuntimeCoderCreated)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processRuntimeCoderReady(event: event))
        
    }
    
    
    
    
    
     func processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)  {
        
    return cuckoo_manager.call(
    """
    processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)
    """,
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.processRuntimeCoderCreationFailed(event: event))
        
    }
    
    

     struct __StubbingProxy_EventVisitorProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func processProjectVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProjectVoteEvent)> where M1.MatchedType == ProjectVoteEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ProjectVoteEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processProjectVote(event: ProjectVoteEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processProjectFavoriteToggle<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProjectFavoriteToggleEvent)> where M1.MatchedType == ProjectFavoriteToggleEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ProjectFavoriteToggleEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processProjectView<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ProjectViewEvent)> where M1.MatchedType == ProjectViewEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ProjectViewEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processProjectView(event: ProjectViewEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processInvitationInput<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationInputEvent)> where M1.MatchedType == InvitationInputEvent {
            let matchers: [Cuckoo.ParameterMatcher<(InvitationInputEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processInvitationInput(event: InvitationInputEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processInvitationApplied<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InvitationAppliedEvent)> where M1.MatchedType == InvitationAppliedEvent {
            let matchers: [Cuckoo.ParameterMatcher<(InvitationAppliedEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processInvitationApplied(event: InvitationAppliedEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processWalletUpdate<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletUpdateEvent)> where M1.MatchedType == WalletUpdateEvent {
            let matchers: [Cuckoo.ParameterMatcher<(WalletUpdateEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processWalletUpdate(event: WalletUpdateEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processReferendumVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ReferendumVoteEvent)> where M1.MatchedType == ReferendumVoteEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ReferendumVoteEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processReferendumVote(event: ReferendumVoteEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processSelectedAccountChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedAccountChanged)> where M1.MatchedType == SelectedAccountChanged {
            let matchers: [Cuckoo.ParameterMatcher<(SelectedAccountChanged)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processSelectedAccountChanged(event: SelectedAccountChanged)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processSelectedUsernameChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SelectedUsernameChanged)> where M1.MatchedType == SelectedUsernameChanged {
            let matchers: [Cuckoo.ParameterMatcher<(SelectedUsernameChanged)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processSelectedUsernameChanged(event: SelectedUsernameChanged)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processBalanceChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletBalanceChanged)> where M1.MatchedType == WalletBalanceChanged {
            let matchers: [Cuckoo.ParameterMatcher<(WalletBalanceChanged)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processBalanceChanged(event: WalletBalanceChanged)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processStakingChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletStakingInfoChanged)> where M1.MatchedType == WalletStakingInfoChanged {
            let matchers: [Cuckoo.ParameterMatcher<(WalletStakingInfoChanged)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processStakingChanged(event: WalletStakingInfoChanged)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processNewTransaction<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(WalletNewTransactionInserted)> where M1.MatchedType == WalletNewTransactionInserted {
            let matchers: [Cuckoo.ParameterMatcher<(WalletNewTransactionInserted)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processNewTransaction(event: WalletNewTransactionInserted)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processNewTransactionCreated<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(NewTransactionCreatedEvent)> where M1.MatchedType == NewTransactionCreatedEvent {
            let matchers: [Cuckoo.ParameterMatcher<(NewTransactionCreatedEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processNewTransactionCreated(event: NewTransactionCreatedEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processTypeRegistryPrepared<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TypeRegistryPrepared)> where M1.MatchedType == TypeRegistryPrepared {
            let matchers: [Cuckoo.ParameterMatcher<(TypeRegistryPrepared)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processTypeRegistryPrepared(event: TypeRegistryPrepared)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MigrationEvent)> where M1.MatchedType == MigrationEvent {
            let matchers: [Cuckoo.ParameterMatcher<(MigrationEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processMigration(event: MigrationEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processSuccsessMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(MigrationSuccsessEvent)> where M1.MatchedType == MigrationSuccsessEvent {
            let matchers: [Cuckoo.ParameterMatcher<(MigrationSuccsessEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processSuccsessMigration(event: MigrationSuccsessEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processChainSyncDidStart<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainSyncDidStart)> where M1.MatchedType == ChainSyncDidStart {
            let matchers: [Cuckoo.ParameterMatcher<(ChainSyncDidStart)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processChainSyncDidStart(event: ChainSyncDidStart)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processChainSyncDidComplete<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainSyncDidComplete)> where M1.MatchedType == ChainSyncDidComplete {
            let matchers: [Cuckoo.ParameterMatcher<(ChainSyncDidComplete)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processChainSyncDidComplete(event: ChainSyncDidComplete)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processChainSyncDidFail<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainSyncDidFail)> where M1.MatchedType == ChainSyncDidFail {
            let matchers: [Cuckoo.ParameterMatcher<(ChainSyncDidFail)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processChainSyncDidFail(event: ChainSyncDidFail)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processChainsUpdated<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainsUpdatedEvent)> where M1.MatchedType == ChainsUpdatedEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ChainsUpdatedEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processChainsUpdated(event: ChainsUpdatedEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processFailedNodeConnection<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FailedNodeConnectionEvent)> where M1.MatchedType == FailedNodeConnectionEvent {
            let matchers: [Cuckoo.ParameterMatcher<(FailedNodeConnectionEvent)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processFailedNodeConnection(event: FailedNodeConnectionEvent)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processRuntimeCommonTypesSyncCompleted<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeCommonTypesSyncCompleted)> where M1.MatchedType == RuntimeCommonTypesSyncCompleted {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeCommonTypesSyncCompleted)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processRuntimeChainTypesSyncCompleted<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeChainTypesSyncCompleted)> where M1.MatchedType == RuntimeChainTypesSyncCompleted {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeChainTypesSyncCompleted)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processRuntimeChainMetadataSyncCompleted<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeMetadataSyncCompleted)> where M1.MatchedType == RuntimeMetadataSyncCompleted {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeMetadataSyncCompleted)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processRuntimeCoderReady<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeCoderCreated)> where M1.MatchedType == RuntimeCoderCreated {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeCoderCreated)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processRuntimeCoderReady(event: RuntimeCoderCreated)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func processRuntimeCoderCreationFailed<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeCoderCreationFailed)> where M1.MatchedType == RuntimeCoderCreationFailed {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeCoderCreationFailed)>] = [wrap(matchable: event) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockEventVisitorProtocol.self, method:
    """
    processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    processProjectVote(event: ProjectVoteEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processProjectFavoriteToggle<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ProjectFavoriteToggleEvent), Void> where M1.MatchedType == ProjectFavoriteToggleEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ProjectFavoriteToggleEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processProjectView<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ProjectViewEvent), Void> where M1.MatchedType == ProjectViewEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ProjectViewEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processProjectView(event: ProjectViewEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processInvitationInput<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(InvitationInputEvent), Void> where M1.MatchedType == InvitationInputEvent {
            let matchers: [Cuckoo.ParameterMatcher<(InvitationInputEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processInvitationInput(event: InvitationInputEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processInvitationApplied<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(InvitationAppliedEvent), Void> where M1.MatchedType == InvitationAppliedEvent {
            let matchers: [Cuckoo.ParameterMatcher<(InvitationAppliedEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processInvitationApplied(event: InvitationAppliedEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processWalletUpdate<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletUpdateEvent), Void> where M1.MatchedType == WalletUpdateEvent {
            let matchers: [Cuckoo.ParameterMatcher<(WalletUpdateEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processWalletUpdate(event: WalletUpdateEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processReferendumVote<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ReferendumVoteEvent), Void> where M1.MatchedType == ReferendumVoteEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ReferendumVoteEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processReferendumVote(event: ReferendumVoteEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processSelectedAccountChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(SelectedAccountChanged), Void> where M1.MatchedType == SelectedAccountChanged {
            let matchers: [Cuckoo.ParameterMatcher<(SelectedAccountChanged)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processSelectedAccountChanged(event: SelectedAccountChanged)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processSelectedUsernameChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(SelectedUsernameChanged), Void> where M1.MatchedType == SelectedUsernameChanged {
            let matchers: [Cuckoo.ParameterMatcher<(SelectedUsernameChanged)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processSelectedUsernameChanged(event: SelectedUsernameChanged)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processBalanceChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletBalanceChanged), Void> where M1.MatchedType == WalletBalanceChanged {
            let matchers: [Cuckoo.ParameterMatcher<(WalletBalanceChanged)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processBalanceChanged(event: WalletBalanceChanged)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processStakingChanged<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletStakingInfoChanged), Void> where M1.MatchedType == WalletStakingInfoChanged {
            let matchers: [Cuckoo.ParameterMatcher<(WalletStakingInfoChanged)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processStakingChanged(event: WalletStakingInfoChanged)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processNewTransaction<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(WalletNewTransactionInserted), Void> where M1.MatchedType == WalletNewTransactionInserted {
            let matchers: [Cuckoo.ParameterMatcher<(WalletNewTransactionInserted)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processNewTransaction(event: WalletNewTransactionInserted)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processNewTransactionCreated<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(NewTransactionCreatedEvent), Void> where M1.MatchedType == NewTransactionCreatedEvent {
            let matchers: [Cuckoo.ParameterMatcher<(NewTransactionCreatedEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processNewTransactionCreated(event: NewTransactionCreatedEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processTypeRegistryPrepared<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(TypeRegistryPrepared), Void> where M1.MatchedType == TypeRegistryPrepared {
            let matchers: [Cuckoo.ParameterMatcher<(TypeRegistryPrepared)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processTypeRegistryPrepared(event: TypeRegistryPrepared)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(MigrationEvent), Void> where M1.MatchedType == MigrationEvent {
            let matchers: [Cuckoo.ParameterMatcher<(MigrationEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processMigration(event: MigrationEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processSuccsessMigration<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(MigrationSuccsessEvent), Void> where M1.MatchedType == MigrationSuccsessEvent {
            let matchers: [Cuckoo.ParameterMatcher<(MigrationSuccsessEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processSuccsessMigration(event: MigrationSuccsessEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processChainSyncDidStart<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ChainSyncDidStart), Void> where M1.MatchedType == ChainSyncDidStart {
            let matchers: [Cuckoo.ParameterMatcher<(ChainSyncDidStart)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processChainSyncDidStart(event: ChainSyncDidStart)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processChainSyncDidComplete<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ChainSyncDidComplete), Void> where M1.MatchedType == ChainSyncDidComplete {
            let matchers: [Cuckoo.ParameterMatcher<(ChainSyncDidComplete)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processChainSyncDidComplete(event: ChainSyncDidComplete)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processChainSyncDidFail<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ChainSyncDidFail), Void> where M1.MatchedType == ChainSyncDidFail {
            let matchers: [Cuckoo.ParameterMatcher<(ChainSyncDidFail)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processChainSyncDidFail(event: ChainSyncDidFail)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processChainsUpdated<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(ChainsUpdatedEvent), Void> where M1.MatchedType == ChainsUpdatedEvent {
            let matchers: [Cuckoo.ParameterMatcher<(ChainsUpdatedEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processChainsUpdated(event: ChainsUpdatedEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processFailedNodeConnection<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(FailedNodeConnectionEvent), Void> where M1.MatchedType == FailedNodeConnectionEvent {
            let matchers: [Cuckoo.ParameterMatcher<(FailedNodeConnectionEvent)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processFailedNodeConnection(event: FailedNodeConnectionEvent)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processRuntimeCommonTypesSyncCompleted<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(RuntimeCommonTypesSyncCompleted), Void> where M1.MatchedType == RuntimeCommonTypesSyncCompleted {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeCommonTypesSyncCompleted)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processRuntimeChainTypesSyncCompleted<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(RuntimeChainTypesSyncCompleted), Void> where M1.MatchedType == RuntimeChainTypesSyncCompleted {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeChainTypesSyncCompleted)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processRuntimeChainMetadataSyncCompleted<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(RuntimeMetadataSyncCompleted), Void> where M1.MatchedType == RuntimeMetadataSyncCompleted {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeMetadataSyncCompleted)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processRuntimeCoderReady<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(RuntimeCoderCreated), Void> where M1.MatchedType == RuntimeCoderCreated {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeCoderCreated)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processRuntimeCoderReady(event: RuntimeCoderCreated)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func processRuntimeCoderCreationFailed<M1: Cuckoo.Matchable>(event: M1) -> Cuckoo.__DoNotUse<(RuntimeCoderCreationFailed), Void> where M1.MatchedType == RuntimeCoderCreationFailed {
            let matchers: [Cuckoo.ParameterMatcher<(RuntimeCoderCreationFailed)>] = [wrap(matchable: event) { $0 }]
            return cuckoo_manager.verify(
    """
    processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
    
    
    
    
    
     func processBalanceChanged(event: WalletBalanceChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processStakingChanged(event: WalletStakingInfoChanged)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processNewTransaction(event: WalletNewTransactionInserted)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processNewTransactionCreated(event: NewTransactionCreatedEvent)   {
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
    
    
    
    
    
     func processChainSyncDidStart(event: ChainSyncDidStart)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processChainSyncDidComplete(event: ChainSyncDidComplete)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processChainSyncDidFail(event: ChainSyncDidFail)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processChainsUpdated(event: ChainsUpdatedEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processFailedNodeConnection(event: FailedNodeConnectionEvent)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processRuntimeCoderReady(event: RuntimeCoderCreated)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)   {
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
        
    return cuckoo_manager.call(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuthProtocol.self, method:
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuth.self, method:
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """,
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void)  {
        
    return cuckoo_manager.call(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """,
            parameters: (message, title, closeAction, view, completion),
            escapingParameters: (message, title, closeAction, view, completion),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view, completion: completion))
        
    }
    
    
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call(
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method:
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.Matchable>(message: M1, title: M2, closeAction: M3, from view: M4, completion: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol, M5.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: completion) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method:
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method:
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.Matchable>(message: M1, title: M2, closeAction: M3, from view: M4, completion: M5) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?, () -> Void), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol, M5.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: completion) { $0.4 }]
            return cuckoo_manager.verify(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
            return cuckoo_manager.verify(
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class AlertPresentableStub: AlertPresentable {
    

    

    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void)   {
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
    

    

    

    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool
    """,
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool {
        
    return cuckoo_manager.call(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
    """,
            parameters: (error, view, locale, completion),
            escapingParameters: (error, view, locale, completion),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale, completion: completion))
        
    }
    
    

     struct __StubbingProxy_ErrorPresentable: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Swift.Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockErrorPresentable.self, method:
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.Matchable>(error: M1, from view: M2, locale: M3, completion: M4) -> Cuckoo.ProtocolStubFunction<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale, M4.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: completion) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockErrorPresentable.self, method:
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
    """, parameterMatchers: matchers))
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
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Swift.Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
            return cuckoo_manager.verify(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.Matchable>(error: M1, from view: M2, locale: M3, completion: M4) -> Cuckoo.__DoNotUse<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale, M4.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: completion) { $0.3 }]
            return cuckoo_manager.verify(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class ErrorPresentableStub: ErrorPresentable {
    

    

    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool  {
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
        
    return cuckoo_manager.call(
    """
    requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockInputFieldPresentable.self, method:
    """
    requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    didStartLoading()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call(
    """
    didStopLoading()
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method:
    """
    didStartLoading()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method:
    """
    didStopLoading()
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    didStartLoading()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    didStopLoading()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
        
    return cuckoo_manager.call(
    """
    share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockSharingPresentable.self, method:
    """
    share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
    

    

    

    
    
    
    
     func presentAlert(alert: UIAlertController, animated: Bool)  {
        
    return cuckoo_manager.call(
    """
    presentAlert(alert: UIAlertController, animated: Bool)
    """,
            parameters: (alert, animated),
            escapingParameters: (alert, animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentAlert(alert: alert, animated: animated))
        
    }
    
    
    
    
    
     func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)  {
        
    return cuckoo_manager.call(
    """
    presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)
    """,
            parameters: (title, style, animated),
            escapingParameters: (title, style, animated),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentStatus(title: title, style: style, animated: animated))
        
    }
    
    
    
    
    
     func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)  {
        
    return cuckoo_manager.call(
    """
    dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)
    """,
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
        
        
        
        
        func presentAlert<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(alert: M1, animated: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UIAlertController, Bool)> where M1.MatchedType == UIAlertController, M2.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(UIAlertController, Bool)>] = [wrap(matchable: alert) { $0.0 }, wrap(matchable: animated) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockApplicationStatusPresentable.self, method:
    """
    presentAlert(alert: UIAlertController, animated: Bool)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func presentStatus<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, ApplicationStatusStyle, Bool)> where M1.MatchedType == String, M2.MatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(String, ApplicationStatusStyle, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockApplicationStatusPresentable.self, method:
    """
    presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func dismissStatus<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, ApplicationStatusStyle?, Bool)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(String?, ApplicationStatusStyle?, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockApplicationStatusPresentable.self, method:
    """
    dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)
    """, parameterMatchers: matchers))
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
        func presentAlert<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(alert: M1, animated: M2) -> Cuckoo.__DoNotUse<(UIAlertController, Bool), Void> where M1.MatchedType == UIAlertController, M2.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(UIAlertController, Bool)>] = [wrap(matchable: alert) { $0.0 }, wrap(matchable: animated) { $0.1 }]
            return cuckoo_manager.verify(
    """
    presentAlert(alert: UIAlertController, animated: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func presentStatus<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.__DoNotUse<(String, ApplicationStatusStyle, Bool), Void> where M1.MatchedType == String, M2.MatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(String, ApplicationStatusStyle, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
            return cuckoo_manager.verify(
    """
    presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func dismissStatus<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable>(title: M1, style: M2, animated: M3) -> Cuckoo.__DoNotUse<(String?, ApplicationStatusStyle?, Bool), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == ApplicationStatusStyle, M3.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<(String?, ApplicationStatusStyle?, Bool)>] = [wrap(matchable: title) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: animated) { $0.2 }]
            return cuckoo_manager.verify(
    """
    dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class ApplicationStatusPresentableStub: ApplicationStatusPresentable {
    

    

    
    
    
    
     func presentAlert(alert: UIAlertController, animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)   {
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
        
    return cuckoo_manager.call(
    """
    showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockWebPresentable.self, method:
    """
    showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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

import CommonWallet
import UIKit
import XNetworking






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
    
    

    

    
    
    
    
     func setup(with models: [CellViewModel])  {
        
    return cuckoo_manager.call(
    """
    setup(with: [CellViewModel])
    """,
            parameters: (models),
            escapingParameters: (models),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup(with: models))
        
    }
    
    
    
    
    
     func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)  {
        
    return cuckoo_manager.call(
    """
    reloadScreen(with: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)
    """,
            parameters: (models, updatedIndexs, isExpanding),
            escapingParameters: (models, updatedIndexs, isExpanding),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.reloadScreen(with: models, updatedIndexs: updatedIndexs, isExpanding: isExpanding))
        
    }
    
    
    
    
    
     func startInvitingScreen(with referrer: String)  {
        
    return cuckoo_manager.call(
    """
    startInvitingScreen(with: String)
    """,
            parameters: (referrer),
            escapingParameters: (referrer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.startInvitingScreen(with: referrer))
        
    }
    
    
    
    
    
     func showAlert(with text: String, image: UIImage?)  {
        
    return cuckoo_manager.call(
    """
    showAlert(with: String, image: UIImage?)
    """,
            parameters: (text, image),
            escapingParameters: (text, image),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAlert(with: text, image: image))
        
    }
    
    
    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call(
    """
    didStartLoading()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call(
    """
    didStopLoading()
    """,
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
        
        
        
        
        
        func setup<M1: Cuckoo.Matchable>(with models: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([CellViewModel])> where M1.MatchedType == [CellViewModel] {
            let matchers: [Cuckoo.ParameterMatcher<([CellViewModel])>] = [wrap(matchable: models) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method:
    """
    setup(with: [CellViewModel])
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func reloadScreen<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(with models: M1, updatedIndexs: M2, isExpanding: M3) -> Cuckoo.ProtocolStubNoReturnFunction<([CellViewModel], [Int], Bool)> where M1.MatchedType == [CellViewModel], M2.MatchedType == [Int], M3.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<([CellViewModel], [Int], Bool)>] = [wrap(matchable: models) { $0.0 }, wrap(matchable: updatedIndexs) { $0.1 }, wrap(matchable: isExpanding) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method:
    """
    reloadScreen(with: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func startInvitingScreen<M1: Cuckoo.Matchable>(with referrer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: referrer) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method:
    """
    startInvitingScreen(with: String)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func showAlert<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(with text: M1, image: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(String, UIImage?)> where M1.MatchedType == String, M2.OptionalMatchedType == UIImage {
            let matchers: [Cuckoo.ParameterMatcher<(String, UIImage?)>] = [wrap(matchable: text) { $0.0 }, wrap(matchable: image) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method:
    """
    showAlert(with: String, image: UIImage?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method:
    """
    didStartLoading()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsViewProtocol.self, method:
    """
    didStopLoading()
    """, parameterMatchers: matchers))
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
        func setup<M1: Cuckoo.Matchable>(with models: M1) -> Cuckoo.__DoNotUse<([CellViewModel]), Void> where M1.MatchedType == [CellViewModel] {
            let matchers: [Cuckoo.ParameterMatcher<([CellViewModel])>] = [wrap(matchable: models) { $0 }]
            return cuckoo_manager.verify(
    """
    setup(with: [CellViewModel])
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func reloadScreen<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(with models: M1, updatedIndexs: M2, isExpanding: M3) -> Cuckoo.__DoNotUse<([CellViewModel], [Int], Bool), Void> where M1.MatchedType == [CellViewModel], M2.MatchedType == [Int], M3.MatchedType == Bool {
            let matchers: [Cuckoo.ParameterMatcher<([CellViewModel], [Int], Bool)>] = [wrap(matchable: models) { $0.0 }, wrap(matchable: updatedIndexs) { $0.1 }, wrap(matchable: isExpanding) { $0.2 }]
            return cuckoo_manager.verify(
    """
    reloadScreen(with: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func startInvitingScreen<M1: Cuckoo.Matchable>(with referrer: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: referrer) { $0 }]
            return cuckoo_manager.verify(
    """
    startInvitingScreen(with: String)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func showAlert<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(with text: M1, image: M2) -> Cuckoo.__DoNotUse<(String, UIImage?), Void> where M1.MatchedType == String, M2.OptionalMatchedType == UIImage {
            let matchers: [Cuckoo.ParameterMatcher<(String, UIImage?)>] = [wrap(matchable: text) { $0.0 }, wrap(matchable: image) { $0.1 }]
            return cuckoo_manager.verify(
    """
    showAlert(with: String, image: UIImage?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    didStartLoading()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return cuckoo_manager.verify(
    """
    didStopLoading()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
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
    
    

    

    
    
    
    
     func setup(with models: [CellViewModel])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func startInvitingScreen(with referrer: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func showAlert(with text: String, image: UIImage?)   {
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
        
    return cuckoo_manager.call(
    """
    setup()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
    
    
     func didSelectAction(_ action: FriendsPresenter.InvitationActionType)  {
        
    return cuckoo_manager.call(
    """
    didSelectAction(_: FriendsPresenter.InvitationActionType)
    """,
            parameters: (action),
            escapingParameters: (action),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSelectAction(action))
        
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """,
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void)  {
        
    return cuckoo_manager.call(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """,
            parameters: (message, title, closeAction, view, completion),
            escapingParameters: (message, title, closeAction, view, completion),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view, completion: completion))
        
    }
    
    
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call(
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """,
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
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method:
    """
    setup()
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func didSelectAction<M1: Cuckoo.Matchable>(_ action: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FriendsPresenter.InvitationActionType)> where M1.MatchedType == FriendsPresenter.InvitationActionType {
            let matchers: [Cuckoo.ParameterMatcher<(FriendsPresenter.InvitationActionType)>] = [wrap(matchable: action) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method:
    """
    didSelectAction(_: FriendsPresenter.InvitationActionType)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method:
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.Matchable>(message: M1, title: M2, closeAction: M3, from view: M4, completion: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol, M5.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: completion) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method:
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsPresenterProtocol.self, method:
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    setup()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func didSelectAction<M1: Cuckoo.Matchable>(_ action: M1) -> Cuckoo.__DoNotUse<(FriendsPresenter.InvitationActionType), Void> where M1.MatchedType == FriendsPresenter.InvitationActionType {
            let matchers: [Cuckoo.ParameterMatcher<(FriendsPresenter.InvitationActionType)>] = [wrap(matchable: action) { $0 }]
            return cuckoo_manager.verify(
    """
    didSelectAction(_: FriendsPresenter.InvitationActionType)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
            return cuckoo_manager.verify(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.Matchable>(message: M1, title: M2, closeAction: M3, from view: M4, completion: M5) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?, () -> Void), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol, M5.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: completion) { $0.4 }]
            return cuckoo_manager.verify(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
            return cuckoo_manager.verify(
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class FriendsPresenterProtocolStub: FriendsPresenterProtocol {
    

    

    
    
    
    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func didSelectAction(_ action: FriendsPresenter.InvitationActionType)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void)   {
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
        
    return cuckoo_manager.call(
    """
    setup()
    """,
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    

     struct __StubbingProxy_FriendsInteractorInputProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorInputProtocol.self, method:
    """
    setup()
    """, parameterMatchers: matchers))
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
            return cuckoo_manager.verify(
    """
    setup()
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class FriendsInteractorInputProtocolStub: FriendsInteractorInputProtocol {
    

    

    
    
    
    
     func setup()   {
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
    

    

    

    
    
    
    
     func didReceive(rewards: [ReferrerReward], setReferrerFee: Decimal, bondFee: Decimal, unbondFee: Decimal, referralBalance: Decimal, referrer: String)  {
        
    return cuckoo_manager.call(
    """
    didReceive(rewards: [ReferrerReward], setReferrerFee: Decimal, bondFee: Decimal, unbondFee: Decimal, referralBalance: Decimal, referrer: String)
    """,
            parameters: (rewards, setReferrerFee, bondFee, unbondFee, referralBalance, referrer),
            escapingParameters: (rewards, setReferrerFee, bondFee, unbondFee, referralBalance, referrer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(rewards: rewards, setReferrerFee: setReferrerFee, bondFee: bondFee, unbondFee: unbondFee, referralBalance: referralBalance, referrer: referrer))
        
    }
    
    
    
    
    
     func updateReferrer(address: String)  {
        
    return cuckoo_manager.call(
    """
    updateReferrer(address: String)
    """,
            parameters: (address),
            escapingParameters: (address),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateReferrer(address: address))
        
    }
    
    
    
    
    
     func updateReferral(balance: Decimal)  {
        
    return cuckoo_manager.call(
    """
    updateReferral(balance: Decimal)
    """,
            parameters: (balance),
            escapingParameters: (balance),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateReferral(balance: balance))
        
    }
    
    
    
    
    
     func updateReferral(rewards: [ReferrerReward])  {
        
    return cuckoo_manager.call(
    """
    updateReferral(rewards: [ReferrerReward])
    """,
            parameters: (rewards),
            escapingParameters: (rewards),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateReferral(rewards: rewards))
        
    }
    
    

     struct __StubbingProxy_FriendsInteractorOutputProtocol: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager
    
         init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }
        
        
        
        
        func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable, M6: Cuckoo.Matchable>(rewards: M1, setReferrerFee: M2, bondFee: M3, unbondFee: M4, referralBalance: M5, referrer: M6) -> Cuckoo.ProtocolStubNoReturnFunction<([ReferrerReward], Decimal, Decimal, Decimal, Decimal, String)> where M1.MatchedType == [ReferrerReward], M2.MatchedType == Decimal, M3.MatchedType == Decimal, M4.MatchedType == Decimal, M5.MatchedType == Decimal, M6.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<([ReferrerReward], Decimal, Decimal, Decimal, Decimal, String)>] = [wrap(matchable: rewards) { $0.0 }, wrap(matchable: setReferrerFee) { $0.1 }, wrap(matchable: bondFee) { $0.2 }, wrap(matchable: unbondFee) { $0.3 }, wrap(matchable: referralBalance) { $0.4 }, wrap(matchable: referrer) { $0.5 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method:
    """
    didReceive(rewards: [ReferrerReward], setReferrerFee: Decimal, bondFee: Decimal, unbondFee: Decimal, referralBalance: Decimal, referrer: String)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func updateReferrer<M1: Cuckoo.Matchable>(address: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(String)> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method:
    """
    updateReferrer(address: String)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func updateReferral<M1: Cuckoo.Matchable>(balance: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Decimal)> where M1.MatchedType == Decimal {
            let matchers: [Cuckoo.ParameterMatcher<(Decimal)>] = [wrap(matchable: balance) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method:
    """
    updateReferral(balance: Decimal)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func updateReferral<M1: Cuckoo.Matchable>(rewards: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([ReferrerReward])> where M1.MatchedType == [ReferrerReward] {
            let matchers: [Cuckoo.ParameterMatcher<([ReferrerReward])>] = [wrap(matchable: rewards) { $0 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsInteractorOutputProtocol.self, method:
    """
    updateReferral(rewards: [ReferrerReward])
    """, parameterMatchers: matchers))
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
        func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable, M6: Cuckoo.Matchable>(rewards: M1, setReferrerFee: M2, bondFee: M3, unbondFee: M4, referralBalance: M5, referrer: M6) -> Cuckoo.__DoNotUse<([ReferrerReward], Decimal, Decimal, Decimal, Decimal, String), Void> where M1.MatchedType == [ReferrerReward], M2.MatchedType == Decimal, M3.MatchedType == Decimal, M4.MatchedType == Decimal, M5.MatchedType == Decimal, M6.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<([ReferrerReward], Decimal, Decimal, Decimal, Decimal, String)>] = [wrap(matchable: rewards) { $0.0 }, wrap(matchable: setReferrerFee) { $0.1 }, wrap(matchable: bondFee) { $0.2 }, wrap(matchable: unbondFee) { $0.3 }, wrap(matchable: referralBalance) { $0.4 }, wrap(matchable: referrer) { $0.5 }]
            return cuckoo_manager.verify(
    """
    didReceive(rewards: [ReferrerReward], setReferrerFee: Decimal, bondFee: Decimal, unbondFee: Decimal, referralBalance: Decimal, referrer: String)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func updateReferrer<M1: Cuckoo.Matchable>(address: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: address) { $0 }]
            return cuckoo_manager.verify(
    """
    updateReferrer(address: String)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func updateReferral<M1: Cuckoo.Matchable>(balance: M1) -> Cuckoo.__DoNotUse<(Decimal), Void> where M1.MatchedType == Decimal {
            let matchers: [Cuckoo.ParameterMatcher<(Decimal)>] = [wrap(matchable: balance) { $0 }]
            return cuckoo_manager.verify(
    """
    updateReferral(balance: Decimal)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func updateReferral<M1: Cuckoo.Matchable>(rewards: M1) -> Cuckoo.__DoNotUse<([ReferrerReward]), Void> where M1.MatchedType == [ReferrerReward] {
            let matchers: [Cuckoo.ParameterMatcher<([ReferrerReward])>] = [wrap(matchable: rewards) { $0 }]
            return cuckoo_manager.verify(
    """
    updateReferral(rewards: [ReferrerReward])
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class FriendsInteractorOutputProtocolStub: FriendsInteractorOutputProtocol {
    

    

    
    
    
    
     func didReceive(rewards: [ReferrerReward], setReferrerFee: Decimal, bondFee: Decimal, unbondFee: Decimal, referralBalance: Decimal, referrer: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func updateReferrer(address: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func updateReferral(balance: Decimal)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func updateReferral(rewards: [ReferrerReward])   {
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
    

    

    

    
    
    
    
     func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput)  {
        
    return cuckoo_manager.call(
    """
    showLinkInputViewController(from: UIViewController, delegate: InputLinkPresenterOutput)
    """,
            parameters: (controller, delegate),
            escapingParameters: (controller, delegate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showLinkInputViewController(from: controller, delegate: delegate))
        
    }
    
    
    
    
    
     func showInputRewardAmountViewController(from controller: UIViewController, fee: Decimal, bondedAmount: Decimal, type: InputRewardAmountType, delegate: InputRewardAmountPresenterOutput)  {
        
    return cuckoo_manager.call(
    """
    showInputRewardAmountViewController(from: UIViewController, fee: Decimal, bondedAmount: Decimal, type: InputRewardAmountType, delegate: InputRewardAmountPresenterOutput)
    """,
            parameters: (controller, fee, bondedAmount, type, delegate),
            escapingParameters: (controller, fee, bondedAmount, type, delegate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showInputRewardAmountViewController(from: controller, fee: fee, bondedAmount: bondedAmount, type: type, delegate: delegate))
        
    }
    
    
    
    
    
     func showActivityViewController(from controller: UIViewController, shareText: String)  {
        
    return cuckoo_manager.call(
    """
    showActivityViewController(from: UIViewController, shareText: String)
    """,
            parameters: (controller, shareText),
            escapingParameters: (controller, shareText),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showActivityViewController(from: controller, shareText: shareText))
        
    }
    
    
    
    
    
     func showReferrerScreen(from controller: UIViewController, referrer: String)  {
        
    return cuckoo_manager.call(
    """
    showReferrerScreen(from: UIViewController, referrer: String)
    """,
            parameters: (controller, referrer),
            escapingParameters: (controller, referrer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showReferrerScreen(from: controller, referrer: referrer))
        
    }
    
    
    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)  {
        
    return cuckoo_manager.call(
    """
    share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)
    """,
            parameters: (source, view, completionHandler),
            escapingParameters: (source, view, completionHandler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.share(source: source, from: view, with: completionHandler))
        
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """,
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void)  {
        
    return cuckoo_manager.call(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """,
            parameters: (message, title, closeAction, view, completion),
            escapingParameters: (message, title, closeAction, view, completion),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view, completion: completion))
        
    }
    
    
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call(
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """,
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    
    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        
    return cuckoo_manager.call(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool
    """,
            parameters: (error, view, locale),
            escapingParameters: (error, view, locale),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale))
        
    }
    
    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool {
        
    return cuckoo_manager.call(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
    """,
            parameters: (error, view, locale, completion),
            escapingParameters: (error, view, locale, completion),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(error: error, from: view, locale: locale, completion: completion))
        
    }
    
    
    
    
    
     func requestInput(for viewModel: InputFieldViewModelProtocol, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call(
    """
    requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)
    """,
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
        
        
        
        
        func showLinkInputViewController<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from controller: M1, delegate: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UIViewController, InputLinkPresenterOutput)> where M1.MatchedType == UIViewController, M2.MatchedType == InputLinkPresenterOutput {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, InputLinkPresenterOutput)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: delegate) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    showLinkInputViewController(from: UIViewController, delegate: InputLinkPresenterOutput)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func showInputRewardAmountViewController<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable>(from controller: M1, fee: M2, bondedAmount: M3, type: M4, delegate: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(UIViewController, Decimal, Decimal, InputRewardAmountType, InputRewardAmountPresenterOutput)> where M1.MatchedType == UIViewController, M2.MatchedType == Decimal, M3.MatchedType == Decimal, M4.MatchedType == InputRewardAmountType, M5.MatchedType == InputRewardAmountPresenterOutput {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, Decimal, Decimal, InputRewardAmountType, InputRewardAmountPresenterOutput)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: fee) { $0.1 }, wrap(matchable: bondedAmount) { $0.2 }, wrap(matchable: type) { $0.3 }, wrap(matchable: delegate) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    showInputRewardAmountViewController(from: UIViewController, fee: Decimal, bondedAmount: Decimal, type: InputRewardAmountType, delegate: InputRewardAmountPresenterOutput)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func showActivityViewController<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from controller: M1, shareText: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UIViewController, String)> where M1.MatchedType == UIViewController, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, String)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: shareText) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    showActivityViewController(from: UIViewController, shareText: String)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func showReferrerScreen<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from controller: M1, referrer: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UIViewController, String)> where M1.MatchedType == UIViewController, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, String)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: referrer) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    showReferrerScreen(from: UIViewController, referrer: String)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
            let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.Matchable>(message: M1, title: M2, closeAction: M3, from view: M4, completion: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol, M5.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: completion) { $0.4 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.ProtocolStubFunction<(Swift.Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.Matchable>(error: M1, from view: M2, locale: M3, completion: M4) -> Cuckoo.ProtocolStubFunction<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale, M4.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: completion) { $0.3 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
    """, parameterMatchers: matchers))
        }
        
        
        
        
        func requestInput<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for viewModel: M1, from view: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(InputFieldViewModelProtocol, ControllerBackedProtocol?)> where M1.MatchedType == InputFieldViewModelProtocol, M2.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(InputFieldViewModelProtocol, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: view) { $0.1 }]
            return .init(stub: cuckoo_manager.createStub(for: MockFriendsWireframeProtocol.self, method:
    """
    requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)
    """, parameterMatchers: matchers))
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
        func showLinkInputViewController<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from controller: M1, delegate: M2) -> Cuckoo.__DoNotUse<(UIViewController, InputLinkPresenterOutput), Void> where M1.MatchedType == UIViewController, M2.MatchedType == InputLinkPresenterOutput {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, InputLinkPresenterOutput)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: delegate) { $0.1 }]
            return cuckoo_manager.verify(
    """
    showLinkInputViewController(from: UIViewController, delegate: InputLinkPresenterOutput)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func showInputRewardAmountViewController<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable>(from controller: M1, fee: M2, bondedAmount: M3, type: M4, delegate: M5) -> Cuckoo.__DoNotUse<(UIViewController, Decimal, Decimal, InputRewardAmountType, InputRewardAmountPresenterOutput), Void> where M1.MatchedType == UIViewController, M2.MatchedType == Decimal, M3.MatchedType == Decimal, M4.MatchedType == InputRewardAmountType, M5.MatchedType == InputRewardAmountPresenterOutput {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, Decimal, Decimal, InputRewardAmountType, InputRewardAmountPresenterOutput)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: fee) { $0.1 }, wrap(matchable: bondedAmount) { $0.2 }, wrap(matchable: type) { $0.3 }, wrap(matchable: delegate) { $0.4 }]
            return cuckoo_manager.verify(
    """
    showInputRewardAmountViewController(from: UIViewController, fee: Decimal, bondedAmount: Decimal, type: InputRewardAmountType, delegate: InputRewardAmountPresenterOutput)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func showActivityViewController<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from controller: M1, shareText: M2) -> Cuckoo.__DoNotUse<(UIViewController, String), Void> where M1.MatchedType == UIViewController, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, String)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: shareText) { $0.1 }]
            return cuckoo_manager.verify(
    """
    showActivityViewController(from: UIViewController, shareText: String)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func showReferrerScreen<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from controller: M1, referrer: M2) -> Cuckoo.__DoNotUse<(UIViewController, String), Void> where M1.MatchedType == UIViewController, M2.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<(UIViewController, String)>] = [wrap(matchable: controller) { $0.0 }, wrap(matchable: referrer) { $0.1 }]
            return cuckoo_manager.verify(
    """
    showReferrerScreen(from: UIViewController, referrer: String)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func share<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(source: M1, from view: M2, with completionHandler: M3) -> Cuckoo.__DoNotUse<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?), Void> where M1.MatchedType == UIActivityItemSource, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == SharingCompletionHandler {
            let matchers: [Cuckoo.ParameterMatcher<(UIActivityItemSource, ControllerBackedProtocol?, SharingCompletionHandler?)>] = [wrap(matchable: source) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: completionHandler) { $0.2 }]
            return cuckoo_manager.verify(
    """
    share(source: UIActivityItemSource, from: ControllerBackedProtocol?, with: SharingCompletionHandler?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
            return cuckoo_manager.verify(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.Matchable>(message: M1, title: M2, closeAction: M3, from view: M4, completion: M5) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?, () -> Void), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol, M5.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?, () -> Void)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }, wrap(matchable: completion) { $0.4 }]
            return cuckoo_manager.verify(
    """
    present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?, completion: @escaping () -> Void)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
            return cuckoo_manager.verify(
    """
    present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(error: M1, from view: M2, locale: M3) -> Cuckoo.__DoNotUse<(Swift.Error, ControllerBackedProtocol?, Locale?), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }]
            return cuckoo_manager.verify(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func present<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.Matchable>(error: M1, from view: M2, locale: M3, completion: M4) -> Cuckoo.__DoNotUse<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void), Bool> where M1.MatchedType == Swift.Error, M2.OptionalMatchedType == ControllerBackedProtocol, M3.OptionalMatchedType == Locale, M4.MatchedType == () -> Void {
            let matchers: [Cuckoo.ParameterMatcher<(Swift.Error, ControllerBackedProtocol?, Locale?, () -> Void)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: locale) { $0.2 }, wrap(matchable: completion) { $0.3 }]
            return cuckoo_manager.verify(
    """
    present(error: Swift.Error, from: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
        
        
        @discardableResult
        func requestInput<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for viewModel: M1, from view: M2) -> Cuckoo.__DoNotUse<(InputFieldViewModelProtocol, ControllerBackedProtocol?), Void> where M1.MatchedType == InputFieldViewModelProtocol, M2.OptionalMatchedType == ControllerBackedProtocol {
            let matchers: [Cuckoo.ParameterMatcher<(InputFieldViewModelProtocol, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: view) { $0.1 }]
            return cuckoo_manager.verify(
    """
    requestInput(for: InputFieldViewModelProtocol, from: ControllerBackedProtocol?)
    """, callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
        }
        
        
    }
}


 class FriendsWireframeProtocolStub: FriendsWireframeProtocol {
    

    

    
    
    
    
     func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func showInputRewardAmountViewController(from controller: UIViewController, fee: Decimal, bondedAmount: Decimal, type: InputRewardAmountType, delegate: InputRewardAmountPresenterOutput)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func showActivityViewController(from controller: UIViewController, shareText: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func showReferrerScreen(from controller: UIViewController, referrer: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completionHandler: SharingCompletionHandler?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
    
    
     func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
    
    
     func requestInput(for viewModel: InputFieldViewModelProtocol, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
}




