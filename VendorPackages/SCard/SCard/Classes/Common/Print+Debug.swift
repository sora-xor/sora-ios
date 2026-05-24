func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if F_STAGING || F_RELEASE
    return
    #elseif DEBUG || F_DEV || F_TEST
    Swift.print(items, separator: separator, terminator: terminator)
    #else /// local runs
    Swift.print(items, separator: separator, terminator: terminator)
    #endif
}
