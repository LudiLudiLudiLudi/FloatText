import Foundation

/// Visible build marker shown in the UI for debug verification.
/// Update this constant when committing to confirm the running build
/// matches the source. Temporary — remove once MVP stabilization is done.
enum BuildInfo {
    static let shortHash: String = "DEBUG-NEW"
}
