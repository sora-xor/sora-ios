import Foundation
import SoraFoundation

protocol ReferendumViewModelFactoryProtocol: DynamicProjectViewModelFactoryProtocol {
    func create(from referendum: ReferendumData,
                layoutMetadata: ReferendumLayoutMetadata,
                delegate: ReferendumViewModelDelegate,
                locale: Locale) -> ReferendumViewModel

    func createDetails(from referendum: ReferendumData, locale: Locale) -> ReferendumDetailsViewModelProtocol
}

final class ReferendumViewModelFactory {
    private(set) var votesFormatter: LocalizableResource<NumberFormatter>
    private(set) var integerFormatter: LocalizableResource<NumberFormatter>
    private(set) var dateFormatterProvider: DateFormatterProviderProtocol

    weak var delegate: ProjectViewModelFactoryDelegate?

    init(votesFormatter: LocalizableResource<NumberFormatter>,
         integerFormatter: LocalizableResource<NumberFormatter>,
         dateFormatterProvider: DateFormatterProviderProtocol) {
        self.votesFormatter = votesFormatter
        self.integerFormatter = integerFormatter
        self.dateFormatterProvider = dateFormatterProvider

        dateFormatterProvider.delegate = self
    }

    private func convertClosed(timestamp: Int64, locale: Locale) -> String {
        let fundingDeadline = Date(timeIntervalSince1970: TimeInterval(timestamp))

        if fundingDeadline.compare(Date()) != .orderedDescending {
            let dateFormatter = dateFormatterProvider.dateFormatter.value(for: locale)
            return dateFormatter.string(from: fundingDeadline)
        } else {
            return ""
        }
    }

    private func createTotalVotes(from referendum: ReferendumData, locale: Locale) -> String? {
        let supportVotes = Decimal(string: referendum.supportVotes) ?? 0.0
        let unsupportVotes = Decimal(string: referendum.opposeVotes) ?? 0.0

        let totalVotes = supportVotes + unsupportVotes

        if totalVotes > 0.0 {
            return votesFormatter.value(for: locale).string(from: totalVotes as NSNumber)
        } else {
            return nil
        }
    }

    private func formatVotes(from votesString: String, locale: Locale) -> String {
        let votes = Decimal(string: votesString) ?? 0.0
        return votesFormatter.value(for: locale).string(from: votes as NSNumber) ?? votesString
    }

    private func createVotingProgress(from supportVotesString: String,
                                      unsupportVotesString: String) -> Float {
        let supportVotes = Decimal(string: supportVotesString) ?? 0.0
        let unsupportVotes = Decimal(string: unsupportVotesString) ?? 0.0

        if supportVotes + unsupportVotes > 0.0 {
            let progress = supportVotes / (supportVotes + unsupportVotes)
            return (progress as NSNumber).floatValue
        } else {
            return 0.5
        }
    }

    private func createContent(from referendum: ReferendumData, locale: Locale) -> ReferendumContent {
        ReferendumContent {
            $0.title = referendum.name
            $0.details = referendum.shortDescription

            let finished = referendum.status != .open
            $0.finished = finished

            if finished {
                $0.remainedTimeDetails = convertClosed(timestamp: referendum.fundingDeadline, locale: locale)
            } else {
                $0.remainedTimeDetails = nil
            }

            $0.votingProgress = createVotingProgress(from: referendum.supportVotes,
                                                     unsupportVotesString: referendum.opposeVotes)

            $0.supportingVotes = formatVotes(from: referendum.supportVotes, locale: locale)
            $0.unsupportingVotes = formatVotes(from: referendum.opposeVotes, locale: locale)
        }
    }
}

