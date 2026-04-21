# visionOS: windows, volumetric scenes, immersive spaces, and ornaments

@Metadata {
  @PageKind(article)
}

Coordinate visionOS spatial presentations through `SceneStore`,
`SceneHost`, and `innoRouterOrnament`.

## Overview

visionOS exposes three distinct "scene" primitives that are not
modelled by `NavigationStore` / `ModalStore`:

- a regular window, declared with `WindowGroup(id:)`
- a volumetric window, declared with `WindowGroup(id:).windowStyle(.volumetric)`
- an immersive space, declared with `ImmersiveSpace(id:)`

SwiftUI's openers for these (`@Environment(\.openWindow)`,
`@Environment(\.openImmersiveSpace)`, `@Environment(\.dismissImmersiveSpace)`,
`@Environment(\.dismissWindow)`) are only reachable from a view's
`body`. InnoRouter provides a thin `SceneStore` / `SceneHost` pair
that mirrors the `NavigationStore` / `NavigationHost` discipline:

- the store owns the desired scene state and publishes intents
- the host sits in the view tree and translates intents into the
  matching environment action
- subscribers observe outcomes through `SceneStore.events`

## Declaring scenes in your App

```swift
@main
struct MyApp: App {
    @State private var sceneStore = SceneStore<SpatialRoute>()

    var body: some Scene {
        WindowGroup(id: SpatialRoute.main.rawValue) {
            ContentView()
                .innoRouterSceneHost(sceneStore) { $0.rawValue }
        }
        ImmersiveSpace(id: SpatialRoute.theatre.rawValue) {
            TheatreView()
        }
    }
}
```

The `windowID:` closure maps each `Route` value to the scene's
declared `id`. `SceneStore` never constructs identifiers itself —
SwiftUI owns the string form.

## Opening and dismissing scenes

From anywhere that holds a reference to the store:

```swift
// In the main window:
sceneStore.openImmersive(.theatre, style: .mixed)

// Somewhere else later:
sceneStore.dismissImmersive()
```

The `SceneHost` modifier observes `store.pendingIntent`, dispatches
through the SwiftUI environment, and reports success back into the
store. If `openImmersiveSpace` returns `.userCancelled` or `.error`,
the host emits a `SceneEvent.rejected(_, reason: .environmentReturnedFailure)`
and leaves `currentScene` untouched.

## Observing lifecycle through `events`

`SceneStore.events` is an `AsyncStream<SceneEvent<R>>` that mirrors
the `events` channel shipped by `NavigationStore` and `ModalStore`:

```swift
Task {
    for await event in sceneStore.events {
        analytics.record(event)
    }
}
```

The event taxonomy (`presented`, `dismissed`, `rejected`) is
deliberately minimal — only outcomes the SwiftUI environment can
actually report.

## Ornaments on any platform

`View.innoRouterOrnament(_:content:)` attaches an ornament on
visionOS (delegating to SwiftUI's
`ornament(attachmentAnchor:contentAlignment:ornament:)`) and
degrades to a no-op on every other platform. That keeps call sites
unconditional:

```swift
ContentView()
    .innoRouterOrnament(OrnamentAnchor(anchor: .bottom, alignment: .center)) {
        ControlBar()
    }
```

`OrnamentAnchor` lives in `InnoRouterCore` so ornament placement is
serialisable and testable on platforms that never materialise the
visual effect.

## Composing with `FlowStore`

`SceneStore` is intentionally **not** composed into `FlowStore`.
`RouteStep` captures transitions inside a single scene (push / sheet
/ cover); spatial presentations are multi-scene events and would
break the `FlowStore` contract. Apps that need both simply own a
`FlowStore<R>` and a `SceneStore<R>` side-by-side — the `R` can be
the same route enum or two distinct enums, depending on whether the
spatial surface shares routes with the primary flow.
