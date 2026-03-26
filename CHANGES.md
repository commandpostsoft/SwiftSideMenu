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
