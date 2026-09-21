# Logging Strategy

How to log with ButchKit: where, what, and at which level.

## Why we log at all

Logs have exactly one purpose: making the product better and more stable for the person using it. In this order:

1. **See failures.** Notice when something goes wrong for a user, ideally before they report it.
2. **Be ready for a crash.** When the app crashes or ends up in an invalid state, the messages written before it must be enough to understand what happened.
3. **Improve the system.** Turn recurring patterns into targeted fixes.

Logs are not analytics. Usage statistics belong in an analytics tool, not in the log.

## The model

Five things make up every log message. Understand these and you can log.

| Part | Meaning | Who decides |
|---|---|---|
| **Subsystem** | Which app | ButchKit, automatically from the bundle identifier, or the process name when there is none |
| **Category** | Which area of the app | You, once per area: `Camera`, `Audio`, `Purchase` |
| **Level** | How important | You, per message. Decides whether the line survives in the field |
| **Message** | A constant stem plus `key=value` fields | You |
| **Privacy** | Every value is private unless you mark it public | You, deliberately |

Subsystem and category are what you filter by in the console. Level decides whether a message is still there when you need it. The rest is wording.

## Setup

Every app declares its categories in **one dedicated file**, `LoggerCategories.swift`. That file is the registry: the single place where a category comes into existence, and the place where you say what it covers. Nothing else to call at launch, no configuration.

```swift
// LoggerCategories.swift — the one place categories are declared
import ButchKit
import OSLog

nonisolated extension Logger {
    /// Capture session, recording lifecycle, and saving to Photos.
    static let camera   = Logger(category: "Camera")
    /// Audio session configuration and microphone selection.
    static let audio    = Logger(category: "Audio")
    /// Entitlement checks and paywall decisions.
    static let purchase = Logger(category: "Purchase")
}
```

`Logger(category:)` resolves the subsystem from the bundle identifier, so there is nothing to pass and nothing to keep in sync. A target that has to log under someone else's subsystem — an app extension filing under its host app — names it: `Logger(category: "Camera", subsystem: "com.host.app")`.

That shared subsystem is for reading in Console and in a sysdiagnose, where one filter then shows both processes side by side. It does not merge exports: a process only ever reads its own entries back, so neither `LogExport` nor `LogMirror` in the app will ever see a line the extension wrote. An extension that needs nothing else from ButchKit should call `os.Logger`'s own `init(subsystem:category:)` with the host's identifier rather than link the package for one initializer — the package carries a resource bundle, and the extension would ship it a second time.

Write the doc comment. It is what lets the next person — or the next agent — pick the right category instead of inventing a near-duplicate. A console filter full of `Camera`, `Capture` and `Recording` is how that goes wrong.

Add a category when an area actually logs, not in advance. An unused category is noise.

### Categories ButchKit writes itself

Some ButchKit components log under the app's subsystem as well, in categories of their own:

| Category | Written by | What it covers |
|---|---|---|
| `LogMirror` | `LogMirror` | A harvest or write that failed |
| `Purchase` | `PaywallService` | Purchases, restores, entitlement and status reads |
| `UFEService` | `UFEService` | Every error shown to the user, as `User-facing error shown: level=… domain=… code=…`. `info` is written at `notice`, so it survives in the field. The description of the underlying error is private. Change the name with `UFEService(category:)` |

The `Purchase` category in the setup example above is the same name on purpose: the app's own entitlement decisions then sit next to the paywall's under one filter. Choose a different name if you want them apart. Do not declare `LogMirror` yourself.

### Why `nonisolated`

It is not decoration. As soon as a project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, static properties without it belong to the main actor, and reading them from a background queue is a compile error — which is exactly where capture pipelines, sample buffers and network work live. One keyword on the extension covers the whole file.

Applying `nonisolated` to an extension requires **Swift 6.1 or newer** (SE-0449). In a project that does not use main-actor-by-default it changes no behaviour, so writing it costs nothing there.

### Why a plain extension

The obvious next question is whether a macro could shorten this. It could, by roughly one line per category — and it would cost a `swift-syntax` dependency that pins every consuming app to one version, a trust dialog per project and per version bump, and incompatibility with binary distribution. It would also delete the one place where a category is documented, because the only workable macro form is a list of strings in an attribute. `swift-log` stays macro-free for the same reasons. One readable line per category is the better trade.

## Writing a message

```swift
Logger.camera.notice("Recording started: fps=\(fps, privacy: .public) width=\(width, privacy: .public) height=\(height, privacy: .public)")
Logger.camera.error("Capture start failed: code=\(code, privacy: .public) op=startRecording")
```

The pattern is always the same: **a constant stem, then values as `key=value` fields.**

The stem describes the event and never changes between calls, which is what makes messages groupable and searchable. Values hang off the end as fields rather than being built into the sentence. One message is always one line.

