import Foundation

public final class XOneViewModel {

    // var onDone: (() -> Void)?

    private let service: KYCService
    private let paymentId = UUID().uuidString
    private let address: String
    private var dataToBlockchain = "TXOR"

    public init(address: String, service: KYCService) {
        self.address = address
        self.service = service

        #if F_DEV
        dataToBlockchain = "TXOR"
        #elseif F_TEST
        dataToBlockchain = "TXOR"
        #elseif F_STAGING
        dataToBlockchain = "XOR"
        #endif
    }

    func checkStatus() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
            guard let self = self else { return }
            Task {
                let result = await self.service.xOneStatus(paymentId: self.paymentId)
                switch result {
                case .failure(let error):
                    print(error)

                case .success(let response):
                    if response.userStatus == .successful {
                        // self.onDone?()
                    } else {
                        self.checkStatus()
                    }
                }
            }
        }
    }

    var xOneHtmlString: String {
        """
        <!DOCTYPE html>
        <html lang="en">

        <head>
          <meta name="description" content="" />
          <meta charset="utf-8">
          <title>x1ex</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="author" content="">
          <link rel="stylesheet" href="css/style.css">
        </head>

        <body>
        <div
            id="\(service.config.xOneId)"
            data-from-currency="EUR"

            data-from-amount="\(100)"
            data-hide-buy-more-button="true"
            data-hide-try-again-button="false"
            data-disable-to-blockchain="true"
            data-locale="en"
            data-payload="\(paymentId)"
            data-address="\(address)"
            data-to-blockchain="\(dataToBlockchain)"
        ></div>
        <script async src="\(service.config.xOneEndpoint)"></script>

        </body>
        </html>
        """
    }
}
