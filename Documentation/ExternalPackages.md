# External packages

How to list an app's external packages with ButchKit, and let the user turn the optional ones off: one definition, one screen, one question everywhere else.

## What it is

Every app lists the third-party packages it ships, with their license and a way to the source. Some of those packages the app can do without, analytics being the usual one, and the user should be able to switch them off in the same place they learn about them. The module turns that into a fixed system:

1. **One definition.** The app declares its packages once, as `ExternalPackage` values in `ExternalPackage.all`. The screen renders them, so listing a new package is adding one entry.
2. **One switch per optional package.** `isOptional: true` puts a switch under the package. It is an opt-out: on until the user turns it off.
3. **One question everywhere else.** `ExternalPackage.ID.isEnabled` answers whether the app may run a package. Whatever starts the package asks it, and nothing else stores the decision.

## The model

| Part | Meaning | Who decides |
|---|---|---|
| **`ExternalPackage.ID`** | The name a package is switched under, and the `isEnabled` gate | You, one `static let` per package |
| **`ExternalPackage`** | One package: name, license, purpose, source, whether it is optional, and what happens when its switch flips | You, once per package |
| **`ExternalPackagesTexts`** | Every word the screen shows around the packages | You, once per app |
| **`ExternalPackagesView`** | The screen: one section per package, with the switch under each optional one | ButchKit |

## Setup

Every app declares its packages in **one dedicated file**, `ExternalPackagesDefinition.swift`. That file is the whole definition: which packages, which of them are optional, what switching one does, and which words the screen shows.

```swift
// ExternalPackagesDefinition.swift — the one place the app's external packages are declared
import ButchKit
import SwiftUI
import TelemetryDeck

extension ExternalPackage.ID {
    static let telemetryDeck = ExternalPackage.ID("telemetryDeck")
}

extension ExternalPackage {
    static let all: [ExternalPackage] = [
        ExternalPackage(
            id: .telemetryDeck,
            name: "TelemetryDeck",
            license: "MIT",
            description: "text.packages.telemetrydeck.description",
            url: "https://github.com/TelemetryDeck/SwiftSDK",
            isOptional: true,
            onEnabledChange: { isEnabled in
                TelemetryDeck.setEnabled(isEnabled)
            }
        )
    ]
}

// Every word the screen shows. Written here, so Xcode extracts each key into the app's
// catalogs; see Localization below. `appName` is the app's display name from the bundle,
// so a renamed app cannot leave the old name in the text.
let externalPackagesTexts = ExternalPackagesTexts(
    title: "text.settings.licenses.title",
    emptyTitle: "text.settings.licenses.empty.title",
    purpose: Text("text.packages.purpose \(appName)"),
    sourceHint: String(localized: "accessibility.link.settings.licenses.source", table: "Accessibility"),
    toggle: { Text("toggle.packages.enabled \($0)") },
    toggleHint: String(localized: "accessibility.toggle.packages.enabled", table: "Accessibility")
)
```

Then open the screen with the app's one array and its one texts value:

```swift
ExternalPackagesView(packages: ExternalPackage.all, texts: externalPackagesTexts)
```

Both are always required. There is no second way in and nothing a missing modifier could leave blank.

A project that sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes each `ExternalPackage.ID` constant main-actor isolated. Declare it `nonisolated static let` when code off the main actor asks the gate.

That is the complete setup for the screen. There is no root modifier and no service to store. Starting each package at launch with the stored decision is the app's own code; see [Asking the gate](#asking-the-gate).

## Opening the screen

Anywhere. The screen reads no environment and needs no service, so it can sit in the settings, on a privacy page or in onboarding. It is a `List` with a navigation title, so give it a navigation container.

On iOS, push it from a settings list:

```swift
NavigationLink {
    ExternalPackagesView(packages: ExternalPackage.all, texts: externalPackagesTexts)
} label: {
    Label("link.settings.legal.licenses", systemImage: "checkmark.seal")
}
```

