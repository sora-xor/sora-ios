import SoraUIKit


final class MoreMenuViewController: SoramitsuViewController & MoreMenuViewProtocol {
    var presenter: MoreMenuPresenterProtocol?
    
    private lazy var dataSource: MoreMenuDataSource = {
        MoreMenuDataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "MoreMenuCell", for: indexPath) as? MoreMenuCell
            cell?.set(item: item, context: nil)
            return cell
        }
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        presenter?.reload()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .bgPage
        soramitsuView.addSubview(tableView)
        
        tableView.register(MoreMenuCell.self, forCellReuseIdentifier: "MoreMenuCell")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: soramitsuView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: soramitsuView.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: soramitsuView.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: soramitsuView.centerYAnchor)
        ])
    }
    
    func set(title: String) {
        navigationItem.title = title
    }

    func update(snapshot: MoreMenuSnapshot) {
        dataSource.apply(snapshot, animatingDifferences: true)
    }

}


extension MoreMenuViewController: UITableViewDelegate {
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
