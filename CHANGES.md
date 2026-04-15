# Changes

## Fixes Applied from Upstream Issues

### Fix 1: Privacy Manifest (#699)
Apple requires `PrivacyInfo.xcprivacy` for SDK submissions since spring 2024. Added an empty privacy manifest declaring no tracking, no collected data, and no required-reason APIs.

- Created `Pod/Classes/PrivacyInfo.xcprivacy`
- Updated `Package.swift` to include the resource (bumped swift-tools-version to 5.3)
- Updated `SideMenu.podspec` with `resource_bundles`

### Fix 2: Typo Fix (#658)
Fixed "vierw" to "view" in `SideMenuPresentationController.swift` doc comment.

### Fix 3: Delegate Nil Before Callback (#667)
When the menu was dismissed, `viewDidDisappear` set `transitionController = nil`, which deallocated the `SideMenuTransitionController`. Since `SideMenuAnimationController` holds a weak reference to its delegate (the transition controller), `animationEnded(_:)` would find a nil delegate, so `didDismiss` never fired and `sideMenuManager.sideMenuTransitionDidDismiss(menu:)` was never called.

**Fix**: Moved the `transitionController = nil` cleanup from `viewDidDisappear` into the `didDismiss` delegate callback, so the transition controller stays alive until after `animationEnded` fires.

### Fix 4: macOS/Catalyst Compilation Guards (#689)
SPM users in multi-platform projects got compilation errors because UIKit isn't available on macOS. Wrapped all 11 UIKit-dependent source files with `#if canImport(UIKit)` / `#endif`.

### Fix 5: Init with Settings (#681)
Already implemented - the initializer at `SideMenuNavigationController.swift` line 167 already accepts `settings: SideMenuSettings = SideMenuSettings()`. No work needed.

### Fix 6: Crash when UISheetPresentationController conflicts with SideMenu transitions
If `modalPresentationStyle` was changed from `.overFullScreen` (e.g., by user code, another library, or iOS defaults on iPad), UIKit would create a `UISheetPresentationController` that conflicted with SideMenu's custom `SideMenuAnimationController` / `SideMenuPresentationController`, causing an `NSInvalidArgumentException` during gesture recognizer setup.

**Fix**: Added a `modalPresentationStyle` override on `SideMenuNavigationController` that enforces `.overFullScreen` and prints a warning if other code attempts to change it. Follows the same pattern as the existing `transitioningDelegate` guard.

- Modified `Pod/Classes/SideMenuNavigationController.swift` (added property override)
- Modified `Pod/Classes/Print.swift` (added warning message)

### Fix 7: iPad Rotation Glitch (#656, #679)
On iPad, when the side menu was open and the app went to background then returned, the presenting view could rotate 90 degrees. The root cause was `.overFullScreen` interacting poorly with iPad's view hierarchy management during app lifecycle transitions.

**Fix**: iPad now uses `.overCurrentContext` instead of `.overFullScreen`. Both styles keep the presenting view in the hierarchy, so the custom transition system works identically — the difference is `.overCurrentContext` handles iPad's view transform restoration correctly during background/foreground cycles. The `modalPresentationStyle` override was updated to allow both safe styles through while still blocking problematic ones (`.pageSheet`, `.automatic`, etc.).

- Modified `Pod/Classes/SideMenuNavigationController.swift` (iPad detection in `setup()`, updated override guard)

### Fix 8: Skip Transition During Backgrounding (#660)
iOS fires `viewWillTransition(to:with:)` when the app is backgrounding. When this ran with a nil `presentationController`, the animation coordinator's methods silently became no-ops via optional chaining, leaving the view hierarchy in a corrupted state (contributing to the rotation glitch from Fix 7).

**Fix**: Added `.background` app state check to the guard in `viewWillTransition(to:with:)` so transition/layout code is skipped when the app is backgrounding. Only `.background` is checked — `.inactive` was deliberately excluded because apps go inactive during Control Center, Notification Center, system dialogs, and iPad multitasking transitions, and rotation during those states should still be handled.

- Modified `Pod/Classes/SideMenuNavigationController.swift` (added app state guard in `viewWillTransition`)

### Fix 9: Crash When Child VC Presents .formSheet/.pageSheet
When a view controller within the SideMenu navigation stack presented a modal using `.formSheet` or `.pageSheet`, UIKit created a `UISheetPresentationController` that conflicted with SideMenu's custom `SideMenuTransitionController`. The transition controller unconditionally returned custom animation/interaction controllers for all presentations — not just SideMenu's own — causing `NSInvalidArgumentException` crashes via `___forwarding___` when `UISheetPresentationController` sent selectors that `SideMenuTransitionController` didn't respond to.

Two crash variants were observed in production:
1. UIButton layout corruption during CA transaction layout pass (downstream view hierarchy corruption)
2. Gesture recognizer initialization crash during `UISheetPresentationController.presentationTransitionWillBegin`

