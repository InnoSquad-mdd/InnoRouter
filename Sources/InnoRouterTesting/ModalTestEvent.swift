// MARK: - ModalTestEvent.swift
// InnoRouterTesting - legacy alias for the unified ModalEvent
// Copyright © 2026 Inno Squad. All rights reserved.

import InnoRouterCore
import InnoRouterSwiftUI

/// Legacy alias for `ModalEvent`.
///
/// `ModalTestEvent` shipped with the initial `InnoRouterTesting`
/// release before the event taxonomy was promoted into
/// `InnoRouterSwiftUI` for reuse in the `events` `AsyncStream`
/// channels.
public typealias ModalTestEvent<M: Route> = ModalEvent<M>
