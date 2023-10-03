# SwiftCompilationTimingParser

Whenever there is a need to automate swift compilation duration reporting, there are many ways of doing that. However, it is unclear how to achieve the best format for easier navigation in the generated reports.

`SwiftCompilationTimingParser` makes it easy to parse `xcactivitylog` logs or raw `xcodebuild` output, gathering timing information reported by Swift Frontend, and outputing it as a JSON file with a straightforward format.

This project is able to do the following:

1. Parse given `xcactivitylog` (using `--derived-data-path`) or `xcodebuild` raw output log
2. Filter compilation timing in the provided log file based on the given `--threshold` and `--filtered-path` (optional).
3. Generate `JSON` file with the interesting slow compiling symbols

## The following `xcodebuild` log is expected

To generate the expected `xcodebuild` log (for `--xcodebuild-log-path` flag), the following `xcodebuild` invocation must be made:

```bash                                         
    xcodebuild -workspace Project.xcworkspace \
    -scheme SchemaName \
    -sdk iphonesimulator \
    ONLY_ACTIVE_ARCH=YES \
    OTHER_SWIFT_FLAGS="-Xfrontend -debug-time-expression-type-checking \
    -Xfrontend -debug-time-function-bodies" \
    -destination 'platform=iOS Simulator,id=insert_your_simulator_id_here' clean build clean \
    | tee xcodebuild.log
```

Then, specify the path to `xcodebuild.log` file generated after this command finishes to `SwiftCompilationTimingParser`'s `--xcodebuild-log-path`.

> Note: running `xcodebuild ... clean build clean` is mandatory to achieve consistent results, but `build` can be also replaced by `test` in order to include test files into the generated report. Related issue: https://github.com/MobileNativeFoundation/XCLogParser/issues/139

## The following `xcactivitylog` is expected

In case `--derived-data-path` is specified instead of `--xcodebuild-log-path`, the following flags need to be set in project's `OTHER_SWIFT_FLAGS`: 

```bash
-Xfrontend -debug-time-expression-type-checking
-Xfrontend -debug-time-function-bodies
```

## The following arguments are accepted

```bash
--root-path "path_to_the_root_of_the_project_whose_log_is_parsed"
--enable-grouping
--target-name "target_name_if_xcactivitylog_is_used"
--output-path "path_to_json_file_which_would_contain_parsed_symbols"
--xcodebuild-log-path "path_to_xcodebuild_raw_log_output"
--threshold 0.4
```

## Generated JSON format

```json
[
  {
    "symbol" : "instance method increase(_:count:file:line:)",
    "duration" : 2.119999885559082,
    "location" : "/MyProject/Counter.swift:192:17"
  },
  {
    "symbol" : "instance method perform(_:)",
    "duration" : 0.55000001192092896,
    "location" : "/MyProject/Counter.swift:115:17"
  },
  ...
]
```

## Usage

```bash
USAGE: swift-compilation-timing-parser --root-path <root-path> [--derived-data-path <derived-data-path>] [--xcodebuild-log-path <xcodebuild-log-path>] [--filtered-path <filtered-path>] --target-name <target-name> --threshold <threshold> --output-path <output-path> [--xcactivitylog-output-path <xcactivitylog-output-path>] [--include-invalid-loc] [--enable-grouping]

OPTIONS:
  --root-path <root-path> Absolute path to the project's root folder. Used for
                          filtering purpose to cut out the username and other
                          non-relevant paths when logs are parsed
  --derived-data-path <derived-data-path>
                          Absolute path to DerivedData, where xcactivitylog
                          will be searched
  --xcodebuild-log-path <xcodebuild-log-path>
                          Absolute path to a file with xcodebuild log output.
                          If specified, `--derived-data-path` argument is
                          ignored
  --filtered-path <filtered-path>
                          (Optional) Path which should be included during log
                          filtering. If specified, this path is the only path
                          that will appear in the results, other results will
                          be omitted
  --target-name <target-name>
                          Name of the target to be used for finding logs
  --threshold <threshold> Threshold to be used for filtering symbol compilation
                          duration
  --output-path <output-path>
                          Path where the generated contents of parsed
                          compilation duration will be stored
  --xcactivitylog-output-path <xcactivitylog-output-path>
                          Path where the parsed xcactivitylog' JSON will be
                          stored
  --include-invalid-loc   (Optional) If specified, symbols without a specific
                          location (<invalid loc>) will be included in the
                          results
  --enable-grouping       (Optional) If specified, symbols are grouped by
                          location and symbol before being written to
                          `--output-path`
```