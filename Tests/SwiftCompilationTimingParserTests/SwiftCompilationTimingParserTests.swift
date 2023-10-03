/*
 MIT License

 Copyright (c) 2023 Qonto

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

@testable import SwiftCompilationTimingParser
import XCTest
final class SwiftCompilationTimingParserTests: XCTestCase {
    func test_whenNoInputProvided_thenShouldThrowAnError() async throws {
        // GIVEN
        let command = try XCTUnwrap(
            SwiftCompilationTimingParser.parseAsRoot([
                "--root-path",
                "",
                "--target-name",
                "",
                "--threshold",
                "0",
                "--output-path",
                ""
            ]) as? SwiftCompilationTimingParser
        )
        // WHEN
        var caughtError: Error?
        do {
            try await command.run()
        } catch {
            caughtError = error
        }
        // THEN
        XCTAssertNotNil(caughtError)
    }

    func test_whenOnlyDerivedDataPathIsSet_thenShouldThrowFileNotFoundError() async throws {
        // GIVEN
        let command = try XCTUnwrap(
            SwiftCompilationTimingParser.parseAsRoot([
                "--derived-data-path",
                "",
                "--root-path",
                "",
                "--target-name",
                "",
                "--threshold",
                "0",
                "--output-path",
                ""
            ]) as? SwiftCompilationTimingParser
        )
        // WHEN
        var caughtError: NSError?
        do {
            try await command.run()
        } catch let error as NSError {
            caughtError = error
        }
        // THEN
        XCTAssertEqual(caughtError?.domain, "NSCocoaErrorDomain")
        XCTAssertEqual(caughtError?.code, 260)
    }

    func test_whenOnlyXcodebuildLogPathIsSet_thenShouldThrowFileNotFoundError() async throws {
        // GIVEN
        let command = try XCTUnwrap(
            SwiftCompilationTimingParser.parseAsRoot([
                "--xcodebuild-log-path",
                "",
                "--root-path",
                "",
                "--target-name",
                "",
                "--threshold",
                "0",
                "--output-path",
                ""
            ]) as? SwiftCompilationTimingParser
        )
        // WHEN
        var caughtError: NSError?
        do {
            try await command.run()
        } catch let error as NSError {
            caughtError = error
        }
        // THEN
        XCTAssertEqual(caughtError?.domain, "NSCocoaErrorDomain")
        XCTAssertEqual(caughtError?.code, 256)
    }

    func test_whenWhenGroupingSet_thenShouldEnableGroupingIsTrue() async throws {
        // GIVEN
        let command = try XCTUnwrap(
            SwiftCompilationTimingParser.parseAsRoot([
                "--root-path",
                "",
                "--target-name",
                "",
                "--threshold",
                "0",
                "--output-path",
                "",
                "--enable-grouping"
            ]) as? SwiftCompilationTimingParser
        )
        // WHEN
        // THEN
        XCTAssertTrue(command.shouldEnableGrouping)
    }

    func test_whenWhenIncludeInvalidLocSet_thenShouldIncludeInvalidLocIsTrue() async throws {
        // GIVEN
        let command = try XCTUnwrap(
            SwiftCompilationTimingParser.parseAsRoot([
                "--root-path",
                "",
                "--target-name",
                "",
                "--threshold",
                "0",
                "--output-path",
                "",
                "--include-invalid-loc"
            ]) as? SwiftCompilationTimingParser
        )
        // WHEN
        // THEN
        XCTAssertTrue(command.shouldIncludeInvalidLoc)
    }
}
