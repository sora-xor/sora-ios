import SoraUIKit
import Anchorage

protocol SettingsInformationViewProtocol: ControllerBackedProtocol {
    var presenter: SettingsInformationPresenterProtocol? { get set }
    
    func set(title: String)
    func update(snapshot: SettingsInformationSnapshot)
}

final class SettingsInformationViewController: SoramitsuViewController & SettingsInformationViewProtocol {
    var presenter: SettingsInformationPresenterProtocol?
    
    private lazy var dataSource: SettingsInformationDataSource = {
        SettingsInformationDataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsInformationCell", for: indexPath) as? SettingsInformationCell
            cell?.set(item: item, context: nil)
            return cell
        }
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.rowHeight = 64
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.estimatedSectionFooterHeight = 16
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        addCloseButton()
        setupView()
        setupConstraints()
        presenter?.reload()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
        
        tableView.register(SettingsInformationCell.self, forCellReuseIdentifier: "SettingsInformationCell")
    }

    private func setupConstraints() {
        tableView.edgeAnchors == view.safeAreaLayoutGuide.edgeAnchors
    }
    
    func set(title: String) {
        navigationItem.title = title
        setNeedsStatusBarAppearanceUpdate()
    }

    func update(snapshot: SettingsInformationSnapshot) {
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension SettingsInformationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        item.onTap?()
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
}

extension SettingsInformationViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -200 {
            close()
        }
    }
}
