# External packages

How to list an app's external packages with ButchKit, show their licenses, and let the user turn the optional ones off: one definition, one screen, one question everywhere else.

## What it is

Every app lists the third-party packages it ships, with their license and a way to the source. Some of those packages the app can do without, analytics being the usual one, and the user should be able to switch them off in the same place they learn about them. The module turns that into a fixed system:

1. **One definition.** The app declares its packages once, as `ExternalPackage` values in `ExternalPackage.all`. The screen renders them, so listing a new package is adding one entry.
2. **One switch per optional package.** An id declared `.optOut` or `.optIn` puts a switch under the package. Opt-out is on until the user turns it off, opt-in is off until the user turns it on.
3. **One question everywhere else.** `isEnabled` on the package's `ExternalPackage.ID`, such as `ExternalPackage.ID.analytics.isEnabled`, answers whether the app may run a package. Whatever starts the package asks it, and nothing else stores the decision.
4. **One page per package.** Each row opens the package's own page with its copyright notice and full license text, which is what MIT, BSD and Apache ask an app to include.

The component stands on its own: it uses no other part of ButchKit, only SwiftUI and `UserDefaults`.

## The model

| Part | Meaning | Who decides |
|---|---|---|
| **`ExternalPackage.ID`** | The name a package is switched under, whether it can be switched (`availability`), where the decision is stored, and the `isEnabled` gate | You, one `static let` per package |
| **`ExternalPackage`** | One package: name, license, purpose, source, and what happens when its switch flips | You, once per package |
| **`ExternalPackage.License`** | The license, with the copyright notice and the full text | You, once per package |
| **`ExternalPackagesTexts`** | Every word the screens show around the packages | You, once per app |
| **`ExternalPackagesView`** | The screen: one section per package, with the switch under each optional one | ButchKit |
| **`ExternalPackagesLink`**, **`ExternalPackagesWindow`** | The settings row that opens the screen, and the screen's window on the Mac | ButchKit |
| **`ExternalPackageToggle`** | One package's switch, for a second place such as a privacy screen | ButchKit |

## Setup

Every app declares its packages in **one dedicated file**, `ExternalPackagesDefinition.swift`. That file is the whole definition: which packages, which of them are optional, what switching one does, and which words the screens show.

The example uses an analytics SDK, because an analytics package is the typical optional one. Any other package is declared the same way.

```swift
// ExternalPackagesDefinition.swift: the one place the app's external packages are declared
import ButchKit
import SwiftUI

extension ExternalPackage.ID {
    // `nonisolated`, because a project with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, the
    // default of new Xcode projects, would otherwise keep the gate from code off the main actor.
    nonisolated static let analytics = ExternalPackage.ID(
        "analytics",
        availability: .optOut,
        appGroupID: "group.com.example.App"
    )
    nonisolated static let charts = ExternalPackage.ID("charts", availability: .required)
}

extension ExternalPackage {
    static let all: [ExternalPackage] = [
        ExternalPackage(
            id: .analytics,
            name: "Example Analytics",
            license: .mit(copyright: "Copyright (c) 2024 Example Author"),
            description: "text.packages.analytics.description",
            url: "https://example.com/analytics",
            note: "text.packages.analytics.note",
            onEnabledChange: { isEnabled in
                Analytics.setEnabled(isEnabled)
            }
        ),
        ExternalPackage(
            id: .charts,
            name: "Example Charts",
            license: .apache2(copyright: "Copyright 2024 Example Organization"),
            description: "text.packages.charts.description",
            url: "https://example.com/charts"
        )
    ]
}

// The app's display name from the bundle, so a renamed app cannot leave the old name in the
// text. The app's own constant: ButchKit does not provide one.
private let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "App"

// Every word the screens show. Written here, so Xcode extracts each key into the app's
// catalogs; see Localization below. Computed, because `ExternalPackagesTexts` is not
// `Sendable` and a global `let` of it does not compile in Swift 6 language mode.
var externalPackagesTexts: ExternalPackagesTexts {
    ExternalPackagesTexts(
        title: "text.settings.licenses.title",
        emptyTitle: "text.settings.licenses.empty.title",
        purpose: Text("text.packages.purpose \(appName)"),
        sourceHint: String(localized: "accessibility.link.settings.licenses.source", table: "Accessibility"),
        toggle: { Text("toggle.packages.enabled \($0)") },
        toggleHint: String(localized: "accessibility.toggle.packages.enabled", table: "Accessibility"),
        detail: .init(
            source: "button.packages.source",
            openHint: String(localized: "accessibility.link.settings.licenses.open", table: "Accessibility")
        )
    )
}
```

