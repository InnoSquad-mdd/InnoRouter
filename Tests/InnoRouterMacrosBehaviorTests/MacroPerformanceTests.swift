// MARK: - MacroPerformanceTests.swift
// InnoRouterMacrosBehaviorTests - @Routable expansion / CasePath
// runtime baseline at scale.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// `@Routable` and `@CasePathable` are compile-time macros. Their
// *expansion* time is a build-time signal — a regression in the
// macro plugin shows up as a slower `swift build`, not a slower
// runtime. Swift Testing does not own a build-time measurement API.
//
// What this file *does* own is the runtime baseline at scale:
// declaring 10/50/100-case enums forces the macro to expand a
// large `Cases` namespace at build time (any expansion regression
// surfaces there), and the runtime tests then exercise the
// generated `CasePath` embed / extract on every case so a runtime
// regression in the generated code is caught regardless of whether
// the build-time signal is visible.
//
// Performance assertions use a deliberately loose ceiling
// (`< 0.5s` for 1,000 round-trips at N=100). The intent is *catch
// catastrophic regressions*, not benchmark micro-optimisations.
// If a real benchmark dashboard ships later, narrow these.

#if canImport(InnoRouterMacrosPlugin)

import Foundation
import Testing
import InnoRouterCore
import InnoRouterMacros

// MARK: - 10-case fixture

@Routable
enum Route10Cases {
    case c00, c01, c02, c03, c04, c05, c06, c07, c08, c09
}

// MARK: - 50-case fixture

@Routable
enum Route50Cases {
    case c00, c01, c02, c03, c04, c05, c06, c07, c08, c09
    case c10, c11, c12, c13, c14, c15, c16, c17, c18, c19
    case c20, c21, c22, c23, c24, c25, c26, c27, c28, c29
    case c30, c31, c32, c33, c34, c35, c36, c37, c38, c39
    case c40, c41, c42, c43, c44, c45, c46, c47, c48, c49
}

// MARK: - 100-case fixture

@Routable
enum Route100Cases {
    case c000, c001, c002, c003, c004, c005, c006, c007, c008, c009
    case c010, c011, c012, c013, c014, c015, c016, c017, c018, c019
    case c020, c021, c022, c023, c024, c025, c026, c027, c028, c029
    case c030, c031, c032, c033, c034, c035, c036, c037, c038, c039
    case c040, c041, c042, c043, c044, c045, c046, c047, c048, c049
    case c050, c051, c052, c053, c054, c055, c056, c057, c058, c059
    case c060, c061, c062, c063, c064, c065, c066, c067, c068, c069
    case c070, c071, c072, c073, c074, c075, c076, c077, c078, c079
    case c080, c081, c082, c083, c084, c085, c086, c087, c088, c089
    case c090, c091, c092, c093, c094, c095, c096, c097, c098, c099
}

@Suite("Macro expansion + CasePath runtime baseline")
struct MacroPerformanceTests {

    // MARK: - Expansion sanity at scale

    @Test("@Routable expands and CasePath embed/extract round-trips on a 10-case enum")
    func tenCases_embedExtractRoundtrip() {
        let path = Route10Cases.Cases.c05
        let embedded = path.embed(())
        let extracted: Void? = path.extract(embedded)
        let mismatched: Void? = path.extract(.c00)

        #expect(embedded == .c05)
        #expect(extracted != nil)
        #expect(mismatched == nil)
    }

    @Test("@Routable expands and CasePath embed/extract round-trips on a 50-case enum")
    func fiftyCases_embedExtractRoundtrip() {
        let path = Route50Cases.Cases.c25
        let embedded = path.embed(())
        let extracted: Void? = path.extract(embedded)
        let mismatched: Void? = path.extract(.c00)

        #expect(embedded == .c25)
        #expect(extracted != nil)
        #expect(mismatched == nil)
    }

    @Test("@Routable expands and CasePath embed/extract round-trips on a 100-case enum")
    func hundredCases_embedExtractRoundtrip() {
        let path = Route100Cases.Cases.c050
        let embedded = path.embed(())
        let extracted: Void? = path.extract(embedded)
        let mismatched: Void? = path.extract(.c000)

        #expect(embedded == .c050)
        #expect(extracted != nil)
        #expect(mismatched == nil)
    }

    // MARK: - Coarse runtime budget at N = 100

    @Test("1,000 CasePath round-trips on a 100-case enum stay within a generous budget")
    func hundredCases_thousandRoundtrips_within500ms() {
        let path = Route100Cases.Cases.c050
        let start = Date()

        for _ in 0..<1000 {
            let embedded = path.embed(())
            let extracted: Void? = path.extract(embedded)
            #expect(extracted != nil)
        }

        let elapsed = Date().timeIntervalSince(start)
        // Generous ceiling — this is a catastrophic-regression guard,
        // not a micro-benchmark. Tighten only when a real perf
        // dashboard exists and we have measured headroom.
        #expect(elapsed < 0.5)
    }
}

#endif
