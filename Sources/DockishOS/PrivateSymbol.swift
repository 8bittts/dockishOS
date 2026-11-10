import Darwin

/// Resolves a private system function at run time. A macOS release that drops
/// the symbol then turns one feature off, where a link-time reference would
/// stop the app from launching. `type` must be the function's `@convention(c)` type.
func privateSymbol<Function>(_ name: String, as type: Function.Type) -> Function? {
    let allLoadedImages = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
    guard let symbol = dlsym(allLoadedImages, name) else { return nil }
    return unsafeBitCast(symbol, to: type)
}