`os.Logger` splits this interpolation into static text and arguments by itself. You get the benefits of structured logging while writing what looks like ordinary interpolation.

Interpolated values must be `CustomStringConvertible`. Numbers, strings and durations are; struct types like `CGSize` are not. Log their parts as separate fields — which reads better anyway — or convert with `String(describing:)`.

### Logging a property from inside a class

`os.Logger` takes each interpolated value as an `@autoclosure @escaping` closure, so it can skip the work entirely when the message is dropped. Escaping closures that capture `self` in a class or actor need `self.` spelled out, so this does not compile inside one:

```swift
// error: reference to property 'allowsCellular' in closure requires explicit
//        use of 'self' to make capture semantics explicit
Logger.sync.notice("Sync deferred: network=\(allowsCellular ? "any" : "wifiOnly", privacy: .public)")
```

Writing `self.allowsCellular` silences it. Binding the value first is the better fix: the line gets shorter, the ternary stops competing with the message for attention, and there is no `self.` noise in the middle of the text.

```swift
let network = allowsCellular ? "any" : "wifiOnly"
Logger.sync.notice("Sync deferred: network=\(network, privacy: .public)")
```

Keep the value inside the interpolation, with `self.`, only when producing it is genuinely expensive and the message might be dropped. A local is computed either way; the interpolation is not. That case is rare — most logged values are counters, codes and flags.

Structs are unaffected, and so are locals such as a `catch` binding. Only stored properties of a class or actor need this.

Formatting belongs inside the interpolation, never in a string you build beforehand:

```swift
// Costs nothing when the message is dropped
Logger.scroll.debug("Scroll tick: speed=\(speed, format: .fixed(precision: 1))")
```

## Choosing the level

This is the most consequential decision per message, because it decides visibility, persistence, and cost.

| Question | Level | On disk? |
|---|---|---|
| Pure developer tracing, high frequency? | `debug` | Never |
| Nice to know, not essential? | `info` | Only while actively collecting |
| Would I need this in a user's failure report? | `notice` | Yes |
| A real runtime failure at a system boundary? | `error` | Yes, kept longer |
| A broken assumption that points at a bug? | `fault` | Yes, kept longest |

Rules of thumb:

- Anything you might need later is at least `notice`. `debug` and `info` are not there in the field.
- High-frequency tracing — per frame, per match, per sample — is always `debug`.
- Expected but meaningful events and deliberate decisions are `notice`.
- Handled failures at a system boundary are `error`.
- Violated assumptions are `fault`.
- Successful routine operations are not logged above `debug`.

Two of those rules meet on every success line, and this is the tiebreaker: a routine success earns `notice` only when it is the anchor a failure report needs to be readable — the store opening at launch, a sync run settling, an export finishing — and then once per launch or once per run. Everything else that went right becomes a count in that one summary line, never a line of its own.

At `notice` and above the level is always enabled, so the interpolation always runs. A value that costs a pass over the data, such as the length of a text that was just decoded, is real work on a persisted line. Log the size you already have — the byte count that came in — instead.

You do not need `#if DEBUG` around log calls. `debug` and `info` are not persisted in release anyway, and building the message is optimised away when nothing consumes it. The level controls visibility.

## Privacy

User data is not negotiable.

```swift
// Never: user content in a log
Logger.notes.notice("Note: \(text)")

// Instead: derived values that cannot be traced back
Logger.notes.notice("Note loaded: words=\(wordCount, privacy: .public) locale=\(locale, privacy: .public)")
```

- Interpolated values are **private by default** and appear as `<private>` in Console and in a sysdiagnose. They do **not** appear that way when the app reads its own log back: `LogExport`, `LogMirror` and every diagnostics file built from them show an unannotated value exactly as it was written. Only an explicit `privacy: .private` or `.private(mask: .hash)` survives into an export as a redaction.
- Mark a value `public` only when it can never contain personal data: a locale identifier, a duration, a counter, an error code.
- Anyone with the device and its passcode can read these logs, and anyone who receives a diagnostics file reads all of it. Nothing personal belongs in any value, whatever its annotation.
- To correlate equal values without revealing them, use `privacy: .private(mask: .hash)`.
- Log an error as its domain and code, which `error.logCode` renders as two fields, and add `error.localizedDescription` only when the domain cannot embed a file name or user text. Foundation's file errors quote the file's name; CloudKit's and StoreKit's do not.

```swift
Logger.store.error("Save failed: \(error.logCode, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
Logger.fileImport.error("File unreadable: ext=\(url.pathExtension, privacy: .public) \(error.logCode, privacy: .public)")
```

When in doubt, do not log it. The one protection that holds everywhere — Console, sysdiagnose, export — is that user data is never logged, at any level, with any annotation.

## The readability test

