import Foundation
import XCTest
import Files
import S3DeduplicationHelperCore
import class Foundation.Bundle

final class S3DeduplicationHelperTests: XCTestCase {

    func testCreatingFile() throws {
        // Setup a temp test folder that can be used as a sandbox
        let tempFolder = Folder.temporary
        let testFolder = try tempFolder.createSubfolderIfNeeded(
            withName: "CommandLineToolTests"
        )

        // Empty the test folder to ensure a clean state
        try testFolder.empty()

        // Make the temp folder the current working folder
        let fileManager = FileManager.default
        fileManager.changeCurrentDirectoryPath(testFolder.path)

        // Create an instance of the command line tool
        let arguments = [testFolder.path, "Hello.swift"]
        let tool = S3DeduplicationHelper(arguments: arguments)

        // Run the tool and assert that the file was created
        try tool.run()
        XCTAssertNotNil(try? testFolder.file(named: "Hello.swift"))
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }

    static var allTests = [
        ("testCreatingFile", testCreatingFile),
    ]
}
