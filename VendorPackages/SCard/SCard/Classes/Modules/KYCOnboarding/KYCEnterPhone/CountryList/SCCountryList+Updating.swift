import UIKit

extension CountryList: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let searchResults = countries
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let searchString = searchController.searchBar.text!
            .trimmingCharacters(in: whitespaceCharacterSet)
            .lowercased()

        let filteredResults = searchResults.filter {
            $0.name.lowercased().contains(searchString) ||
            $0.localizedName.lowercased().contains(searchString) ||
            $0.originalName.lowercased().contains(searchString) ||
            $0.code.lowercased().contains(searchString) ||
            $0.dialCode.lowercased().contains(searchString)
        }

        if let resultsController = searchController.searchResultsController as? ResultsTableController {
            resultsController.filteredCountries = filteredResults
            resultsController.tableView.reloadData()
        }
    }
}
