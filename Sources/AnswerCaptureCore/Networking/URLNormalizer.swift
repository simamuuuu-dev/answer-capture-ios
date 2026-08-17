import Foundation

public enum URLNormalizationError: Error, Sendable {
    case invalidScheme
    case missingHost
    case invalidURL
}

public enum URLNormalizer {
    public static func normalize(_ raw: String) throws -> URL {
        let value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: value) else {
            throw URLNormalizationError.invalidURL
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw URLNormalizationError.invalidScheme
        }
        guard url.host != nil else {
            throw URLNormalizationError.missingHost
        }
        return url
    }

    public static func endpoint(
        base: URL,
        path: String,
        query: [URLQueryItem] = []
    ) -> URL {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var url = base.appendingPathComponent(cleanPath)
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query
            url = components?.url ?? url
        }
        return url
    }
}
