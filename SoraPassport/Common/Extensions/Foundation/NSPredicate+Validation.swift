import Foundation

extension NSPredicate {
    static var email: NSPredicate {
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailFormat)
    }

    static var phone: NSPredicate {
        let phoneFormat = "\\+?[1-9][0-9]{3,14}"
        return NSPredicate(format: "SELF MATCHES %@", phoneFormat)
    }

    static var phoneCode: NSPredicate {
        let format = "[0-9]{4}"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }

    static var empty: NSPredicate {
        return NSPredicate(format: "SELF = ''")
    }

    static var notEmpty: NSPredicate {
        return NSPredicate(format: "SELF != ''")
    }

    static var personName: NSPredicate {
        let format = "\\p{L}([\\s'\\-]*\\p{L})*"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }

    static var invitationCode: NSPredicate {
        return NSPredicate(format: "SELF MATCHES %@", String.invitationCodePattern)
    }

    static var ethereumAddress: NSPredicate {
        let format = "0x[A-Fa-f0-9]{40}"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
