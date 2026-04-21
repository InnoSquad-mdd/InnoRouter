# Split, modal, and composition patterns

@Metadata {
  @PageKind(article)
}

Stack navigation, split detail navigation, and modal presentation are intentionally separate authorities.

## Split navigation

Use `NavigationSplitHost` or `CoordinatorSplitHost` when the app has a sidebar/detail layout.

Important scope boundary:

- InnoRouter owns only the detail stack
- sidebar selection remains app-owned
- column visibility remains app-owned
- compact adaptation remains app-owned

This keeps shell state out of the stack authority.

> Platform: `NavigationSplitHost` and `CoordinatorSplitHost` are **unavailable on watchOS**
> because SwiftUI's `NavigationSplitView` is unavailable there. watchOS apps should fall back
> to ``NavigationHost`` / ``CoordinatorHost`` inside a `#if !os(watchOS)` branch.

## Modal navigation

Use `ModalStore` with `ModalHost` when `sheet` or `fullScreenCover` should be routed with the same discipline as stack navigation.

On iOS and tvOS, `ModalHost` uses native `sheet` and `fullScreenCover` presentation.
On other supported platforms, `fullScreenCover` requests degrade to `sheet`.

Modal routing intentionally stays separate from stack routing:

- modal intent uses `ModalIntent`
- stack intent uses `NavigationIntent`
- modal queue state lives in `ModalStore`
- stack state lives in `NavigationStore`

`alert` and `confirmationDialog` stay outside this framework surface and should remain feature-owned state.

## Composition

The recommended composition order is:

1. shell state such as tabs or app mode
2. `ModalHost` if modal routing should be shared
3. `NavigationHost` or `CoordinatorHost` for stack routing
4. feature-local flow state inside a destination

This keeps each authority narrow and avoids one giant store owning every kind of navigation.
