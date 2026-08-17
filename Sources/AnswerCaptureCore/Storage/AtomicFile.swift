import Foundation

public enum AtomicFile {
    public static func write(_ data: Data, to url: URL, fileManager: FileManager = .default) throws { try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); let temp=url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp"); try data.write(to:temp,options:.atomic); if fileManager.fileExists(atPath:url.path) { _=try fileManager.replaceItemAt(url,withItemAt:temp) } else { try fileManager.moveItem(at:temp,to:url) } }
}