Then check the list in the app's tests, once:

```swift
@Test func externalPackagesAreValid() {
    #expect(ExternalPackage.issues(in: ExternalPackage.all).isEmpty)
}
```

`issues(in:)` names every mistake that would otherwise show only on a device: two packages under one id, a malformed source address, a reaction on a required package, and an id without an availability. The screen asserts the same in a debug build, so the first preview shows it too. A malformed address no longer crashes: a release build shows the package without its link.

That is the complete setup. There is no root modifier and no service to store. Starting each package at launch with the stored decision is the app's own code; see [Asking the gate](#asking-the-gate).

### Availability

Declared on the id, because the gate needs it:

| `availability` | Switch | Before the user decides | Fits |
|---|---|---|---|
| `.required` | none | on, always | Anything the app cannot run without |
| `.optOut` | yes | on | A package that collects nothing personal, such as privacy-friendly analytics |
| `.optIn` | yes | off | A package that may only run with consent, such as crash reporting with device data |

A package that becomes `.required` in an update is on for everyone, including a user who turned it off before: no switch is left to undo that, so the gate ignores the old decision. A package that moves from `.optOut` to `.optIn` keeps every decision a user made and changes only the default for everyone who never touched the switch.

### App group

With an `appGroupID`, the decision is stored in the app group, so an app extension that sends signals of its own can ask the same gate and respects the user's opt-out. Name the group the app already shares with its extensions, as in `PaywallConfiguration`, and compile the definition file into every target that asks.

An app that adds the group later loses nothing. The first time the app asks the gate, a decision still stored in the app's standard defaults is copied into the group. Ask the gate at launch, as below, and the extensions see the decision from then on.

### Licenses

`ExternalPackage.License` carries the copyright notice and the full text, which the package's page shows. Use a standard case only when the package's `LICENSE` file is the standard text:

| Case | For |
|---|---|
| `.mit(copyright:)` | The MIT License |
| `.apache2(copyright:)` | The Apache License 2.0 |
| `.bsd2(copyright:)`, `.bsd3(copyright:)` | The BSD 2-Clause and 3-Clause Licenses |
| `.custom(name:copyright:text:)` | Anything else, or a standard license in wording of its own |

Many packages change the standard text: some drop the attribution clause, some add one. Hand those in as `.custom` with the text from the package's own `LICENSE` file. An Apache package that ships a `NOTICE` file needs its contents too, so it is a `.custom` license with both texts. The copyright is the notice as the package states it, such as `"Copyright (c) 2024 Example Author"`.

The texts are legal texts in their original English and are not translated. This is an engineering aid, not legal advice.

## Opening the screen

Anywhere. The screen reads no environment and needs no service, so it can sit in the settings, on a privacy page or in onboarding. It is a `List` with a navigation title, and each row pushes the package's page, so give it a navigation stack.

In the settings, use the row ButchKit ships. It pushes the list on iPhone and iPad and opens the list's window on the Mac:

```swift
Section {
    ExternalPackagesLink(
        packages: ExternalPackage.all,
        texts: externalPackagesTexts,
        systemImage: "checkmark.seal",
        hint: String(localized: "accessibility.link.settings.licenses", table: "Accessibility")
    )
}
```

On the Mac, declare that window once in the app's body. A `Settings` window has no toolbar for a back button, so the list gets a window of its own, with a title bar, a close button, Cmd-W and a navigation stack for the package pages:

```swift
#if os(macOS)
ExternalPackagesWindow(packages: ExternalPackage.all, texts: externalPackagesTexts)
#endif
```

A window of the app's own must wrap the list in a `NavigationStack`, or the rows cannot open the package pages.

In a sheet, wrap the list in a `NavigationStack` too.

### The switch on its own

People who want to turn analytics off look under privacy, not under licenses. Show the same switch there as well:

```swift
Section {
    ExternalPackageToggle(package: ExternalPackage.all[0], texts: externalPackagesTexts)
}
```

It stores under the package's id and runs its `onEnabledChange`, so it and the switch in the list always agree and react the same way. There is no second place the decision lives. Hand it the package from `ExternalPackage.all`, not a second declaration of it.

