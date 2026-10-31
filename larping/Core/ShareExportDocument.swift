import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Owns export bytes so temporary video cleanup cannot invalidate a Files save.
struct ShareExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .mpeg4Movie] }

    let data: Data
    let contentType: UTType

    init(image: UIImage) throws {
        guard let data = image.pngData(), !data.isEmpty else {
            throw ExportError.imageEncodingFailed
        }
        self.data = data
        contentType = .png
    }

    init(videoURL: URL) throws {
        let data = try Data(contentsOf: videoURL)
        guard !data.isEmpty else { throw ExportError.emptyFile }
        self.data = data
        contentType = .mpeg4Movie
    }

    init(configuration: ReadConfiguration) throws {
        guard Self.readableContentTypes.contains(configuration.contentType),
              let data = configuration.file.regularFileContents,
              !data.isEmpty else { throw ExportError.emptyFile }
        self.data = data
        contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    private enum ExportError: LocalizedError {
        case imageEncodingFailed
        case emptyFile

        var errorDescription: String? {
            switch self {
            case .imageEncodingFailed: return "The image couldn't be prepared. Please try again."
            case .emptyFile: return "The export file is empty or unreadable. Please try again."
            }
        }
    }
}
