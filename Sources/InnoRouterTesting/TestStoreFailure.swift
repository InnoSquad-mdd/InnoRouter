// MARK: - TestStoreFailure.swift
// InnoRouterTesting - Swift Testing bridge for test store failures
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

/// Records a Swift Testing issue at the call-site of the failing assertion.
///
/// All InnoRouter test-store failure paths go through this helper so tests
/// can capture them via `withKnownIssue { ... }` in regression coverage.
///
/// - Parameters:
///   - message: Human-readable description of the failure. Include enough
///     context for the developer to understand what mismatched.
///   - fileID: `#fileID` of the caller (not this file).
///   - filePath: `#filePath` of the caller.
///   - line: `#line` of the caller.
///   - column: `#column` of the caller.
@MainActor
func recordTestStoreIssue(
    _ message: String,
    fileID: String,
    filePath: String,
    line: Int,
    column: Int
) {
    Issue.record(
        Comment(rawValue: message),
        sourceLocation: SourceLocation(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    )
}