Every message has to stand on its own. Someone who sees only that one line, without knowing the code, must understand:

- **what** happened
- **where** in the system
- in **which flow**
- with **which values**
- and for failures: **why**

A line you can only decode by opening the source fails the test and needs rewriting.

## Wording

Log messages are text humans read. They are written with the same care as the app's UI copy, and they must be understandable to everyone on the team, not just to whoever wrote them.

The counterexample is the classic bad error message: "An error occurred (6383)." It says neither what happened, nor where, nor why.

- **US English**, like code and comments. Log messages are never localised.
- **Specific over generic.** Name the actual operation and object. Not "Operation failed" but "Audio session activation failed".
- **Codes are a field, never the whole message.** `code=…` may travel along, but it never replaces the description in words.
- **Calm and factual.** No drama, no blame, no exclamation marks.
- **Active and concrete.** Say what actually happened.
- **The product's own vocabulary.** Use the words the UI uses, so the whole team talks about the same things.
- **No filler.** Every word carries meaning or goes.
- **No emoji.** They do not help filtering and hurt readability. Category and level already provide the framing.

| Situation | Poor | Good |
|---|---|---|
| Server unreachable | `print("⚠️ not available")` | `Sync server unreachable: status=\(status, privacy: .public)` |
| Audio session fails | `An error occurred (6383)` | `Audio session activation failed: code=\(err, privacy: .public) op=startRecording` |
| Locale fallback | `fallback en-US` | `Locale fallback: requested=\(code, privacy: .public) resolved=en-US reason=noOnDeviceSupport` |
| Missing permission | `not authorized` | `Photo library access denied: cannot save export` |
| Recording ended | `[AS] stopped` | `Recording stopped: duration=\(seconds, privacy: .public)s` |

## What we log

- Decisions with their reason — which option was chosen and why a fallback kicked in.
- State transitions of stateful engines.
- Events at system boundaries that can fail: permissions, audio sessions, file access, network, purchases.
- The lifecycle of a long-running operation: start, end, and a summary.
- Failures with enough context to act on them.

## What we never log

- User content or any other user input.
- Success spam for routine operations.
- High-frequency diagnostics at a persisted level.
- Multi-line messages.
- Anything that serves none of the three purposes at the top.

## Correlating a flow

A single user action often crosses several areas. Carry one `LogSession` through them so the whole run can be filtered as one flow:

```swift
let session = LogSession()

Logger.camera.notice("Recording started: session=\(session.id, privacy: .public)")
Logger.audio.notice("Audio session activated: session=\(session.id, privacy: .public)")
Logger.camera.notice("Recording stopped: session=\(session.id, privacy: .public) duration=\(seconds, privacy: .public)s")
```

Filtering the console for `session=a3f9` now shows that one recording across every category, instead of reading each area separately.

The identifier is interpolated explicitly. `os.Logger` takes a message the compiler assembles at the call site, so nothing can be appended afterwards without giving up privacy annotations and lazy formatting. Always write `\(session.id, privacy: .public)`.

## Logging from a view

Views use the same static loggers as everything else; `Logger.purchase.notice(…)` inside an `onAppear` is the normal shape. The environment also carries a `LoggerService` as `\.log`, for the one case where a view hierarchy has to log under a subsystem other than the target's own: set `.environment(\.log, LoggerService(subsystem: "com.host.app"))` above it and read the logger by category inside the body.

`log[…]` takes a `LogCategory`. A string literal works (`log["Purchase"]`), and for autocompletion declare the category as a named value next to the `Logger` ones, in `LoggerCategories.swift`:

```swift
nonisolated extension LogCategory {
    /// Entitlement checks and paywall decisions.
    static let purchase: Self = "Purchase"
}

// inside the view
log[.purchase].notice("Paywall presented: source=onboarding")
```

Nothing else needs the environment, and categories stay declared in `LoggerCategories.swift` either way.

## Reading logs

While developing, the Xcode console filters by category and level. For a test device outside Xcode, use the Console app and filter by subsystem and category. `notice` and above are visible by default; `info` and `debug` have to be switched on.

## Exporting logs

`LogMirror` keeps the app's persisted messages across launches and hands them back, for example to attach them to a bug report. It needs one mirror per app, applied at the root:

```swift
@main struct MyApp: App {
    @State private var logMirror = LogMirror()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .logMirror(logMirror)
        }
    }
}
```

Wherever diagnostics are shared, the mirror comes out of the environment:

