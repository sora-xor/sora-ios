import CommonWallet

struct SubqueryReferrerRewardsData: Decodable {
    struct ReferrerRewardsElements: Decodable {
        let pageInfo: SubqueryPageInfo
        let nodes: [SubqueryReferrerRewardsElement]
    }

    let referrerRewards: ReferrerRewardsElements
}

struct SubqueryReferrerRewardsElement: Decodable {

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case timestamp
        case blockHeight
        case referral
        case referrer
        case amount
    }

    let identifier: String
    let timestamp: SubqueryTimestamp
    let blockHeight: String
    let referral: String
    let referrer: String
    let amount: AmountDecimal
}
