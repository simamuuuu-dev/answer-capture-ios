import Foundation

public struct CapturedPageData: Sendable {
    public let jpeg: Data
    public let width: Int
    public let height: Int

    public init(jpeg: Data, width: Int, height: Int) {
        self.jpeg = jpeg
        self.width = width
        self.height = height
    }
}

public enum ScanRepositoryError: Error, Sendable {
    case emptyCapture
    case invalidPageMetadata
    case unsafeFileName
}

public actor ScanRepository {
    public let root: URL
    private let fileManager: FileManager

    public init(root: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.root = root ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("AnswerCapture", isDirectory: true)
    }

    public func saveCapturedPages(
        _ pages: [CapturedPageData],
        captureId: String = CaptureID.make(),
        createdAt: Date = Date(),
        storageMode: StorageMode = .appSandboxOrDocumentPicker
    ) throws -> ScanRecord {
        guard !pages.isEmpty else { throw ScanRepositoryError.emptyCapture }
        let records = pages.enumerated().map { offset, page in
            let index = offset + 1
            let fileName = String(format: "%@_p%03d.jpg", captureId, index)
            return ScanPage(
                index: index,
                fileName: fileName,
                relativePath: "AnswerCapture/\(captureId)/\(fileName)",
                width: page.width,
                height: page.height,
                sizeBytes: page.jpeg.count,
                sha256: CaptureID.sha256(page.jpeg)
            )
        }
        let scan = ScanRecord(
            id: captureId,
            createdAt: createdAt,
            storageMode: storageMode,
            pages: records
        )
        let images = zip(records, pages).map { pair in
            (page: pair.0, data: pair.1.jpeg)
        }
        return try save(scan: scan, images: images)
    }

    public func save(scan: ScanRecord, images: [(page: ScanPage, data: Data)]) throws -> ScanRecord {
        guard !images.isEmpty, scan.pages.count == images.count else {
            throw ScanRepositoryError.invalidPageMetadata
        }
        let expectedIndices = Array(1 ... images.count)
        guard images.map({ $0.page.index }) == expectedIndices else {
            throw ScanRepositoryError.invalidPageMetadata
        }
        for item in images {
            guard item.page.fileName == URL(fileURLWithPath: item.page.fileName).lastPathComponent,
                  item.page.sizeBytes == item.data.count,
                  item.page.sha256 == CaptureID.sha256(item.data) else {
                throw ScanRepositoryError.unsafeFileName
            }
        }

        let folder = root.appendingPathComponent(scan.id, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for item in images {
            try AtomicFile.write(
                item.data,
                to: folder.appendingPathComponent(item.page.fileName),
                fileManager: fileManager
            )
        }
        try AtomicFile.write(
            try WireCoding.encoder.encode(scan),
            to: folder.appendingPathComponent("scan.json"),
            fileManager: fileManager
        )
        let row = try WireCoding.encoder.encode(ManifestRecord(scan: scan)) + Data("\n".utf8)
        let manifestURL = root.appendingPathComponent("manifest.jsonl")
        let previous = fileManager.fileExists(atPath: manifestURL.path)
            ? try Data(contentsOf: manifestURL)
            : Data()
        try AtomicFile.write(previous + row, to: manifestURL, fileManager: fileManager)
        return scan
    }
}
