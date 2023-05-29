protocol NetworkAvailabilityLayerInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NetworkAvailabilityLayerInteractorOutputProtocol: AnyObject {
    func didDecideUnreachableStatusPresentation()
    func didDecideReachableStatusPresentation()
}
