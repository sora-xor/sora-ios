import UIKit

extension CountryList {

    enum RestorationKeys: String {
        case viewControllerTitle
        case searchControllerIsActive
        case searchBarText
        case searchBarIsFirstResponder
        case selectedScope
    }

    struct SearchControllerRestorableState {
        var wasActive = false
        var wasFirstResponder = false
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(navigationItem.title!, forKey: RestorationKeys.viewControllerTitle.rawValue)
        coder.encode(searchController.isActive, forKey: RestorationKeys.searchControllerIsActive.rawValue)
        coder.encode(searchController.searchBar.isFirstResponder, forKey: RestorationKeys.searchBarIsFirstResponder.rawValue)
        coder.encode(searchController.searchBar.selectedScopeButtonIndex, forKey: RestorationKeys.selectedScope.rawValue)
        coder.encode(searchController.searchBar.text, forKey: RestorationKeys.searchBarText.rawValue)
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        guard let decodedTitle = coder.decodeObject(forKey: RestorationKeys.viewControllerTitle.rawValue) as? String else {
            fatalError("A title did not exist. In your app, handle this gracefully.")
        }
        navigationItem.title! = decodedTitle
        restoredState.wasActive = coder.decodeBool(forKey: RestorationKeys.searchControllerIsActive.rawValue)
        restoredState.wasFirstResponder = coder.decodeBool(forKey: RestorationKeys.searchBarIsFirstResponder.rawValue)
        searchController.searchBar.selectedScopeButtonIndex = coder.decodeInteger(forKey: RestorationKeys.selectedScope.rawValue)
        searchController.searchBar.text = coder.decodeObject(forKey: RestorationKeys.searchBarText.rawValue) as? String
    }

}
