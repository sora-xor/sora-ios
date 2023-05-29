import Foundation
import SoraUIKit

class ProfileLoginModel {
    let title: String
    let sections: [SoramitsuTableViewSection]

    init(title: String, sections: [SoramitsuTableViewSection]) {
        self.title = title
        self.sections = sections
    }
}
