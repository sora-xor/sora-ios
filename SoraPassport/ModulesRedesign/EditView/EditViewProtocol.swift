import Foundation
import SoraUIKit
import UIKit

typealias EditViewDataSource = UITableViewDiffableDataSource<EnabledSection, EnabledSectionItem>
typealias EditViewSnapshot = NSDiffableDataSourceSnapshot<EnabledSection, EnabledSectionItem>

protocol EditViewControllerProtocol: ControllerBackedProtocol {}

protocol EditViewFactoryProtocol: AnyObject {
    static func createView(completion: (() -> Void)?) -> EditViewController
}

protocol EditViewModelProtocol: AnyObject {
    var snapshotPublisher: Published<EditViewSnapshot>.Publisher { get }
    var completion: (() -> Void)? { get }
    func reloadView(with section: EnabledSection?)
}

extension EditViewModelProtocol {
    func reloadView(with section: EnabledSection? = nil) {
        reloadView(with: section)
    }
}

