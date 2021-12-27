@testable import SwiftGrayscalePNGPacker
import XCTest

final class SwiftGrayscalePNGPackerTests: XCTestCase {

    func testFixtures12() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        let blackImageURL = Bundle.module.url(forResource: "Fixtures/1", withExtension: "jpg")!
        let whiteImageURL = Bundle.module.url(forResource: "Fixtures/2", withExtension: "jpg")!
        let desiredImageURL = Bundle.module.url(forResource: "Fixtures/1_2", withExtension: "png")!
        let desiredImageData = try Data(contentsOf: desiredImageURL)
        let outputURL = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: blackImageURL,
            create: true
        ).appendingPathComponent("output.png")
        print(outputURL)
        try SwiftGrayscalePNGPacker().pack(
            blackImageURL: blackImageURL,
            whiteImageURL: whiteImageURL,
            outputURL: outputURL
        )
        let outputData = try Data(contentsOf: outputURL)
        XCTAssert(desiredImageData == outputData)
    }

    func testFixtures34() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        let blackImageURL = Bundle.module.url(forResource: "Fixtures/3", withExtension: "jpg")!
        let whiteImageURL = Bundle.module.url(forResource: "Fixtures/4", withExtension: "png")!
        let desiredImageURL = Bundle.module.url(forResource: "Fixtures/3_4", withExtension: "png")!
        let desiredImageData = try Data(contentsOf: desiredImageURL)
        let outputURL = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: blackImageURL,
            create: true
        ).appendingPathComponent("output.png")
        print(outputURL)
        try SwiftGrayscalePNGPacker().pack(
            blackImageURL: blackImageURL,
            whiteImageURL: whiteImageURL,
            outputURL: outputURL
        )
        let outputData = try Data(contentsOf: outputURL)
        XCTAssert(desiredImageData == outputData)
    }
}