## Asking the gate

```swift
guard ExternalPackage.ID.analytics.isEnabled else { return }
```

Ask it where the package starts, typically once at launch. It answers the stored decision, or the availability's default while the user has not decided, and `true` for a required package. It reads the stored decision on every call, so there is never a stale copy to keep in sync. For the same reason it is not something to ask per frame.

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
- The new value is already stored when it runs, so the package's `isEnabled` agrees with it.
- It does **not** run at launch. Whatever starts the package then reads its `isEnabled`.

`ExternalPackage.all` is a static constant, so the closure reaches static API, such as an SDK's own entry points or a static extension on the SDK. It cannot reach an instance the app holds in its state.

Where turning on and turning off are the same call with a different value, as for TelemetryDeck below, write the one call. Two branches with the same body are dead weight.

## Example: TelemetryDeck

TelemetryDeck has its own switch for this: `analyticsDisabled` on its configuration, documented as "Can be used to manually opt out users of tracking". The SDK keeps the configuration object it was handed and reads it on every signal, so a change to the kept object reaches the running SDK. The SDK documents that too: "Use an instance of `TelemetryManagerConfiguration` to configure this at initialization and during its lifetime."

Declare it as an opt-out package. Its [SwiftSDK](https://github.com/TelemetryDeck/SwiftSDK) ships a modified MIT license without the attribution clause, so it is a `.custom` license with the text of the SDK's own `LICENSE` file, not `.mit`:

```swift
extension ExternalPackage.ID {
    nonisolated static let telemetryDeck = ExternalPackage.ID("telemetryDeck", availability: .optOut)
}

// In ExternalPackage.all
ExternalPackage(
    id: .telemetryDeck,
    name: "TelemetryDeck",
    license: .custom(name: "MIT", copyright: "…", text: "…"), // both from the SDK's LICENSE file
    description: "text.packages.telemetrydeck.description",
    url: "https://github.com/TelemetryDeck/SwiftSDK",
    note: "text.packages.telemetrydeck.note",
    onEnabledChange: { isEnabled in
        TelemetryDeck.setEnabled(isEnabled)
    }
)
```

The `note` suits the session statistics below: turning the switch off stops sending at once, but the local statistics only at the next launch. A line such as "Takes full effect at the next launch." says so where the user flips the switch.

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

ButchKit ships no strings and names no keys. Every word the screens show is handed in through `ExternalPackagesTexts`, and every package's purpose and note through the package. Each key is therefore written in the app's own code, where Xcode finds it and extracts it into the app's catalog like any other string. See [ButchKit.md](ButchKit.md#localization) for the rule. The license texts are the one exception: they are legal texts, not interface words, and stay in their original English.

`description` is handed in as a `String.LocalizationValue` and resolved in `Bundle.main`, the consuming app. It is resolved once, when the entry is created, and stored as a `String`: since `ExternalPackage.all` is a static constant, the language is the one the app runs in when the array is first read. A package's `name` and `license` are not language and stay as written. `note` is a `LocalizedStringResource`, resolved when it is shown.

The switch's label is a closure that receives the package's name, so the key and its placeholder stand in the app's code together.

The code says "external packages"; what the user reads is the app's own word, typically "Licenses". The keys above follow the user's word.

`detail` is optional, so an app that has not written its words yet keeps building. Without it, each row opens the package's source directly, as in ButchKit 2.0, and no license text is shown.

Suggested wording:

| Key | English | German |
|---|---|---|
| Switch | `Use %@` | `%@ verwenden` |
| Switch hint | `Lets the app use this package.` | `Erlaubt der App, dieses Paket zu verwenden.` |
| Purpose caption | `Purpose in %@:` | `Verwendung in %@:` |
| Source link | `Source code` | `Quellcode` |
| Row hint | `Shows the license of this package.` | `Zeigt die Lizenz dieses Pakets.` |

## What happens underneath

- **Storage.** Each switch writes `ButchKit.package.<id>.isEnabled` to the app group named on the id, or to `UserDefaults.standard` without one. The gate reads the same key, the same default and the same store, so the switch and the gate cannot disagree. The key keeps `package` in its name on purpose: a renamed key would reset every decision already stored on a device.
- **Default.** No stored value means on for `.optOut`, off for `.optIn`. A `.required` package reads no stored value at all.
- **The switch.** It stores the value through the id, then calls `onEnabledChange`. It does this in the switch's setter rather than in `onChange`: every open copy of the switch watches the same stored value, and `onChange` would run the reaction once per copy.
- **Identity.** `ExternalPackage.ID` is deliberately not expressible by a string literal. A typo in an id would ask a key nobody writes and answer its default forever, so the switch would move and nothing would stop. Declared once as a `static let`, a typo fails to compile instead. Two ids with one name are equal, whatever their availability, because the name is what the decision is stored under.

## What it does not do

Deliberately, to stay one system:

- **No call at launch.** `onEnabledChange` is for the flip only. Starting a package with the stored decision is the app's code, at the place the package starts.
- **No switch for a required package.** Declare the id `.required`, and nothing can turn the package off.
- **No instance access from the reaction.** The closure lives in `ExternalPackage.all`, a static array, so it reaches static API only.
- **No reaction to changes from elsewhere.** Only a switch runs `onEnabledChange`. Nothing else writes the decision.

## Moving from ButchKit 2.0

2.1 keeps every 2.0 declaration building, with deprecation warnings that lead here. The old declarations behave exactly as before, including the gap the new ones close: a package that was optional once stays off for a user who turned it off, even after it became required.

1. Give each id its availability: `ExternalPackage.ID("analytics")` becomes `ExternalPackage.ID("analytics", availability: .optOut)`. Keep the name, or every user starts at the default again.
2. Drop `isOptional:` from each package, and replace `license: "MIT"` with a `License` and its copyright notice.
3. Add `detail:` to `ExternalPackagesTexts`, with its two keys.
4. Replace the settings row and the Mac window with `ExternalPackagesLink` and `ExternalPackagesWindow`. An existing `Window` of the app's own needs a `NavigationStack` around the list, or the package pages cannot open.
5. Add the `issues(in:)` test.
6. With an app extension that asks the gate, add the `appGroupID`.

`ExternalPackage.url` is now optional. Code that reads it, rather than only declaring it, unwraps it.

## Testing

- **In the app's tests**, `ExternalPackage.issues(in: ExternalPackage.all)` is empty. See [Setup](#setup).
- **In the app**, on a device: turn the switch off, relaunch, and check the analytics dashboard for test signals. None should arrive. Turn it back on and relaunch, and a new session should appear. Dashboards show signals with a few minutes' delay, so wait before calling it either way.
- **With an app group**, turn the switch off in a 2.0 build, update to the build with the group, launch once, and check that the switch is still off and the extension sends nothing.
- **Previews** read `ExternalPackagesPreviewData.swift`, so the sample packages and words live in one place.

## Rules for agents

A compact checklist for anyone, human or AI, touching external packages in a ButchKit project:

- External packages are declared in one file, `ExternalPackagesDefinition.swift`: one `nonisolated static let` per `ExternalPackage.ID`, one static array of `ExternalPackage` values in `ExternalPackage.all`, and one `ExternalPackagesTexts` value. Nowhere else.
- Declare every id with its `availability`. Never use the deprecated `ExternalPackage.ID(_:)` or `isOptional:`, and never rename an id that has shipped.
- Choose `.required` only if the app cannot run without the package, `.optIn` for anything that needs consent, and `.optOut` otherwise.
- Declare the license the package's `LICENSE` file actually states. When its text differs from the standard one, use `.custom` with the file's text.
- Pass the app's one array and one texts value, `ExternalPackage.all` and `externalPackagesTexts`, at every call site. Declare the texts value as a computed property, never a global `let`. Never build a second array or a second texts value for one entry point.
- Open the list with `ExternalPackagesLink`, and on the Mac declare `ExternalPackagesWindow`. A switch outside the list is an `ExternalPackageToggle`, never a `Toggle` of its own.
- Ask the package's `isEnabled`, such as `ExternalPackage.ID.analytics.isEnabled`, where a package starts. Never read the defaults key yourself, and never keep a copy of the answer.
- Put the reaction to the switch in `onEnabledChange`, on the package. Never wire it at a call site.
- Keep the `issues(in:)` test in the app's tests.
- Every word is written in the app's code, in `ExternalPackagesTexts` and the packages, so Xcode extracts it into the app's catalogs. Never add a key to a catalog by hand.
- If the app uses TelemetryDeck, opt out with `analyticsDisabled` on a kept configuration. Never skip `initialize`, and never `terminate()` to opt out.
