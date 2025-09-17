import UIKit
import SoraUIKit

class CountryList: UITableViewController, UISearchControllerDelegate {

    var onCountrySelected: ((SCCountry) -> Void)?

    let tableViewCellIdentifier = "cellID"

    // MARK: - Properties

    let service: KYCService
    var countries = [SCCountry]()
    var searchController: UISearchController!
    private var resultsTableController: ResultsTableController!
    var restoredState = SearchControllerRestorableState()

    // MARK: - View Life Cycle

    init(service: KYCService) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        title = R.string.soraCard.selectCountryTitle(preferredLanguages: .currentLocale)

        tableView.register(CountryCell.self, forCellReuseIdentifier: tableViewCellIdentifier)

        resultsTableController = ResultsTableController()
        resultsTableController.tableView.delegate = self

        searchController = UISearchController(searchResultsController: resultsTableController)
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.delegate = self
        searchController.searchBar.barStyle = SoramitsuUI.shared.theme == .dark ? .black : .default
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        setupDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if restoredState.wasActive {
            searchController.isActive = restoredState.wasActive
            restoredState.wasActive = false

            if restoredState.wasFirstResponder {
                searchController.searchBar.becomeFirstResponder()
                restoredState.wasFirstResponder = false
            }
        }
    }

    private func setupDataSource() {
        countries = service.countries
    }
}

// MARK: - UITableViewDelegate

extension CountryList {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedCountry: SCCountry
        if tableView === self.tableView {
            selectedCountry = countries[indexPath.row]
        } else {
            selectedCountry = resultsTableController.filteredCountries[indexPath.row]
        }

        tableView.deselectRow(at: indexPath, animated: false)
        onCountrySelected?(selectedCountry)
    }
}

// MARK: - UITableViewDataSource

extension CountryList {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return countries.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: tableViewCellIdentifier, for: indexPath) as? CountryCell
        let country = countries[indexPath.row]
        cell?.configure(model: country)
        return cell ?? .init()
    }
}

// MARK: - UISearchBarDelegate

extension CountryList: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }
}
