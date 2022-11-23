import BigInt

//struct SubqueryPoolsInfoResponse: Decodable {
//    let data: SubqueryPoolsInfoData
//}

struct SubqueryPoolsInfoData: Decodable {
    let poolXYKEntities: SubqueryPoolXykEnties
}

struct SubqueryPoolXykEnties: Decodable {
    let nodes: [SubqueryPoolInfoNode]
}

struct SubqueryPoolInfoNode: Decodable {
    let pools: SubqueryPoolInfoPool
}

struct SubqueryPoolInfoPool: Decodable {
    let edges: [SubqueryPoolInfoPoolEdge]
}

struct SubqueryPoolInfoPoolEdge: Decodable {
    let node: SubqueryPoolsInfoResponseData
}

struct SubqueryPoolsInfoResponseData: Decodable {
    let targetAssetId: String
    let priceUSD: String
    let strategicBonusApy: String
}
