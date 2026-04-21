// MARK: - NavigationTestEvent.swift
// InnoRouterTesting - legacy alias for the unified NavigationEvent
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// Legacy alias for `NavigationEvent`.
///
/// `NavigationTestEvent` shipped with the initial `InnoRouterTesting`
/// release before the event taxonomy was promoted into
/// `InnoRouterSwiftUI` for reuse in the `events` `AsyncStream`
/// channels. The test store API continues to refer to this alias so
/// existing call sites keep building without edits.
public typealias NavigationTestEvent<R: Route> = NavigationEvent<R>
