import UIKit

final class AboutViewController: UIViewController {
    private enum Row {
        static let height: CGFloat = 55.0

        case version
        case writeUs
        case opensource
        case terms
        case privacy
    }

    private enum Section: Int, CaseIterable {
        static let height: CGFloat = 55.0

        case software
        case legal

        var rows: [Row] {
            switch self {
            case .software:
                return [.version, .writeUs, .opensource]
            case .legal:
                return [.terms, .privacy]
            }
        }

        var title: String {
            switch self {
            case .software:
                return R.string.localizable.aboutSoftwareTitle()
            case .legal:
                return R.string.localizable.aboutLegalTitle()
            }
        }
    }

    var presenter: AboutPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private var version: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()

        presenter.setup()
    }

    // MARK: UITableView

    private func configureTableView() {
        tableView.register(R.nib.aboutAccessoryTitleCell)
        tableView.register(R.nib.aboutNavigationCell)

        let hiddableFooterSize = CGSize(width: tableView.bounds.width, height: 1.0)
        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero,
                                                         size: hiddableFooterSize))
    }

    private func prepareAccessoryCell(for tableView: UITableView,
                                      indexPath: IndexPath,
                                      title: String,
                                      subtitle: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.aboutAccessoryTitleCellId,
                                                 for: indexPath)!

        cell.bind(title: title, subtitle: subtitle)

        return cell
    }

    private func prepareNavigationCell(for tableView: UITableView,
                                       indexPath: IndexPath,
                                       title: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.aboutNavigationCellId,
                                                 for: indexPath)!

        cell.bind(title: title)

        return cell
    }
}

extension AboutViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Section(rawValue: section)!.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)!.rows[indexPath.row] {
        case .version:
            return prepareAccessoryCell(for: tableView,
                                        indexPath: indexPath,
                                        title: R.string.localizable.aboutVersionTitle(),
                                        subtitle: version)
        case .writeUs:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable.aboutWriteUs())
        case .opensource:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable.aboutOpensourceTitle())
        case .terms:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable.aboutTermsTitle())
        case .privacy:
            return prepareNavigationCell(for: tableView,
                                         indexPath: indexPath,
                                         title: R.string.localizable.aboutPrivacyTitle())
        }
    }
}

extension AboutViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Row.height
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Section.height
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let view = UINib(resource: R.nib.aboutHeaderView)
            .instantiate(withOwner: nil, options: nil).first as? AboutHeaderView else {
                return nil
        }

        view.bind(title: Section(rawValue: section)!.title)

        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)!.rows[indexPath.row] {
        case .version:
            return
        case .writeUs:
            presenter.activateWriteUs()
        case .opensource:
            presenter.activateOpensource()
        case .terms:
            presenter.activateTerms()
        case .privacy:
            presenter.activatePrivacyPolicy()
        }
    }
}

extension AboutViewController: AboutViewProtocol {
    func didReceive(version: String) {
        self.version = version
        tableView.reloadData()
    }
}