extension ReferendumViewModelFactory: ReferendumViewModelFactoryProtocol {
    func create(from referendum: ReferendumData,
                layoutMetadata: ReferendumLayoutMetadata,
                delegate: ReferendumViewModelDelegate,
                locale: Locale) -> ReferendumViewModel {
        let content = createContent(from: referendum, locale: locale)

        let layout = createLayout(from: content,
                                  layoutMetadata: layoutMetadata)

        let timerViewModel: TimerViewModelProtocol?

        if !content.finished {
            let deadline = Date(timeIntervalSince1970: TimeInterval(referendum.fundingDeadline))
            timerViewModel = ReferendumTimerViewModel(deadline: deadline,
                                                      timeFormatter: TotalTimeFormatter())
        } else {
            timerViewModel = nil
        }

        let viewModel = ReferendumViewModel(identifier: referendum.identifier,
                                            content: content,
                                            layout: layout,
                                            remainedTimeViewModel: timerViewModel,
                                            imageViewModel: nil)
        viewModel.delegate = delegate

        if let imageLink = referendum.imageLink {
            viewModel.imageViewModel = ImageViewModel(url: imageLink)
            viewModel.imageViewModel?.cornerRadius = layoutMetadata.cornerRadius
            viewModel.imageViewModel?.targetSize = layout.imageSize
        }

        return viewModel
    }

    func createDetails(from referendum: ReferendumData, locale: Locale) -> ReferendumDetailsViewModelProtocol {
        let remainedTimeDetails: String?
        let finished = referendum.status != .open

        if finished {
            remainedTimeDetails = convertClosed(timestamp: referendum.fundingDeadline, locale: locale)
        } else {
            remainedTimeDetails = nil
        }

        let votingProgress = createVotingProgress(from: referendum.supportVotes,
                                                  unsupportVotesString: referendum.opposeVotes)

        let totalVotes = createTotalVotes(from: referendum, locale: locale)

        let supportVotes = formatVotes(from: referendum.supportVotes, locale: locale)
        let unsupportVotes = formatVotes(from: referendum.opposeVotes, locale: locale)

        let mySupportVotes = formatVotes(from: referendum.userSupportVotes, locale: locale)
        let myUnsupportVotes = formatVotes(from: referendum.userOpposeVotes, locale: locale)

        let content = ReferendumDetailsContent(title: referendum.name,
                                               details: referendum.detailedDescription,
                                               remainedTimeDetails: remainedTimeDetails,
                                               status: referendum.status,
                                               votingProgress: votingProgress,
                                               totalVotes: totalVotes,
                                               supportingVotes: supportVotes,
                                               unsupportingVotes: unsupportVotes,
                                               mySupportingVotes: mySupportVotes,
                                               myUnsupportingVotes: myUnsupportVotes)

        let timerViewModel: TimerViewModelProtocol?

        if !content.finished {
            let deadline = Date(timeIntervalSince1970: TimeInterval(referendum.fundingDeadline))
            timerViewModel = ReferendumTimerViewModel(deadline: deadline,
                                                      timeFormatter: TotalTimeFormatter())
        } else {
            timerViewModel = nil
        }

        let imageViewModel: ImageViewModelProtocol?

        if let imageLink = referendum.imageLink {
            imageViewModel = ImageViewModel(url: imageLink)
        } else {
            imageViewModel = nil
        }

        return ReferendumDetailsViewModel(content: content,
                                          remainedTimeViewModel: timerViewModel,
                                          mainImageViewModel: imageViewModel)
    }
}

extension ReferendumViewModelFactory: DateFormatterProviderDelegate {
    func providerDidChangeDateFormatter(_ provider: DateFormatterProviderProtocol) {
        delegate?.projectFactoryDidChange(self)
    }
}

extension ReferendumViewModelFactory {
    static func createDefault() -> ReferendumViewModelFactoryProtocol {
        let votesFormatter = NumberFormatter.vote.localizableResource()
        let integerFormatter = NumberFormatter.anyInteger.localizableResource()

        let dateFormatterFactory = FinishedProjectDateFormatterFactory.self
        let dateFormatterProvider = DateFormatterProvider(dateFormatterFactory: dateFormatterFactory,
                                                          dayChangeHandler: DayChangeHandler())

        return ReferendumViewModelFactory(votesFormatter: votesFormatter,
                                          integerFormatter: integerFormatter,
                                          dateFormatterProvider: dateFormatterProvider)
    }
}
