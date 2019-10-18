import Foundation

enum MediaItemType: String, Codable {
    case image = "IMAGE"
    case video = "VIDEO"
}

enum MediaItemData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case type
    }

    case image(item: ImageData)
    case video(item: VideoData)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MediaItemType.self, forKey: .type)

        switch type {
        case .image:
            let item = try ImageData(from: decoder)
            self = .image(item: item)
        case .video:
            let item = try VideoData(from: decoder)
            self = .video(item: item)
        }
    }

    func encode(to encoder: Encoder) throws {
        var typeContainer = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .image(let item):
            try typeContainer.encode(MediaItemType.image, forKey: .type)
            try item.encode(to: encoder)
        case .video(item: let item):
            try typeContainer.encode(MediaItemType.video, forKey: .type)
            try item.encode(to: encoder)
        }
    }
}

struct ImageData: Codable, Equatable {
    var url: URL
}

struct VideoData: Codable, Equatable {
    var url: URL
    var previewUrl: URL?
    var duration: Int
}
