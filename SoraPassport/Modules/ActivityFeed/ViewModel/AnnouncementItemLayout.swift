import UIKit

struct AnnouncementItemLayoutMetadata: Withable {
    var itemWidth: CGFloat = 338.0
    var headerHeight: CGFloat = 41.0
    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 12.0, left: 20.0, bottom: 16.0, right: 20.0)

    var messageFont: UIFont = UIFont.announcementMessage

    var drawingOptions: NSStringDrawingOptions = .usesLineFragmentOrigin
}
