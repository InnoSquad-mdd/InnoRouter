# Choosing an `EnvironmentMissingPolicy`

InnoRouter property wrappers
(`@EnvironmentNavigationIntent`, `@EnvironmentModalIntent`,
`@EnvironmentFlowIntent`) resolve their dispatcher through the
SwiftUI environment. When the matching host is missing, the
``EnvironmentMissingPolicy`` decides whether to crash, log, or
both.

## The three policies

| Policy | Debug | Release | When to use |
|---|---|---|---|
| ``EnvironmentMissingPolicy/crash`` | `preconditionFailure` | `preconditionFailure` | App code where missing wiring is always a bug. Default. |
| ``EnvironmentMissingPolicy/logAndDegrade`` | `Logger.error` + no-op dispatcher | `Logger.error` + no-op dispatcher | SwiftUI Previews, host-less snapshot tests, and similar out-of-app rendering paths. |
| ``EnvironmentMissingPolicy/assertAndLog`` | `Logger.error` + `assertionFailure` | `Logger.error` + no-op dispatcher | Pre-launch production builds where you want loud signal during development without paging users on a stray missing host. |

## Selecting one

Pick the narrowest policy that still surfaces wiring bugs at the
right time:

- **Default app code** stays on ``EnvironmentMissingPolicy/crash``.
  Production cold-starts will fail loudly and immediately on a
  missing host — exactly the behaviour you want once a real user
  is running the build.
- **`#Preview` blocks** use ``EnvironmentMissingPolicy/logAndDegrade``.
  Previews routinely render leaf views without their hosts; the
  no-op dispatcher keeps the canvas alive and the logged error
  still surfaces in the Xcode console.
- **TestFlight / pre-launch builds** can adopt
  ``EnvironmentMissingPolicy/assertAndLog`` from a single ship
  config. Engineers see `assertionFailure` traps locally, but a
  testflight tester does not get a crash dialog if a stray screen
  forgets its host.

## How to apply it

Use the
``SwiftUI/View/innoRouterEnvironmentMissingPolicy(_:)`` modifier
at the boundary where the policy applies — usually one level
above the offending view tree.

```swift
#Preview {
    SettingsView()
        .innoRouterEnvironmentMissingPolicy(.logAndDegrade)
}
```

```swift
@main
struct AppEntry: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                #if PRELAUNCH
                .innoRouterEnvironmentMissingPolicy(.assertAndLog)
                #endif
        }
    }
}
```

The setting flows through the environment, so a single modifier
covers every nested `@EnvironmentNavigationIntent`,
`@EnvironmentModalIntent`, and `@EnvironmentFlowIntent` it
contains.

## Why `assertAndLog` is not the new default

Switching the default to ``EnvironmentMissingPolicy/assertAndLog``
would silently soften production behaviour for every existing
adopter. ``EnvironmentMissingPolicy/crash`` stays the default to
preserve the loud-by-default contract; opt in to the gentler
policies at the boundary where they actually fit.
