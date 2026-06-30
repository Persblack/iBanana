import AppKit

/// Copies a value and optionally clears the pasteboard after a delay — but only
/// if it still holds the same value (don't clobber what the user copied since).
enum Clipboard {
    static func copy(_ value: String, clearAfter seconds: TimeInterval?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)

        guard let seconds, seconds > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if NSPasteboard.general.string(forType: .string) == value {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
