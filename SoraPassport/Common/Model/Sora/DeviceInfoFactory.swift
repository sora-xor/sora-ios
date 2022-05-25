import UIKit

protocol DeviceInfoFactoryProtocol {
    func createDeviceInfo() -> DeviceInfo
}

struct DeviceInfoFactory: DeviceInfoFactoryProtocol {
    func createDeviceInfo() -> DeviceInfo {
        let screen = UIScreen.main
        let device = UIDevice.current
        let locale = Locale.current
        let timezone = TimeZone.current

        return DeviceInfo(model: device.model,
                          osVersion: device.systemVersion,
                          screenWidth: Int(screen.bounds.width),
                          screenHeight: Int(screen.bounds.height),
                          language: locale.languageCode ?? "",
                          country: locale.regionCode ?? "",
                          timezone: timezone.secondsFromGMT() / 3600)
    }
}