```swift
struct DiagnosticsView: View {
    @Environment(\.logMirror) private var mirror
    @State private var report: URL?
    @State private var failure: String?
    @State private var isPreparing = false

    var body: some View {
        VStack {
            Button("Prepare diagnostics") {
                Task {
                    discard()
                    isPreparing = true
                    defer { isPreparing = false }
                    do {
                        report = try await mirror.fileURL(since: .now.addingTimeInterval(-7 * 86_400))
                        failure = nil
                    } catch {
                        failure = error.localizedDescription
                    }
                }
            }
            .disabled(isPreparing)

            if let report {
                ShareLink("Share diagnostics", item: report)
            }

            if let failure {
                Text(failure).foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: discard)
    }

    /// The exported file is ours to clean up — see below.
    private func discard() {
        if let report { try? FileManager.default.removeItem(at: report) }
        report = nil
    }
}
```

Handle the error rather than swallowing it with `try?`. `fileURL` throws `LogExportError.noEntries` when nothing matched the window, and an empty attachment looks like a real report. Show a progress state: a read costs about a second, see below.

`fileURL` writes a plain text file named `MyApp-Diagnostics-2026-08-05-1431-A3F91B2C.txt` and hands you its URL. Timestamps inside, and the stamp in the name, are in the device's time zone with the offset written out, so `10:52:02.923+02:00` is what the user's clock showed. The app name comes from the bundle, so there is nothing to configure and nothing to keep in sync when you rename the app. Share the URL, not the text: a shared string is pasted into the message body, a shared file arrives as an attachment — the difference between a report someone can open and one they have to scroll past. Every call writes its own file, so two shares can be open at once; delete it once the share sheet is done.

Two more shapes exist for the same content. `mirror.text(since:)` returns a string, for showing the log on screen. `mirror.entries(since:)` returns structured values, for filtering or listing them.

`LogExport` offers the same three shapes for the running launch only, without a file behind them. It is the right tool for a live view while developing and for a target that has no mirror; for anything a user sends you, use the mirror.

## Keeping logs across launches

The system hands a process only its own log entries. Whatever an app wrote before its last relaunch is gone as far as it is concerned, and that is exactly the log a user reports from: "my entries are gone" arrives a day and several launches later. `LogMirror` closes that gap the only way the platform allows. It reads the process's own entries back and appends the persisted levels — `notice`, `error` and `fault` — to a file in the app container. Every later launch reads from that file.

**Reading the store back costs about a second of CPU**, however little is new, so it happens rarely:

- when the scene enters the background, which the `.logMirror(_:)` modifier does on its own,
- at the start of every read through the mirror, so an export is never behind the live log.

There is no timer, and the gap this leaves is honest: a crash loses the lines written since the last time the app went to the background. The system's crash report covers that moment; the mirror covers everything before it. On macOS the scene rarely enters the background and quitting reports no phase, so the harvest at the start of a read is the one that matters there.

What else to know:

- **One mirror per app.** Apply `.logMirror(_:)` once, at the root, with a mirror the app owns in `@State`. Two mirrors on the same file are safe but read the store twice for the same lines.
- **Capacity.** The file holds a million bytes by default and drops its oldest lines first. An app that logs the way this document asks writes a few dozen lines a day; that is months of history.
- **Where it lives.** `Library/Logs/<subsystem>/` in the app's container, excluded from backup. The log is specific to one device, and values without a privacy annotation are in it as written — which changes nothing about what to log, and is the reason the file never travels on its own.
- **A category of ButchKit's own.** The mirror logs its own failures under the category `LogMirror` in the app's subsystem, so a harvest that failed is visible in the very log it failed to keep. See [Categories ButchKit writes itself](#categories-butchkit-writes-itself).
- **`debug` and `info` are not kept.** They were never written to disk by the system either. Anything you may need later has to be logged at `notice` or above; the mirror does not change that rule, it is the reason the rule pays off.

## Rules for agents

A compact checklist for anyone — human or AI — writing log statements in a ButchKit project:

- Never use `print` or `NSLog` for diagnostics. Always `os.Logger`.
- Declare categories only in `LoggerCategories.swift`, as `static let` on `Logger`, each with a `///` comment saying what it covers. Never add one anywhere else.
- Never build a logger — `Logger(category:)` or `service[…]` — inside a loop or a hot path.
- Inside a class or actor, bind a property to a local before logging it, rather than writing `self.` inside the interpolation.
- Constant stem first, then `key=value` fields. One line per message.
- Never mark a value `public` if it can contain user data. Never log user data at all: an export shows unannotated values in the clear.
- Use `notice` or higher for anything that must be visible in the field.
- A routine success is `notice` only as the once-per-launch or once-per-run anchor of a report; every other success is a count in that summary line.
- Log an error as `\(error.logCode, privacy: .public)`; add `localizedDescription` only when its domain cannot carry a file name or user text.
- No emoji, no drama, US English.
- Put formatting inside the interpolation, never in a prebuilt string.
- Add a category only when an area actually logs. `LogMirror`, `Purchase` and `UFEService` are also written by ButchKit.
- One `LogMirror` per app, applied at the root with `.logMirror(_:)`. Exports a user sends go through it, not through `LogExport`.
