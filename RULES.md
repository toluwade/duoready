# DuoReady rules

Every rule has a stable ID. IDs are never reused or renumbered, so they are safe to reference in
configuration, suppressions and issue trackers. Run `duoready rules <ID>` for the same details in
your terminal.

To silence one occurrence, add `// duoready:ignore DR001` at the end of the line, or on its own on
the line above. To change a rule everywhere, use `.duoready.json`:

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
when the branches set geometry (sizes, spacing, padding, insets, margins, columns, frames, axes
or constraint constants), or when a ternary chooses between numbers:

```swift
let padding: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 40 : 16

if UIDevice.current.userInterfaceIdiom == .pad {
    layout.itemSize = CGSize(width: 300, height: 300)
}
```

### Not flagged

- Feature or presentation checks, such as `modalPresentationStyle = .popover` on iPad.
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

- Exact comparisons (`==`, `!=`) of a width or height with a known iPhone or iPad screen dimension
  in points, such as 375, 667 or 812.
- `switch` cases that match a width or height against one of those dimensions.
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
- A constraint whose priority is lowered in the same expression, e.g. `.withPriority(.defaultHigh)`.

### Fix

```swift
card.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor)
card.widthAnchor.constraint(lessThanOrEqualToConstant: 600)
```

### Limitations

Constants stored in variables, constraints defined in storyboards or XIBs, and priorities changed
after the constraint is created are not detected.

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
