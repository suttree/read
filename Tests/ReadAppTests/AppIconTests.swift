import AppKit
import XCTest
@testable import ReadApp

final class AppIconTests: XCTestCase {
    func testAppearanceChangesInkAndPreservesTransparency() throws {
        let light = try bitmap(for: .aqua)
        let dark = try bitmap(for: .darkAqua)
        var opaquePixels = 0
        for y in 0..<light.pixelsHigh {
            for x in 0..<light.pixelsWide {
                let lightColor = try XCTUnwrap(light.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let darkColor = try XCTUnwrap(dark.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                XCTAssertEqual(lightColor.alphaComponent, darkColor.alphaComponent, accuracy: 0.01)
                if lightColor.alphaComponent > 0.9 {
                    opaquePixels += 1
                    for value in [lightColor.redComponent, lightColor.greenComponent, lightColor.blueComponent] {
                        XCTAssertLessThan(value, 0.05)
                    }
                    for value in [darkColor.redComponent, darkColor.greenComponent, darkColor.blueComponent] {
                        XCTAssertGreaterThan(value, 0.95)
                    }
                }
            }
        }
        XCTAssertGreaterThan(opaquePixels, 20)
    }

    private func bitmap(for appearanceName: NSAppearance.Name) throws -> NSBitmapImageRep {
        let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
        let image = try XCTUnwrap(AppIconTheming.themedIcon(.standard, size: 64, appearance: appearance))
        return try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
    }

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