In a sheet, wrap it in a `NavigationStack` so the title shows.

On macOS, open it as a window of its own. A `Settings` window has no toolbar for a `NavigationStack` to put its back button in, and a window brings a title bar, a close button and Cmd-W without any of it being built:

```swift
// In the App's body
Window(externalPackagesTexts.title, id: ExternalPackagesView.windowID) {
    ExternalPackagesView(packages: ExternalPackage.all, texts: externalPackagesTexts)
}
.defaultSize(ExternalPackagesView.windowSize)

// In the settings row
@Environment(\.openWindow) private var openWindow

Button("link.settings.legal.licenses") {
    openWindow(id: ExternalPackagesView.windowID)
}
```

## Asking the gate

```swift
guard ExternalPackage.ID.telemetryDeck.isEnabled else { return }
```

Ask it where the package starts, typically once at launch. It is `true` until the user turns the switch off, and always `true` for a package that is not optional. It reads the stored decision on every call, so there is never a stale copy to keep in sync. For the same reason it is not something to ask per frame.

## Reacting to the switch

`onEnabledChange` runs the moment the user flips the switch. Start the package when it turns on, and clean up after it when it turns off:

```swift
onEnabledChange: { isEnabled in
    if isEnabled {
        Analytics.start()
    } else {
        Analytics.stop()
        Analytics.deleteCache()
    }
}
```

What it promises:

- It runs on the main actor, so it can call anything the app's own code can.
- It runs once per flip by the user, and only when the value really changed.
- The new value is already stored when it runs, so `ExternalPackage.ID.isEnabled` agrees with it.
- It does **not** run at launch. Whatever starts the package then reads `ExternalPackage.ID.isEnabled`.

`ExternalPackage.all` is a static constant, so the closure reaches static API, such as an SDK's own entry points or a static extension on the SDK. It cannot reach an instance the app holds in its state.

Where turning on and turning off are the same call with a different value, as for TelemetryDeck below, write the one call. Two branches with the same body are dead weight.

## Example: TelemetryDeck

TelemetryDeck has its own switch for this: `analyticsDisabled` on its configuration, documented as "Can be used to manually opt out users of tracking". The SDK keeps the configuration object it was handed and reads it on every signal, so a change to the kept object reaches the running SDK. The SDK documents that too: "Use an instance of `TelemetryManagerConfiguration` to configure this at initialization and during its lifetime."

Wrap the SDK in a static extension, keep the one configuration, and give the app two entry points:

```swift
import ButchKit
import TelemetryDeck

extension TelemetryDeck {
    private static let config = Config(appID: "YOUR-APP-ID")

    /// Called once, at launch, from the app's analytics service.
    static func start() {
        let isEnabled = ExternalPackage.ID.telemetryDeck.isEnabled
        config.sessionStatsEnabled = isEnabled
        setEnabled(isEnabled)
        initialize(config: config)
    }

    /// Called by the switch, through `onEnabledChange`.
    static func setEnabled(_ isEnabled: Bool) {
        config.analyticsDisabled = !isEnabled
    }
}
```

Four things that are easy to get wrong:

- **Initialize even when the user said no.** The SDK traps on any call made before `initialize`, including every signal the app sends elsewhere. Off is an SDK that runs and sends nothing.
- **Never `terminate()` to opt out.** It shuts the SDK down, and the next signal would trap in a debug build. Re-initializing to apply a new setting is not needed either, since the kept configuration already reaches the running SDK.
- **Session statistics are decided at launch.** The SDK writes them to `UserDefaults` every second, sent or not. It reads `sessionStatsEnabled` only when a session begins, and restarts that timer on every return to the foreground without asking again. Set it in `start()`: an opt-out made while the app runs stops the local statistics at the next launch, and nothing they record is sent in between.
- **Signals cached before the opt-out can still leave.** The SDK empties its cache without checking `analyticsDisabled`. They were recorded while the user allowed it.