**Fix**: Added type guards to all four `UIViewControllerTransitioningDelegate` methods in `SideMenuTransitionController`. The animation controller methods now check that the presented/dismissed VC is a `SideMenuNavigationController` before returning custom animators. The interaction controller methods check that the animator is a `SideMenuAnimationController`. For any other presentation, the methods return `nil`, telling UIKit to use its standard presentation infrastructure.

- Modified `Pod/Classes/SideMenuTransitionController.swift` (added guards to delegate methods)

### Fix 10: Code Review Fixes
Addressed issues found during code review of Fixes 3, 7, 8, and 9.

**Non-animated dismiss leaked `transitionController`**: Fix 3 moved `transitionController = nil` from `viewDidDisappear` to the `didDismiss` delegate callback (which fires from `animationEnded`). However, for non-animated dismissals where UIKit skips the custom transition system, `animationEnded` never fires, so the callback never ran and `transitionController` was never cleaned up. A stale controller would be reused on the next present with outdated config.

**Fix**: Added a deferred fallback (`DispatchQueue.main.async`) in `viewDidDisappear` that nils out `transitionController` on the next run loop iteration. For animated dismissals, `animationEnded` fires first and the async block is a no-op. For non-animated dismissals, it catches the case where the callback chain never executed. Also cleaned up the dead empty `if isBeingDismissed {}` block.

**`.inactive` state check too aggressive**: Fix 8 checked both `.background` and `.inactive` in `viewWillTransition`. The `.inactive` check blocked legitimate rotation handling during Control Center, Notification Center, system dialogs, and iPad multitasking transitions.

**Fix**: Removed the `.inactive` check, keeping only `.background`.

- Modified `Pod/Classes/SideMenuNavigationController.swift`

### Fix 11: iPadOS 26 Window-Control ("Traffic Light") Overlap
On iPadOS 26 in Stage Manager / windowed mode, the scene's window-control pill overlays the top-left corner of the window. A left-side `SideMenuNavigationController`'s leading nav-bar items (back button, title, bar button items) sat underneath the pill and were obscured / not reliably tappable. `UINavigationBar`'s built-in iOS 26 corner adaptation (the same `UIView.LayoutRegion` API exposed to app code) wasn't kicking in through SideMenu's `.overCurrentContext` modal presentation path — the scene's chrome info isn't propagated to the presented nav controller's view the way it is for top-level view controllers.

**Fix**: Compute the horizontal corner-adaptation delta from the containing window and apply it as `additionalSafeAreaInsets` on the presented menu in `SideMenuPresentationController.containerViewWillLayoutSubviews()`.

```swift
let adapted = window.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
let baseline = window.edgeInsets(for: .safeArea())
let extraLeft = leftSide ? max(0, adapted.left - baseline.left) : 0
let extraRight = leftSide ? 0 : max(0, adapted.right - baseline.right)
```

Key implementation notes:

1. **Read from `containerView.window`, not the menu's own view.** The window's corner-adaptation is derived from scene chrome and is not affected by anything we write to a descendant VC's `additionalSafeAreaInsets`. An earlier attempt that read from the menu's own view froze the app: `.safeArea()` baseline itself reflected the `additionalSafeAreaInsets` we'd just written, so on the next layout pass the delta flipped back to zero, then back to the clearance, etc. `UINavigationController._eagerlyUpdateSafeAreaInsets` spun in `_widthForLayout` on each oscillation until the main thread wedged. Sourcing from the window breaks that feedback loop.

2. **`containerView` alone isn't enough under `.overCurrentContext`.** First cut of this fix read `containerView.edgeInsets(for:)` and got a zero delta — on iPad the transition container can be nested inside the presenter's content area and miss the scene-level corner-adaptation signal. `containerView.window` is always the scene root.

3. **Physical `leftSide` gate is RTL-safe.** SideMenu's `leftSide` flag is used physically (`frameOfPresentedViewInContainerView` sets `origin.x = leftSide ? 0 : rect.width - config.menuWidth`), and `edgeInsets(for:)` returns physical insets, so the gate lines up in every locale regardless of whether iPadOS flips the pill in RTL — the `extraLeft`/`extraRight` path handles whichever physical side matches the menu's position.

4. **`#if compiler(>=6.2)` + `if #available(iOS 26.0, *)`**. The new `UIView.LayoutRegion` symbols don't exist in pre-iOS-26 SDKs, so the compiler guard is necessary in addition to the runtime availability check. On older toolchains or OSes the fix is a no-op and the library behaves as before.

5. **Dismissal cleanup**: `dismissalTransitionDidEnd(_:)` zeros the horizontal component of `additionalSafeAreaInsets` when a dismiss completes. `SideMenuManager` caches menu instances for reuse, and without the reset a stale inset from a previous window could briefly render during the first layout pass of a re-present on a different scene — common in Stage Manager when dragging the window between displays. Top/bottom are intentionally untouched because the library never writes them.

- Modified `Pod/Classes/SideMenuPresentationController.swift` (new `applyWindowControlInsetsIfNeeded` helper, called from `containerViewWillLayoutSubviews`; reset in `dismissalTransitionDidEnd`)
