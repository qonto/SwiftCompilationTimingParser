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

import ArgumentParser
import Foundation
import SwiftCompilationTimingParserFramework

@main
struct SwiftCompilationTimingParser: AsyncParsableCommand {
    enum CodingKeys: CodingKey {
        case rootPath
        case derivedDataPath
        case targetName
        case threshold
        case shouldIncludeInvalidLoc
        case filteredPath
        case outputPath
        case xcactivityLogOutputPath
        case xcodebuildLogPath
        case shouldEnableGrouping
    }

    @Option(name: .customLong("root-path"), help: "Absolute path to the project's root folder. Used for filtering purpose to cut out the username and other non-relevant paths when logs are parsed")
    var rootPath: String

    @Option(name: .customLong("derived-data-path"), help: "Absolute path to DerivedData, where xcactivitylog will be searched")
    var derivedDataPath: String?

    @Option(name: .customLong("xcodebuild-log-path"), help: "Absolute path to a file with xcodebuild log output. If specified, `--derived-data-path` argument is ignored")
    var xcodebuildLogPath: String?

    @Option(name: .customLong("filtered-path"), help: "(Optional) Path which should be included during log filtering. If specified, this path is the only path that will appear in the results, other results will be omitted")
    var filteredPath: String?

    @Option(name: .customLong("target-name"), help: "Name of the target to be used for finding logs")
    var targetName: String

    @Option(name: .customLong("threshold"), help: "Threshold to be used for filtering symbol compilation duration")
    var threshold: Float

    @Option(name: .customLong("output-path"), help: "Path where the generated contents of parsed compilation duration will be stored")
    var outputPath: String

    @Option(name: .customLong("xcactivitylog-output-path"), help: "Path where the parsed xcactivitylog' JSON will be stored")
    var xcactivityLogOutputPath: String?

    @Flag(name: .customLong("include-invalid-loc"), help: "(Optional) If specified, symbols without a specific location (<invalid loc>) will be included in the results")
    var shouldIncludeInvalidLoc = false

    @Flag(name: .customLong("enable-grouping"), help: "(Optional) If specified, symbols are grouped by location and symbol before being written to `--output-path`")
    var shouldEnableGrouping = false

    func run() async throws {
        let configuration = SwiftCompilationTimingParserFramework.SwiftCompilationTimingParser.Configuration(xcactivityLogOutputPath: xcactivityLogOutputPath, outputPath: outputPath, threshold: threshold, targetName: targetName, filteredPath: filteredPath, xcodebuildLogPath: xcodebuildLogPath, derivedDataPath: derivedDataPath, rootPath: rootPath)
        try await SwiftCompilationTimingParserFramework.SwiftCompilationTimingParser(configuration: configuration).run()
    }
}
