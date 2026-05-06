// MARK: - ChildCoordinatorCoreTests.swift
// InnoRouter Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import Foundation
import Observation
import OSLog
import Synchronization
import SwiftUI
import InnoRouter
import InnoRouterEffects
@testable import InnoRouterSwiftUI

// MARK: - ChildCoordinator Tests

@Suite("ChildCoordinator Tests")
struct ChildCoordinatorTests {
    private static func builtExecutable(named name: String) -> URL? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildDirectory = root.appending(path: ".build")
        guard let enumerator = FileManager.default.enumerator(
            at: buildDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == name else {
                continue
            }

            guard fileURL.pathExtension.isEmpty, !fileURL.path.contains(".dSYM/") else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isExecutableKey])
            if values?.isRegularFile == true, values?.isExecutable == true {
                return fileURL
            }
        }

        return nil
    }

    @MainActor
    final class ParentTestCoordinator: Coordinator {
        typealias RouteType = TestRoute
        typealias Destination = EmptyView

        let store = NavigationStore<TestRoute>()

        @ViewBuilder
        func destination(for route: TestRoute) -> EmptyView {
            EmptyView()
        }
    }

    @MainActor
    final class OnboardingChild: ChildCoordinator {
        typealias Result = String

        var onFinish: (@MainActor @Sendable (String) -> Void)?
        var onCancel: (@MainActor @Sendable () -> Void)?
        var lifecycleSignals: LifecycleSignals = LifecycleSignals()
    }

    @Test("push(child:) resumes Task with the finish result")
    @MainActor
    func testFinishResumesTask() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onFinish?("welcome")

        let result = await task.value
        #expect(result == "welcome")
    }

    @Test("push(child:) resumes Task with nil on cancel")
    @MainActor
    func testCancelResumesTaskWithNil() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onCancel?()

        let result = await task.value
        #expect(result == nil)
    }

    @Test("push(child:) ignores cancel after finish")
    @MainActor
    func testCancelAfterFinishIsIgnored() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onFinish?("final")
        child.onCancel?()

        let result = await task.value
        #expect(result == "final")
    }

    @Test("push(child:) ignores finish after cancel")
    @MainActor
    func testFinishAfterCancelIsIgnored() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onCancel?()
        child.onFinish?("late")

        let result = await task.value
        #expect(result == nil)
    }

    @Test("push(child:) installs finish and cancel callbacks on the child")
    @MainActor
    func testPushInstallsCallbacks() {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        #expect(child.onFinish == nil)
        #expect(child.onCancel == nil)

        _ = parent.push(child: child)

        #expect(child.onFinish != nil)
        #expect(child.onCancel != nil)
    }

    @Test("push(child:) fails fast when the same child instance is reused")
    func testPushRejectsSameChildInstanceReuse() throws {
        guard let executableURL = Self.builtExecutable(named: "ChildCoordinatorFailFastProbe") else {
            Issue.record("Expected ChildCoordinatorFailFastProbe executable to be built")
            return
        }

        let stdout = Pipe()
        let stderr = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stderrOutput = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        #expect(process.terminationStatus != 0)
        #expect(stderrOutput.contains("Cannot push the same ChildCoordinator instance more than once."))
    }
}
