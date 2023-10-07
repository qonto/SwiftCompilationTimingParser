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

import Foundation
import RegexBuilder
import XCLogParser

public class SwiftCompilationTimingParser {
    public enum Error: LocalizedError {
        case missingLogPath
    }

    enum ValidPrefixes: String, CaseIterable {
        case CompileSwift
        case SwiftCompile
        case SwiftEmitModule
    }

    enum InvalidPrefixes: String {
        case Cleaning
    }

    public struct Configuration {
        let shouldEnableGrouping = false
        let shouldIncludeInvalidLoc = false
        let xcactivityLogOutputPath: String?
        let outputPath: String
        let threshold: Float
        let targetName: String
        let filteredPath: String?
        let xcodebuildLogPath: String?
        let derivedDataPath: String?
        let rootPath: String

        public init(xcactivityLogOutputPath: String? = nil, outputPath: String, threshold: Float, targetName: String, filteredPath: String? = nil, xcodebuildLogPath: String? = nil, derivedDataPath: String? = nil, rootPath: String) {
            self.xcactivityLogOutputPath = xcactivityLogOutputPath
            self.outputPath = outputPath
            self.threshold = threshold
            self.targetName = targetName
            self.filteredPath = filteredPath
            self.xcodebuildLogPath = xcodebuildLogPath
            self.derivedDataPath = derivedDataPath
            self.rootPath = rootPath
        }
    }

    private var configuration: Configuration

    public init(configuration: SwiftCompilationTimingParser.Configuration) throws {
        self.configuration = configuration
    }

