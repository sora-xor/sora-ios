import Foundation

protocol InvitationFactoryProtocol {
    func createInvitation(for code: String, enviroment: RemoteEnviroment, locale: Locale?) -> String
    func createInvitationLink(for code: String, enviroment: RemoteEnviroment) -> URL
}

extension InvitationFactoryProtocol {
    func createInvitation(from code: String, locale: Locale?) -> String {
        #if F_DEV
        return createInvitation(for: code, enviroment: .development, locale: locale)
        #elseif F_TEST
        return createInvitation(for: code, enviroment: .test, locale: locale)
        #elseif F_STAGING
        return createInvitation(for: code, enviroment: .staging, locale: locale)
        #else
        return createInvitation(for: code, enviroment: .release, locale: locale)
        #endif
    }
}

struct InvitationFactory: InvitationFactoryProtocol {
    let host: URL

    func createInvitationLink(for code: String, enviroment: RemoteEnviroment) -> URL {
        var url = host

        if !enviroment.rawValue.isEmpty {
            url = url.appendingPathComponent(enviroment.rawValue)
        }

        return url//.appendingPathComponent("/join/\(code)")
    }

    func createInvitation(for code: String, enviroment: RemoteEnviroment, locale: Locale?) -> String {
        let url = createInvitationLink(for: code, enviroment: enviroment)
        return R.string.localizable.inviteLinkFormat(url.absoluteString,
                                                     preferredLanguages: locale?.rLanguages)
    }
}
