/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol SelectCountryViewProtocol: ControllerBackedProtocol {
    func didReceive(state: ViewModelState<[String]>)
}

protocol SelectCountryPresenterProtocol: class {
    func setup()
    func search(by query: String)
    func select(at index: Int)
}

protocol SelectCountryInteractorInputProtocol: class {
    func setup()
}

protocol SelectCountryInteractorOutputProtocol: class {
    func didReceive(countries: [Country])
    func didReceiveDataProvider(error: Error)
}

protocol SelectCountryWireframeProtocol: class {
    func showNext(from view: SelectCountryViewProtocol?, country: Country)
}

protocol SelectCountryViewFactoryProtocol: class {
    static func createView() -> SelectCountryViewProtocol?
}
