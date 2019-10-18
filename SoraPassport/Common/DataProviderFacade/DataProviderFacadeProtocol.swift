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
    var votesProvider: SingleValueProvider<VotesData, CDSingleValue> { get }
    var userProvider: SingleValueProvider<UserData, CDSingleValue> { get }
    var friendsDataProvider: SingleValueProvider<ActivatedInvitationsData, CDSingleValue> { get }
    var reputationDataProvider: SingleValueProvider<ReputationData, CDSingleValue> { get }
}

protocol ProjectDataProviderFacadeProtocol: DataProviderFacadeProtocol {
    var pageSize: UInt { get }

    var allProjectsProvider: DataProvider<ProjectData, CDProject> { get }
    var favoriteProjectsProvider: DataProvider<ProjectData, CDProject> { get }
    var votedProjectsProvider: DataProvider<ProjectData, CDProject> { get }
}

protocol InformationDataProviderFacadeProtocol: DataProviderFacadeProtocol {
    var announcementDataProvider: SingleValueProvider<AnnouncementData?, CDSingleValue> { get }
    var helpDataProvider: SingleValueProvider<HelpData, CDSingleValue> { get }
    var reputationDetailsProvider: SingleValueProvider<ReputationDetailsData, CDSingleValue> { get }
    var currencyDataProvider: SingleValueProvider<CurrencyData, CDSingleValue> { get }
    var countryDataProvider: SingleValueProvider<CountryData, CDSingleValue> { get }
}

protocol SettingsDataProviderFacadeProtocol: DataProviderFacadeProtocol {
    var selectedCurrencyDataProvider: SelectedCurrencyDataProvider { get }
}
