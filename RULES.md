# DuoReady rules

DuoReady skips test code by default (test targets such as `AppTests/`, folders like
`TestHelpers/`, and files such as `FeedViewTests.swift`), because tests often fix sizes on
purpose. Pass `--include-tests` or set `"includeTests": true` to scan them too.

Every rule has a stable ID. IDs are never reused or renumbered, so they are safe to reference in
configuration, suppressions and issue trackers. Run `duoready rules <ID>` for the same details in
your terminal.

To silence one occurrence, add `// duoready:ignore DR001` at the end of the line, or on its own on
the line above. To silence a rule for a whole Swift file, add `// duoready:ignore-file DR001`
anywhere in it. To change a rule everywhere, use `.duoready.json`:

```json
{ "version": 1, "rules": { "DR002": { "enabled": false } } }
```

| ID | Title | Default severity | Confidence |
| --- | --- | --- | --- |
| [DR001](#dr001) | `UIScreen.main` usage | warning | high |
| [DR002](#dr002) | Layout decisions based on orientation | warning | medium |
| [DR003](#dr003) | Device-type checks used to select layout dimensions | warning | medium |
| [DR004](#dr004) | Fixed screen dimensions used for layout decisions | warning | high |
| [DR005](#dr005) | Constraints that pin content to screen-sized constants | warning | medium |
| [DR006](#dr006) | SwiftUI frames with screen-sized fixed dimensions | info | medium |
| [DR007](#dr007) | Custom bars the system can't present vertically | warning | high |
| [DR008](#dr008) | Bar items with a title but no icon | info | high |
| [DR009](#dr009) | `ArrangementView` inside a list, scroll view or split view | warning | high |
| [DR010](#dr010) | `UIRequiresFullScreen` no longer prevents resizing | warning | high |
| [DR011](#dr011) | UIKit app without the scene life cycle | error | medium |
| [DR012](#dr012) | App-wide window lookups | warning | high |

---

## DR001

**`UIScreen.main` usage** · UIKit · warning · high confidence

### Why

`UIScreen.main` describes a single, fixed display. When an app's window can be resized, moved
between displays or shown alongside other apps, the main screen's size no longer matches the space
your UI actually has. Apple deprecated `UIScreen.main` in iOS 16 for this reason.

### Flagged

```swift
let itemWidth = UIScreen.main.bounds.width / 3
```

### Fix

Read geometry from the context that owns the UI. The suggestion DuoReady prints depends on what
the code reads:

| Reading | Use instead |
| --- | --- |
| `bounds`, `nativeBounds` | `view.bounds` or `view.window?.bounds` (UIKit); `GeometryReader` or `containerRelativeFrame` (SwiftUI) |
| `scale`, `nativeScale` | `traitCollection.displayScale` (UIKit); `@Environment(\.displayScale)` (SwiftUI) |
| `traitCollection` | The `traitCollection` of the view or view controller being laid out |
| `brightness`, `maximumFramesPerSecond` | `view.window?.windowScene?.screen` |

```swift
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let itemWidth = view.bounds.width / 3
}
```

DuoReady never rewrites this automatically: the correct replacement depends on which view, window
or scene is in scope.

### Limitations

Matches the literal expressions `UIScreen.main` and `UIKit.UIScreen.main`. It does not track a
screen stored in a variable or obtained through other APIs.

---

## DR002

**Layout decisions based on orientation** · UIKit · warning · medium confidence

### Why

Orientation describes how the device is held, not how much space the app has. A window can be
narrow while the device is in landscape, or wide while it is in portrait. Layouts chosen from
orientation break when the window is resized or shares the display.

### Flagged

Orientation values (`UIDevice.current.orientation`, `interfaceOrientation`,
`statusBarOrientation`) used as the condition of an `if`, `guard`, `while`, `switch` or ternary:

```swift
if UIDevice.current.orientation.isLandscape {
    stack.axis = .horizontal
}
```

### Not flagged

- Orientation that is read but not branched on, e.g. logging or storing it.
- Decisions that drive camera, video or image rotation (`videoOrientation`, `videoRotationAngle`,
  `imageOrientation`, …). Device orientation is the correct input there.

### Fix

Choose layouts from the available size:

```swift
override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    stack.axis = traitCollection.horizontalSizeClass == .regular ? .horizontal : .vertical
}
```

In SwiftUI, use `@Environment(\.horizontalSizeClass)` or `ViewThatFits`.

### Limitations

Only reports orientation used directly in a condition. Orientation copied into a variable and
branched on later is not tracked. A bare `interfaceOrientation` (implicit `self`) is not matched.

---

## DR003

**Device-type checks used to select layout dimensions** · UIKit and SwiftUI · warning · medium confidence

### Why

The device type doesn't tell you how much space the app has. An iPad app can run in a window
narrower than an iPhone, and a phone-sized device can show a wide window. Sizes picked from
`userInterfaceIdiom` are wrong whenever the window doesn't match the device.

### Flagged

`userInterfaceIdiom` compared with `.pad` or `.phone` in an `if`, `guard`, `switch` or ternary,
when the branches set geometry, or when a ternary chooses between numbers. A branch sets
geometry when it uses a name such as `size`, `itemSize` or `contentSize`, or a name ending in
width, height, padding, spacing, inset, margin, frame, constant, axis or columns (for example
`cellWidth` or `leadingPadding`). DuoReady reports one finding per condition.

```swift
let padding: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 40 : 16

if UIDevice.current.userInterfaceIdiom == .pad {
    layout.itemSize = CGSize(width: 300, height: 300)
}
```

### Not flagged

- Conditions that also check a size class, such as
  `idiom == .pad && horizontalSizeClass == .regular`. They already adapt to the window.
- Feature or presentation checks, such as `modalPresentationStyle = .popover` on iPad.
- Names in the condition itself, such as `prefs.showSecondaryColumn`.
- Checks for other idioms (`.mac`, `.tv`, `.carPlay`, `.vision`), which are platform decisions.

### Fix

```swift
let padding: CGFloat = traitCollection.horizontalSizeClass == .regular ? 40 : 16
```

In SwiftUI, read `@Environment(\.horizontalSizeClass)`.

### Limitations

An idiom stored in a variable (for example `let isPad = …`) and checked later is not tracked.
Code inside `#if os(macOS)` and other non-iOS blocks is ignored.

---

## DR004

**Fixed screen dimensions used for layout decisions** · UIKit and SwiftUI · warning · high confidence

### Why

Checks such as `height == 812` or `screenHeight >= 667` identify a particular device model by its
screen size. When the app's window is resized, or the app runs on a device with new dimensions,
these checks pick the wrong layout, or none at all.

### Flagged

- Exact comparisons (`==`, `!=`) of a view's, window's, screen's or `GeometryReader` proxy's width
  or height with a known iPhone or iPad screen dimension in points, such as 375, 667 or 812.
- `switch` cases that match such a width or height against one of those dimensions.
- Ordered comparisons (`<`, `>`, `<=`, `>=`) with one of those dimensions, when the measured value
  comes from the screen (its expression mentions "screen").

```swift
if view.bounds.height == 812 { topInset = 44 }
let hasNotch = UIScreen.main.bounds.height >= 812
```

### Not flagged

- Breakpoints on the view's own size that aren't device dimensions, such as
  `view.bounds.width > 600`.
- Numbers that aren't compared with a width or height, such as `retryCount == 375`.
- Sizes of content rather than UI, such as `thumbnail.width == 320` or `image.size.height == 812`.

### Fix

Use the safe area for insets (`view.safeAreaInsets`, `.safeAreaInset`) and size classes or the
available width for layout choices.

### Limitations

Arithmetic on either side of a comparison is not evaluated. The table of dimensions covers iPhone
and iPad models up to the time of writing and needs updating when new devices ship. Physical pixel
values (for example from `nativeBounds`) are not in the table.

---

## DR005

**Constraints that pin content to screen-sized constants** · UIKit · warning · medium confidence

### Why

A required constraint that sets a view's width to 320 points or more, or its height to 568 points
or more, assumes the window is at least that large. In a narrower or shorter window the content
clips, or Auto Layout has to break constraints.

### Flagged

```swift
card.widthAnchor.constraint(equalToConstant: 375)
NSLayoutConstraint(item: card, attribute: .width, relatedBy: .equal,
                   toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 414)
```

### Not flagged

- Constraints relative to another view, or capped with `lessThanOrEqualToConstant`.
- Small fixed sizes (widths under 320, heights under 568).
- A constraint whose priority is lowered, either in the same expression
  (`.withPriority(.defaultHigh)`) or later in the same block:

  ```swift
  let width = view.widthAnchor.constraint(equalToConstant: 99999)
  width.priority = .defaultLow
  ```

### Fix

```swift
card.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor)
card.widthAnchor.constraint(lessThanOrEqualToConstant: 600)
```

### Limitations

Constants stored in variables and constraints defined in storyboards or XIBs are not detected. A
priority changed in a different method or block is not recognized.

---

## DR006

**SwiftUI frames with screen-sized fixed dimensions** · SwiftUI · info · medium confidence

### Why

`.frame(width:height:)` proposes an exact size regardless of the space available. A fixed width of
320 points or more, or a fixed height of 568 points or more, is about the size of a whole screen,
so the view clips or overflows in a smaller window.

### Flagged

```swift
Image("hero").frame(width: 390, height: 844)
```

DuoReady reports one finding per `.frame` call, naming whichever dimensions are too large.

### Not flagged

- Flexible frames: `maxWidth`, `minWidth`, `idealWidth`, `.infinity`.
- Small fixed frames, such as icons.
- Frames inside `#Preview`, `PreviewProvider` and non-iOS `#if` blocks, where a fixed size
  deliberately simulates a device or window.

### Fix

```swift
Image("hero")
    .resizable()
    .scaledToFit()
    .frame(maxWidth: 400)
```

Or use `containerRelativeFrame` or `GeometryReader` when the size really depends on the container.

### Limitations

Only literal values are checked. A fixed frame inside a scroll view can be intentional, which is
why this rule defaults to `info`.

---

## DR007

**Custom bars the system can't present vertically** · UIKit · warning · high confidence

### Why

On iPhone Duo, the system presents navigation bars, toolbars and tab bars vertically on the side of
the display in some poses. It can only do that for bars it manages. Apple's
[iPhone Duo guidance](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
says to "set toolbar items on a view controller that you add to a navigation controller, instead of
creating a custom bar for your view based on UIToolbar, UINavigationBar, or UITabBar."

### Flagged

```swift
let toolbar = UIToolbar()
view.addSubview(toolbar)
```

### Not flagged

- Subclasses, such as a branded bar passed to `UINavigationController(navigationBarClass:toolbarClass:)`.
- `UIToolbar` in files that set an `inputAccessoryView`, where a toolbar above the keyboard is expected.

### Fix

```swift
toolbarItems = [shareItem, .flexibleSpace(), deleteItem]
navigationController?.setToolbarHidden(false, animated: false)
```

### Limitations

Bars created in Interface Builder are not detected.

---

## DR008

**Bar items with a title but no icon** · UIKit and SwiftUI · info · high confidence

### Why

When iPhone Duo presents bars vertically, it shows items as icons. Apple: "If your item has a
title and doesn't have an icon, the system doesn't present it vertically." Items with both work in
every pose, because the system chooses the title or the icon to fit.

### Flagged

```swift
.toolbar { Button("Edit") { edit() } }
UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(sort))
```

### Not flagged

- Buttons inside a `Menu`, which shows titles anyway.
- Items with `cancellationAction`, `confirmationAction`, `destructiveAction`, `keyboard`, `principal`
  or `status` placement.
- Back-button items (`backBarButtonItem`) and empty titles.
- UIKit items in files that set an `inputAccessoryView` (keyboard toolbars).

### Fix

```swift
.toolbar { Button("Edit", systemImage: "pencil") { edit() } }
UIBarButtonItem(title: "Sort", image: UIImage(systemName: "arrow.up.arrow.down"), primaryAction: sortAction)
```

### Limitations

Items built in a separate view or helper function are not seen. This rule is `info` because a
hidden item may still be reachable another way.

---

## DR009

**`ArrangementView` inside a list, scroll view or split view** · SwiftUI · warning · high confidence

### Why

An arrangement view lays out a primary and a secondary view around iPhone Duo's fold. Apple: "Avoid
placing an arrangement view inside a navigation split view, list, scroll view, or other container
that might cause part of your view to become inaccessible."

### Flagged

```swift
ScrollView {
    ArrangementView { MapView() } secondary: { DetailsView() }
}
```

### Fix

Make the arrangement view the outer container, and scroll inside it:

```swift
ArrangementView {
    MapView()
} secondary: {
    ScrollView { DetailsView() }
}
```

### Limitations

Only containers written in the same view body are seen. An arrangement view in its own view type,
which a list contains elsewhere, is not reported.

---

## DR010

**`UIRequiresFullScreen` no longer prevents resizing** · project configuration · warning · high confidence

### Why

`UIRequiresFullScreen` is deprecated. Apple's
[TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key):
"Starting in iOS 27 and iPadOS 27, `UIRequiresFullScreen` no longer opts your app out of resizing
on either platform. Instead, the system resizes your app's scene discretely." This applies when you
build with the iOS 27 SDK, so an app that relied on the key is resized anyway, on iPhone Duo and
on iPad.

### Flagged

- `<key>UIRequiresFullScreen</key><true/>` in any `.plist` in the scanned folder.
- `INFOPLIST_KEY_UIRequiresFullScreen = YES` in an Xcode project's build settings.

### Not flagged

- A plist that also sets `UIRequiresFullScreenIgnoredStartingWithVersion`, because its migration is
  already planned.

### Fix

Make your layouts resizable (the other rules help), then remove the key or build setting. TN3192
describes `UIRequiresFullScreenIgnoredStartingWithVersion` if you need more time.

### Limitations

Settings in `.xcconfig` files, and Info.plist files outside the scanned folder, are not read.

---

## DR011

**UIKit app without the scene life cycle** · project configuration · error · medium confidence

### Why

Apple's
[TN3187](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle):
"In the next major release following iOS 26, UIScene lifecycle will be required when building with
the latest SDK; otherwise, your app won't launch." Scenes are also what lets the system resize an
app and move it between iPhone Duo's displays.

### Flagged

A Swift app delegate marked `@main` or `@UIApplicationMain`, including subclasses of framework app
delegates such as `FlutterAppDelegate`, when the scanned folder has none of:

- a `UIApplicationSceneManifest` with scene configurations in a `.plist`,
- an implementation of `application(_:configurationForConnecting:options:)`,
- a SwiftUI `App`, or
- the `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` build setting.

### Fix

Add a scene manifest with one configuration and a `UIWindowSceneDelegate`, and move window setup
from the app delegate into the scene delegate. A single scene is enough. TN3187 walks through it.

### Limitations

Objective-C app delegates are not read. Scan the whole app so its Info.plist is included;
scanning only a subfolder can produce a false report, which `// duoready:ignore DR011` on the app
delegate silences.

---

## DR012

**App-wide window lookups** · UIKit · warning · high confidence

### Why

iPhone Duo can run two apps side by side in Split View, and show two windows of the same app.
App-wide lookups such as `UIApplication.shared.keyWindow`, `.windows` or `connectedScenes.first`
return an arbitrary window, which may not be the one your view is in or have its size. `keyWindow`
and `windows` are also deprecated.

### Flagged

```swift
let width = UIApplication.shared.windows.first?.bounds.width
let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive })
```

### Not flagged

- `connectedScenes.first?.delegate`, which reaches app state rather than a window.
- A scene's own `windows`, such as `view.window?.windowScene?.windows`.

### Fix

Use the window your UI is in: `view.window`, `view.window?.windowScene`, or the scene passed to
your scene delegate.

### Limitations

A window or scene stored earlier and passed around is not tracked.
