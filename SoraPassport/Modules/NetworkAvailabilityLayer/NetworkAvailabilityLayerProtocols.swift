protocol NetworkAvailabilityLayerInteractorInputProtocol: class {
    func setup()
}

protocol NetworkAvailabilityLayerInteractorOutputProtocol: class {
    func didDecideUnreachableStatusPresentation()
    func didDecideReachableStatusPresentation()
}
