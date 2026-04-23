// MARK: - CasePathableBehaviorTests.swift
// InnoRouterMacrosBehaviorTests - @CasePathable runtime semantics
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import InnoRouterMacros

// MARK: - Fixtures

@CasePathable
enum UIEvent {
    case tapped
    case opened(id: String)
    case swiped(dx: Int, dy: Int)
}

// MARK: - @Suite

@Suite("CasePathableBehaviorTests")
struct CasePathableBehaviorTests {

    // MARK: - embed/extract roundtrips

    @Test("parameterless case roundtrips through CasePath")
    func embedExtract_roundtrip_parameterless() {
        let path = UIEvent.Cases.tapped
        let embedded = path.embed(())
        let extracted: Void? = path.extract(embedded)
        #expect(extracted != nil)

        let mismatched: Void? = path.extract(.opened(id: "x"))
        #expect(mismatched == nil)
    }

    @Test("single labeled case roundtrips preserving identifier")
    func embedExtract_roundtrip_singleLabeled() {
        let path = UIEvent.Cases.opened
        let embedded = path.embed("home")
        let extracted = path.extract(embedded)
        #expect(extracted == "home")
    }

    @Test("two labeled case preserves tuple order")
    func embedExtract_roundtrip_twoLabeled() {
        let path = UIEvent.Cases.swiped
        let embedded = path.embed((3, -4))
        let extracted = path.extract(embedded)
        #expect(extracted?.0 == 3)
        #expect(extracted?.1 == -4)
    }

    // MARK: - is(_:)

    @Test("is(_:) distinguishes between CasePathable cases")
    func isDistinguishesCases() {
        let event: UIEvent = .opened(id: "detail")
        #expect(event.is(UIEvent.Cases.opened))
        #expect(!event.is(UIEvent.Cases.swiped))
        #expect(!event.is(UIEvent.Cases.tapped))
    }

    // MARK: - subscript[case:]

    @Test("subscript[case:] returns value only for matching case")
    func subscriptCaseMatchesOnlyCorrectCase() {
        let tap: UIEvent = .tapped
        #expect(tap[case: UIEvent.Cases.opened] == nil)

        let open: UIEvent = .opened(id: "profile")
        #expect(open[case: UIEvent.Cases.opened] == "profile")

        // NOTE: Tuple-valued subscript form (`event[case: UIEvent.Cases.swiped]`)
        // currently triggers a Swift 6.3 SIL-lowering crash for generic subscripts
        // returning `(T, U)?`. Tuple extraction is still covered directly above via
        // `path.extract(_:)`, which uses the same generator output.
    }

    // MARK: - Documentation note

    // NOTE: `@CasePathable` intentionally does NOT synthesize `Route` conformance.
    // Verifying the absence of a conformance at runtime is awkward (and would rely
    // on reflection). This behavior is guarded by the macro definition itself
    // (`Macros.swift` declares no `@attached(extension, conformances:)` for
    // `@CasePathable`) and by plugin-level expansion tests in
    // `Tests/InnoRouterMacrosTests`. Leaving a comment here so the contrast with
    // `@Routable` is discoverable to future contributors.
}
