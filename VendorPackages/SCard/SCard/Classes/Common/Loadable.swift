enum Loadable<Data, Failure> where Failure : Error {
    case inited
    case loading(Data?)
    case success(Data)
    case failure(Failure)
}
