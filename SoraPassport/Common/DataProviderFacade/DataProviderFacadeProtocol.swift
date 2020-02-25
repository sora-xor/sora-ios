/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

protocol DataProviderFacadeProtocol {
    var executionQueue: OperationQueue { get }
}

protocol CustomerDataProviderFacadeProtocol: DataProviderFacadeProtocol {
    var votesProvider: SingleValueProvider<VotesData> { get }
    var userProvider: SingleValueProvider<UserData> { get }
    var friendsDataProvider: SingleValueProvider<ActivatedInvitationsData> { get }
    var reputationDataProvider: SingleValueProvider<ReputationData> { get }
}

protocol ProjectDataProviderFacadeProtocol: DataProviderFacadeProtocol {
    var pageSize: UInt { get }

    var allProjectsProvider: DataProvider<ProjectData> { get }
    var favoriteProjectsProvider: DataProvider<ProjectData> { get }
    var votedProjectsProvider: DataProvider<ProjectData> { get }
}

protocol InformationDataProviderFacadeProtocol: DataProviderFacadeProtocol {
    var announcementDataProvider: SingleValueProvider<AnnouncementData> { get }
    var helpDataProvider: SingleValueProvider<HelpData> { get }
    var reputationDetailsProvider: SingleValueProvider<ReputationDetailsData> { get }
    var currencyDataProvider: SingleValueProvider<CurrencyData> { get }
    var countryDataProvider: SingleValueProvider<CountryData> { get }
}
