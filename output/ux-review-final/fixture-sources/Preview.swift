import UIKit
import BigInt
import SoraUIKit
final class LocalizationManager { static let shared = LocalizationManager(); let selectedLocalization = "en" }
struct PIQuantity { let rawValue: String }
struct TransferRequest { let amount: PIQuantity }
struct Quote { let fee: PIQuantity }
struct NexusPreparedTransfer { let request: TransferRequest; let canonicalReceiver: String; let quote: Quote; var availableBalance: PIQuantity { PIQuantity(rawValue:"125.25") } }
enum NexusAmountPolicy { static let maximumScale = 255 }
enum NexusToriiError: Error { case insufficientBalance,quoteChanged,quoteExpired,wrongWalletOrNetwork,ambiguousSubmission,confirmationAlreadySubmitted,transactionHashMismatch,sendsDisabled,nativeBridgeUnavailable,finalizedHeadUnavailable,other }
enum NexusPendingState { case signing,failedBeforeSubmission,submitting,submissionUnknown,submitted,approved,committedPendingReconciliation,committed,rejected,expired }
struct NexusPendingTransaction { let state: NexusPendingState; let hash: String? }
struct NexusExactDecimal: Comparable {
    let unscaled: BigInt
    let scale: Int

    init?(_ value: String) {
        guard
            !value.isEmpty,
            value.range(
                of: #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$"#,
                options: .regularExpression
            ) != nil
        else {
            return nil
        }
        let isNegative = value.first == "-"
        let unsigned = isNegative ? String(value.dropFirst()) : value
        let components = unsigned.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let integer = String(components[0])
        let fraction = components.count == 2 ? String(components[1]) : ""
        guard
            fraction.count <= NexusAmountPolicy.maximumScale,
            var unscaled = BigInt(integer + fraction)
        else {
            return nil
        }
        if isNegative {
            unscaled = -unscaled
        }
        self.unscaled = unscaled
        scale = fraction.count
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        let scale = max(lhs.scale, rhs.scale)
        let lhsValue = lhs.unscaled * powerOfTen(scale - lhs.scale)
        let rhsValue = rhs.unscaled * powerOfTen(scale - rhs.scale)
        return Self(unscaled: lhsValue + rhsValue, scale: scale)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let scale = max(lhs.scale, rhs.scale)
        return lhs.unscaled * powerOfTen(scale - lhs.scale) <
            rhs.unscaled * powerOfTen(scale - rhs.scale)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        let scale = max(lhs.scale, rhs.scale)
        return lhs.unscaled * powerOfTen(scale - lhs.scale) ==
            rhs.unscaled * powerOfTen(scale - rhs.scale)
    }

    private init(unscaled: BigInt, scale: Int) {
        self.unscaled = unscaled
        self.scale = scale
    }

    private static func powerOfTen(_ exponent: Int) -> BigInt {
        guard exponent > 0 else {
            return 1
        }
        return BigInt(10).power(exponent)
    }
}


@main final class App: UIResponder, UIApplicationDelegate {
 var window: UIWindow?
 func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
 func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey:Any]?) -> Bool {
  let args = ProcessInfo.processInfo.arguments
  SoramitsuUI.shared.themeMode = .manual(args.contains("dark") ? .dark : .light)
  let win=UIWindow(frame: UIScreen.main.bounds)
  let send=NexusSendViewController(network:"Taira · TESTNET",balance:"125.25")
  let nav=UINavigationController(rootViewController:send)
  win.rootViewController=nav; window=win; win.makeKeyAndVisible(); send.loadViewIfNeeded()
  if args.contains("connect") {
   let connect=IrohaConnectViewController(launch:IrohaConnectLaunch(),account:IrohaConnectWalletContext(accountId:"Sample account · sora1qz8u5nv6z8qg46slkg598lh8vlcmy725ygpwmy47deer9qsjkjpn3gnlw"),walletProvider:IrohaConnectWalletProvider())
   connect.prepareVisualFixture(blocked:args.contains("blocked"))
   win.rootViewController=connect
   if args.contains("bottom") { DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { if let scroll=connect.view.subviews.first(where:{$0 is UIScrollView}) as? UIScrollView { scroll.layoutIfNeeded();scroll.setContentOffset(CGPoint(x:0,y:max(0,scroll.contentSize.height-scroll.bounds.height)),animated:false) } } }
   return true
  }
  if args.contains("chart") {
   let chart = PolkamarktLineChartView(frame:.zero)
   chart.caption="Yes probability history"
   chart.context="From 30% at 4 Sep 2026, 10:00 to 65% at 5 Sep 2026, 10:00. Vertical scale: 0% to 100%. Snapshots run from oldest to newest at equal spacing."
   chart.values=[0.3,0.45,0.4,0.52,0.65]
   let page=UIViewController(); page.view.backgroundColor=WalletUX.page
   let scroll=UIScrollView(frame:win.bounds); scroll.autoresizingMask=[.flexibleWidth,.flexibleHeight]
   page.view.addSubview(scroll); scroll.addSubview(chart)
   chart.frame.size=chart.sizeThatFits(CGSize(width:win.bounds.width,height:10000))
   scroll.contentSize=chart.frame.size
   win.rootViewController=page
   if args.contains("bottom") { DispatchQueue.main.asyncAfter(deadline:.now()+0.3) { scroll.setContentOffset(CGPoint(x:0,y:max(0,scroll.contentSize.height-scroll.bounds.height)),animated:false) } }
   return true
  }
  let address="sora1qz8u5nv6z8qg46slkg598lh8vlcmy725ygpwmy47deer9qsjkjpn3gnlwpeyxh2e8q3gg8xh2w5xrwgqmfcsqk3kwcclfnmwja7nph43ydfm6jjm"
  if args.contains("review") {
   send.showReview(NexusPreparedTransfer(request:TransferRequest(amount:PIQuantity(rawValue:"12.5")),canonicalReceiver:address,quote:Quote(fee:PIQuantity(rawValue:"0.01"))))
  }
  if args.contains("uncertain") { send.showUncertainSubmission(WalletUX.sendError(NexusToriiError.ambiguousSubmission)) }
  if args.contains("completed") { send.showResult(NexusPendingTransaction(state:.committed,hash:"0123456789abcdef")) }
  DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
   if args.contains("paste") {
    UIPasteboard.general.string=address
    self.descendants(send.view).compactMap{$0 as? UIButton}.first{$0.configuration?.title=="Paste address"}?.sendActions(for:.touchUpInside)
   }
   if args.contains("keyboard") {
    self.descendants(send.view).compactMap{$0 as? UITextField}.first?.becomeFirstResponder()
   }
   if args.contains("scan") {
    self.descendants(send.view).compactMap{$0 as? UIButton}.first{$0.configuration?.title=="Scan QR"}?.sendActions(for:.touchUpInside)
   }
   if args.contains("bottom") {
    DispatchQueue.main.asyncAfter(deadline:.now()+0.7) {
     if let scroll=send.view.subviews.first(where:{$0 is UIScrollView}) as? UIScrollView { scroll.layoutIfNeeded();scroll.setContentOffset(CGPoint(x:0,y:max(0,scroll.contentSize.height-scroll.bounds.height)),animated:false) }
    }
   }
  }
  return true
 }
}
