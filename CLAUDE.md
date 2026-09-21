# Library Description

The ButchKit is a helpful SDK containing small tools and modifiers to assist with the development of Swift applications for iOS, iPadOS and macOS. It contains functions that are not developed by Apple, but which could be useful in many projects.



# Requirements

Minimum version of iOS and iPadOS is 17.0. Minimum macOS is 14.0.

# General Behaviour

- Remember to declare elements as 'public' so that they can be used in a library

# Generic by Design

ButchKit is for generic use. It must never name or reference a specific product of the author, in code, doc comments, previews, tests or `Documentation/`.

- No app names, no app-specific examples (a domain, feature or wording taken from one app), no real IDs (bundle IDs, subscription group IDs, App Store Connect IDs, legacy keys), no product URLs.
- Examples use neutral placeholders: `com.example.App`, `group.com.example.App`, `https://example.com`, `MyApp`, and neutral domains such as items, documents, sync or export.
- Write from the point of view of any app that uses ButchKit, never "we", "our apps" or "the apps".
- No implementation that only makes sense for one app. Everything app-specific (texts, identifiers, products, URLs) is handed in by the app.
- Exception: ButchKit's own stable runtime keys (`design.heuser.ButchKit.*`) stay, because renaming them loses stored state in existing installs.

# Modularity

Modularity is a top priority. ButchKit ships as one target today, but every component must stay ready to be split into its own target.

- One component per folder. It depends on as few other ButchKit components as possible, and never on an app.
- Every dependency on another component is deliberate and documented. The component table in `Documentation/ButchKit.md` is the single source for what uses what. A component's own document may explain why it needs a dependency, and links to the table rather than keeping a second list.
- Avoid `internal` types shared across components. Where one is unavoidable, document it; it becomes `package` in a split.
- Resources belong to the component that uses them and are listed in the component table.
- A new component is not done until the component table in `Documentation/ButchKit.md` lists it.

# Architecture

**No singletons.** Never add a `static let shared`, a `configure()` call that has to run at launch, or any type whose only access path is a global. This applies to new code and to anything being refactored.

Reach for what Apple already ships, in this order:

1. **A value type with a `public init`.** If the type only carries configuration, make it an immutable `struct`, `Sendable` and `Equatable`. Callers construct one where they need it. `LoggerService` is the reference.
2. **The SwiftUI environment**, for anything a view hierarchy should be able to override. An `EnvironmentKey` plus a `public extension EnvironmentValues`, as in `LogEnvironment.swift`. Where state is involved, use `@Observable` on a `@MainActor final class` and inject it with `.environment(service)`, as `UFEService` does.
3. **A parameter with a default value**, when a function needs the dependency. See `LogExport.entries(since:from:)`.

No service locators, registries or DI containers. `EnvironmentKey`, `EnvironmentValues`, `@Observable`, `@Entry` and plain initializers cover everything this SDK needs. `@Entry` is available at our deployment target: it is a compile-time macro, so only the SDK matters, not the iOS 17 floor. The existing public keys are hand-written `EnvironmentKey`s; `@Entry` is used for internal ones such as `paywallSceneID`. Either is fine for new keys.

**A constant is not a singleton.** A `static let` holding an immutable resolved value, an `EnvironmentKey.defaultValue`, or `static let camera = Logger(category: "Camera")` in a consuming app are constants. The test is whether the value can change and whether callers are forced through it. If neither is true, it is fine.

**The environment does not reach everywhere.** `@Environment` only exists inside a view body, so services, actors and background work cannot read it. Every such type must also be constructible directly, and that direct path is the primary one. The environment is layered on top of it, never the only way in.

# Logging

Follow `Documentation/LoggingStrategy.md`. Its "Rules for agents" section at the end is the checklist — read it before writing a log statement. Three rules matter enough to repeat here, because getting them wrong is not recoverable after the fact:

- NEVER use `print` or `NSLog` for diagnostics — use `os.Logger`
- Never mark an interpolated value `public` if it can contain user data
- Use `notice` or higher for anything that must be visible in the field; `debug` and `info` do not survive there