TelemetryDeck says an opt-out is not legally required, since it collects no data governed by GDPR or CCPA, and recommends placing one in a settings screen if an app offers it. This screen is that place.

To see the decision in a diagnostics file, log it once at launch at `notice`, for example `Telemetry started: enabled=false`. See [LoggingStrategy.md](LoggingStrategy.md).

## Localization

ButchKit ships no strings and names no keys. Every word the screen shows is handed in through `ExternalPackagesTexts`, and every package's purpose through its `description`. Each key is therefore written in the app's own code, where Xcode finds it and extracts it into the app's catalog like any other string. See [ButchKit.md](ButchKit.md#localization) for the rule.

`description` is a `String.LocalizationValue`, resolved in `Bundle.main`, the consuming app. A package's `name` and `license` are not language and stay as written.

The switch's label is a closure that receives the package's name, so the key and its placeholder stand in the app's code together.

The code says "external packages"; what the user reads is the app's own word, typically "Licenses". The keys above follow the user's word.

Suggested wording:

| Key | English | German |
|---|---|---|
| Switch | `Use %@` | `%@ verwenden` |
| Switch hint | `Lets the app use this package.` | `Erlaubt der App, dieses Paket zu verwenden.` |
| Purpose caption | `Purpose in %@:` | `Verwendung in %@:` |

## What happens underneath

- **Storage.** Each switch writes `ButchKit.package.<id>.isEnabled` to `UserDefaults.standard`. The gate reads the same key, the same default and the same store, so the switch and the gate cannot disagree. The key keeps `package` in its name on purpose: a renamed key would reset every decision already stored on a device.
- **Default.** No stored value means enabled.
- **The switch.** It stores the value, then calls `onEnabledChange`. It does this in the switch's setter rather than in `onChange`: every open copy of the list watches the same stored value, and `onChange` would run the reaction once per open window.
- **Identity.** `ExternalPackage.ID` is deliberately not expressible by a string literal. A typo in an id would ask a key nobody writes and answer "enabled" forever, so the switch would move and nothing would stop. Declared once as a `static let`, a typo fails to compile instead.

## What it does not do

Deliberately, to stay one system:

- **No call at launch.** `onEnabledChange` is for the flip only. Starting a package with the stored decision is the app's code, at the place the package starts.
- **No switch for a required package.** Leave `isOptional` out, and nothing can turn the package off.
- **No other store.** The decision lives in the app's standard defaults. An app extension does not see those, so it cannot ask the gate.
- **No instance access from the reaction.** The closure lives in `ExternalPackage.all`, a static array, so it reaches static API only.

## Testing

- **In the app**, on a device: turn the switch off, relaunch, and check the analytics dashboard for test signals. None should arrive. Turn it back on and relaunch, and a new session should appear. Dashboards show signals with a few minutes' delay, so wait before calling it either way.
- **Previews** read `ExternalPackagesPreviewData.swift`, so the sample packages and words live in one place.

## Rules for agents

A compact checklist for anyone, human or AI, touching external packages in a ButchKit project:

- External packages are declared in one file, `ExternalPackagesDefinition.swift`: one `static let` per `ExternalPackage.ID`, one static array of `ExternalPackage` values in `ExternalPackage.all`, and one `ExternalPackagesTexts` value. Nowhere else.
- Pass the app's one array and one texts value, `ExternalPackage.all` and `externalPackagesTexts`, at every call site. Never build a second array or a second texts value for one entry point.
- Ask `ExternalPackage.ID.isEnabled` where a package starts. Never read the defaults key yourself, and never keep a copy of the answer.
- Put the reaction to the switch in `onEnabledChange`, on the package. Never wire it at a call site.
- Mark a package optional only if the app works without it.
- Every word is written in the app's code, in `ExternalPackagesTexts` and the package descriptions, so Xcode extracts it into the app's catalogs. Never add a key to a catalog by hand.
- For TelemetryDeck, opt out with `analyticsDisabled` on a kept configuration. Never skip `initialize`, and never `terminate()` to opt out.
