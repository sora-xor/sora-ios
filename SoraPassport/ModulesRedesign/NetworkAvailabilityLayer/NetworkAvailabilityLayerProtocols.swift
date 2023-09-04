protocol NetworkAvailabilityLayerInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NetworkAvailabilityLayerInteractorOutputProtocol: AnyObject {
    func didDecideUnreachableNodesAllertPresentation()
    func didDecideUnreachableStatusPresentation()
    func didDecideReachableStatusPresentation()
}
