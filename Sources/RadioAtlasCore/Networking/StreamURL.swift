import Foundation

public enum StreamURL {
    /// The same stream over TLS, or `nil` when the URL is not cleartext http
    /// and so has nothing to upgrade.
    ///
    /// Some directory entries name a port that only speaks TLS while listing
    /// the URL as `http`. The server then answers "The plain HTTP request was
    /// sent to HTTPS port" and playback fails with the resource reported as
    /// unavailable. Browsers never expose this, because they auto-upgrade
    /// http to https, which is why such a station plays on the Radio Browser
    /// website and not in a native player.
    ///
    /// Returning `nil` for anything already secure is what stops the caller's
    /// retry from running a second time.
    public static func tlsUpgraded(_ url: URL) -> URL? {
        guard url.scheme?.lowercased() == "http" else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }
}
