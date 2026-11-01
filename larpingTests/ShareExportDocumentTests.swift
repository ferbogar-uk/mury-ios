import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import larping

@MainActor
final class ShareExportDocumentTests: XCTestCase {
    func testPNGPreservesPixelDimensionsAndTransparentPixel() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 6), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 1, y: 1, width: 2, height: 4))
        }

        let document = try ShareExportDocument(image: image)
        XCTAssertEqual(document.contentType, .png)
        let decoded = try XCTUnwrap(UIImage(data: document.data)?.cgImage)
        XCTAssertEqual(decoded.width, 8)
        XCTAssertEqual(decoded.height, 12)
        let corner = try XCTUnwrap(decoded.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(pixel[3], 0)
    }

    func testImageWithoutEncodablePixelsThrows() {
        XCTAssertThrowsError(try ShareExportDocument(image: UIImage()))
    }

    func testVideoOwnsBytesAfterSourceDeletion() throws {
        let url = temporaryVideoURL()
        defer { try? FileManager.default.removeItem(at: url) }
        // This fixture proves byte ownership, not MP4 validity or playback.
        let bytes = Data([0, 1, 2, 3, 255])
        try bytes.write(to: url)
        let document = try ShareExportDocument(videoURL: url)
        try FileManager.default.removeItem(at: url)

        XCTAssertEqual(document.contentType, .mpeg4Movie)
        XCTAssertEqual(document.data, bytes)
    }

    func testMissingVideoSourceThrows() {
        XCTAssertThrowsError(try ShareExportDocument(videoURL: temporaryVideoURL()))
    }

    func testEmptyVideoSourceThrows() throws {
        let url = temporaryVideoURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data().write(to: url)
        XCTAssertThrowsError(try ShareExportDocument(videoURL: url))
    }

    func testPNGSharingAndClipboardPreserveAlphaAndBytes() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 1, y: 1, width: 2, height: 2))
        }
        let png = try SharePNG(image: image)
        let document = try ShareExportDocument(image: image)
        XCTAssertEqual(png.data, document.data)
        XCTAssertEqual(Array(png.data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        png.copyToPasteboard()
        XCTAssertEqual(UIPasteboard.general.data(forPasteboardType: UTType.png.identifier), png.data)
        XCTAssertThrowsError(try SharePNG(image: UIImage()))
    }

    private func temporaryVideoURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("mury-export-test-\(UUID().uuidString).mp4")
    }
}
