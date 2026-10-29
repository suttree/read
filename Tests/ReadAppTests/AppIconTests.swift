import AppKit
import XCTest
@testable import ReadApp

final class AppIconTests: XCTestCase {
    func testEveryThemeRendersVisibleArtwork() throws {
        for theme in ReaderTheme.all {
            let image = try XCTUnwrap(AppIconTheming.themedIcon(theme, size: 64), theme.id)
            let data = try XCTUnwrap(image.tiffRepresentation)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
            var visiblePixels = 0
            var clearPixels = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let alpha = try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent
                    if alpha > 0.1 { visiblePixels += 1 }
                    if alpha == 0 { clearPixels += 1 }
                }
            }
            XCTAssertGreaterThan(visiblePixels, 20, "Blank icon for \(theme.id)")
            XCTAssertGreaterThan(clearPixels, 20, "Missing transparent margin for \(theme.id)")
        }
    }
}
