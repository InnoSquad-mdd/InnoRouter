// MARK: - FlowTestEvent.swift
// InnoRouterTesting - legacy alias for the unified FlowEvent
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// Legacy alias for ``InnoRouterSwiftUI/FlowEvent``.
///
/// `FlowTestEvent` shipped with the initial `InnoRouterTesting`
/// release before the event taxonomy was promoted into
/// `InnoRouterSwiftUI` for reuse in the `events` `AsyncStream`
/// channels.
public typealias FlowTestEvent<R: Route> = FlowEvent<R>