    public func run() async throws {
        var parsedTimings: [ParsedTiming]
        if let xcodebuildLogPath = configuration.xcodebuildLogPath, configuration.derivedDataPath == nil {
            let fileURL = URL(filePath: xcodebuildLogPath)
            let data = try Data(contentsOf: fileURL)
            parsedTimings = try processRawLog(log: data)
        } else if let derivedDataPath = configuration.derivedDataPath {
            var bestActivityLog: XCLogParser.IDEActivityLog?
            var ignoredActivityLogs: [String] = []
            repeat {
                let activityLog = try await findActivityLogs(derivedDataPath: derivedDataPath)
                if !activityLog.mainSection.signature.hasPrefix(InvalidPrefixes.Cleaning.rawValue) {
                    bestActivityLog = activityLog
                    break
                } else {
                    if ignoredActivityLogs.contains(activityLog.mainSection.uniqueIdentifier) {
                        // exit loop if iterations have started over, i.e. no "good log" file was found
                        break
                    }
                    ignoredActivityLogs.append(activityLog.mainSection.uniqueIdentifier)
                    let uuid = activityLog.mainSection.uniqueIdentifier
                    let filename = "\(uuid).xcactivitylog"
                    let path = "\(derivedDataPath)/\(configuration.targetName)/Logs/Build/\(filename)"
                    // Set modification date of the file to -3 months to avoid deleting the file and let LogFinder pick
                    // the newest most recent log
                    try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7.889399e+6)], ofItemAtPath: path)
                }
            } while bestActivityLog == nil
            if let bestActivityLog {
                parsedTimings = try await parseTimings(activityLog: bestActivityLog)
                try saveActivityLogIfNeeded(bestActivityLog)
            } else {
                return
            }
        } else { throw Error.missingLogPath }
        if configuration.shouldEnableGrouping {
            parsedTimings.group()
        }
        try saveFiles(parsedTimings: parsedTimings)
    }

    private func findActivityLogs(derivedDataPath: String) async throws -> XCLogParser.IDEActivityLog {
        let logPath = try XCLogParser.LogFinder().getLatestLogForProjectFolder(configuration.targetName, inDerivedData: URL(filePath: derivedDataPath))
        return try XCLogParser.ActivityParser().parseActivityLogInURL(URL(filePath: logPath), redacted: false, withoutBuildSpecificInformation: false)
    }

    private func parseTimings(activityLog: XCLogParser.IDEActivityLog) async throws -> [ParsedTiming] {
        var subSections = activityLog.mainSection.subSections
        subSections.append(contentsOf: subSections.flatMap { $0.subSections })
        return try await processSubSections(subSections: subSections)
    }

    private func saveFiles(parsedTimings: [ParsedTiming]) throws {
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(parsedTimings)
        try data.write(to: URL(filePath: configuration.outputPath))
    }

    private func saveActivityLogIfNeeded(_ activityLog: XCLogParser.IDEActivityLog) throws {
        guard let xcactivityLogOutputPath = configuration.xcactivityLogOutputPath else { return }
        let output = XCLogParser.FileOutput(path: xcactivityLogOutputPath)
        let logReporter = JsonReporter()
        let buildParser = ParserBuildSteps(
            machineName: nil,
            omitWarningsDetails: false,
            omitNotesDetails: true,
            truncLargeIssues: false
        )
        let buildSteps = try buildParser.parse(activityLog: activityLog)
        try logReporter.report(build: buildSteps, output: output, rootOutput: "")
    }

    private func processRawLog(log: Data) throws -> [ParsedTiming] {
        let regex = try createRegex(
            rootPath: configuration.rootPath,
            filteredPath: configuration.filteredPath,
            shouldIncludeInvalidLoc: configuration.shouldIncludeInvalidLoc
        )
        // The fastest way to split a large file by lines according to https://forums.swift.org/t/difficulties-with-efficient-large-file-parsing/23660/4
        return try log.withUnsafeBytes {
            let dataSlices = $0.split(separator: UInt8(ascii: "\n"))
            let lines = dataSlices.map { Substring(decoding: UnsafeRawBufferPointer(rebasing: $0), as: UTF8.self) }
            return try regex.extractTimingIfPresent(text: lines, threshold: configuration.threshold) ?? []
        }
    }

    private func processSubSections(subSections: [XCLogParser.IDEActivityLogSection]) async throws -> [ParsedTiming] {
        let regex = try createRegex(
            rootPath: configuration.rootPath,
            filteredPath: configuration.filteredPath,
            shouldIncludeInvalidLoc: configuration.shouldIncludeInvalidLoc
        )
        return try await withThrowingTaskGroup(of: [ParsedTiming]?.self) { group in
            for section in subSections {
                group.addTask {
                    try section.extractingTimingIfPresent(
                        regex: regex,
                        threshold: self.configuration.threshold
                    )
                }
            }
            var extractedTimings: [ParsedTiming] = []
            for try await result in group where result != nil {
                extractedTimings.append(contentsOf: result!)
            }
            return extractedTimings
        }
    }

    /*
     Searching for strings of similar format, containing '/r' and `/t` sequences:
     - 0.12ms    /Users/vagrant/git/File1.swift:208:120
     - 0.33ms    /Users/vagrant/git/File2:208:9
     - 7.29ms    /Users/vagrant/git/File3:193:17    instance method verify(_:count:file:line:)
     - 0.33ms    <invalid loc>                      static method combine(_:input:output:)
     */
    private func createRegex(rootPath: String, filteredPath: String?, shouldIncludeInvalidLoc: Bool) throws -> Regex<(Substring, Substring, Substring, Substring)> {
        let trailingRegex: Regex<(Substring, Substring, Substring)>
        if shouldIncludeInvalidLoc {
            if let filteredPath {
                trailingRegex = try Regex("(.*\(filteredPath).*?:\\d+:\\d+|\\Q<invalid loc>\\E)\\t(.+)")
            } else {
                trailingRegex = Regex {
                    /(.*?:\d+:\d+|\Q<invalid loc>\E)\t(.+)/
                }
            }
        } else {
            if let filteredPath {
                trailingRegex = try Regex("(.*\(filteredPath).*?:\\d+:\\d+)\\t(.+)")
            } else {
                trailingRegex = Regex {
                    /(.*?:\d+:\d+)\t(.+)/
                }
            }
        }

        return Regex {
            /(\d+\.\d+?)ms\t.*/
            rootPath
            trailingRegex
        }
    }
}

private extension XCLogParser.IDEActivityLogSection {
    func extractingTimingIfPresent(regex: Regex<(Substring, Substring, Substring, Substring)>, threshold: Float) throws -> [ParsedTiming]? {
        guard
            SwiftCompilationTimingParser.ValidPrefixes.allCases.first(where: { signature.hasPrefix($0.rawValue) }) != nil,
            !text.isEmpty
        else { return nil }

        let lines = text.split(separator: "\r")

        return try regex.extractTimingIfPresent(text: lines, threshold: threshold)
    }
}

private extension Regex where Output == (Substring, Substring, Substring, Substring) {
    func extractTimingIfPresent(text: [Substring], threshold: Float) throws -> [ParsedTiming]? {
        var parsed: [ParsedTiming] = []
        for line in text {
            guard let match = try wholeMatch(in: line) else { continue }
            guard let ms = Float(match.1), ms >= threshold else { continue }

            parsed.append(ParsedTiming(ms: ms, location: String(match.2), symbol: String(match.3)))
        }
        return parsed.isEmpty ? nil : parsed
    }
}

private extension Array where Element == ParsedTiming {
    mutating func group() {
        var groups: [String : ParsedTiming] = [:]
        for timing in self {
            var toAdd = timing
            let key = timing.location + timing.symbol
            if let existing = groups[key] {
                toAdd = ParsedTiming(ms: existing.ms + timing.ms, location: timing.location, symbol: timing.symbol)
            }
            groups[key] = toAdd
        }
        self = Array(groups.values)
    }
}
