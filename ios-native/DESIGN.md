# Native redesign — build 8

The October 16 camera screenshot showed large rectangular text buttons, a long instruction paragraph, and no clear label-framing area. Build 8 replaces that interface and redesigns the rest of the native app using the installed apple-design and apple-design-interaction skills. The hub's referenced child/reference files were not installed; its available rules and Apple's official guidance informed the implementation.

## App structure

- **Inventory** and **Settings** are peer destinations in a native tab bar. Each owns its navigation stack. Item details push; new/edit tasks use sheets; the camera uses a full-screen cover.
- Inventory starts with one scan action and a compact status overview, followed by expiry-sorted items. There are no All statuses or category picker rows. A status card can narrow the list; Clear is shown only while that selection is active. Search still covers names, categories, notes, and barcodes.
- Item rows use small product photos, a readable name/category hierarchy, a labelled status, and the date. Status carries text and a symbol as well as color. At accessibility text sizes the overview uses one column and row metadata stacks vertically.
- The item editor puts scanning first, then core item fields and a dedicated expiry section. Barcode/notes are collapsed until needed and expanded for existing values. An attached label photo and recognized text remain available. The date autofill, manual-edit protection, generation ownership, and explicit Save are retained.
- Item details give the photo, name, and expiry clear hierarchy. Quantity, barcode, notes, edit, and confirmed deletion remain available. Relative expiry text refreshes each minute and when returning to the app.
- Settings uses concise storage/privacy information, warning-day controls, grouped backup/restore/export actions, and the actual bundle version. Future-feature copy and outdated recognition/version claims were removed. Restoring still requires validated data and destructive confirmation.

## Camera

- 48-point circular Close and Torch controls, SF Symbol buttons, and a 76-point shutter replace the old text rectangles.
- A softly dimmed preview and corner frame guide label placement. This is a visual framing aid; OCR continues to read the full captured image.
- A bottom panel contains a short heading, a short hint, Photos, the shutter, and a visible tips action. Detailed focus/lighting advice is available through tips. Processing has an activity indicator.
- The control panel moves beside the preview in landscape. At larger text sizes, guidance can scroll independently while capture controls remain reachable. VoiceOver labels describe all symbol controls. Reduce Transparency replaces the blurred panel with an opaque background; increased contrast strengthens the frame.
- Session serialization, autofocus/lens policy, generation invalidation, permission handling, Photos handoff, rotation, bounded JPEG normalization, and SwiftUI-owned cover dismissal stay in the production controller.

## Visual system

Native grouped backgrounds and surfaces adapt to light/dark appearance. System blue is the interactive accent; red/orange/green communicate expiry status. Type and spacing establish hierarchy. Material is reserved for camera chrome and system navigation. No decorative motion or continuous animations were added.

The app remains local. No web resources, cloud services, OCR subscription, or API key were introduced.

## Product names — build 9

Scan product name opens a front-label camera mode with a taller guide. Prominent printed text can fill an untouched empty name. Up to three names from recognized text appear under the field, with explicit selection and ordinary editing. Existing names and edits during recognition are protected by the name draft's revision. Brand/product combinations are offered for review, not presented as verified identity. Label photos without dates do not produce an expiry warning in product mode. No product database or cloud model is used; unlabelled products cannot be identified from this feature.

## Verification and device acceptance

The standard verifier checks Swift behavior tests, the real arm64 iOS build, plist identity/version, linked frameworks, and absence of web/network source references. Existing source-wiring regressions cover the camera/editor handoff. These checks do not execute SwiftUI/UIKit or establish a visual pass on an iPhone.

On-device checks: inspect Inventory, empty/search/status selection, add/edit/detail, and Settings in light/dark appearance and accessibility text sizes. Exercise the camera in portrait/landscape with VoiceOver and Reduce Transparency; verify Close, Torch, Photos, tips, capture, no-date/manual-date entry, and automatic date filling. Confirm returning from capture leaves the editor visible and preserves other fields. Confirm export/restore confirmation and persisted inventory after relaunch.

## Form grouping and consistency — build 11

The expiry date picker and Scan expiry date action now share one native grouped Form section, together with recognition progress, warnings, autofill feedback, and candidate dates. The separate scan card above the item fields was removed. Product scan progress and warnings appear in the Item section beside the name input instead. Manual date entry or explicit candidate selection clears obsolete expiry warnings. Month-only and ambiguous dates continue to require review.

Required name/category fields and unresolved date review have contextual explanations for disabled Save. Scanning actions are disabled during OCR to avoid competing requests. At accessibility text sizes the date label and picker stack vertically. The inventory's empty filtered state offers Show all items; detail no longer repeats category; Settings shares the same section spacing and does not use navigation chevrons for export/import actions. Existing camera controls, native tabs, semantic colors, status filter selection, and destructive confirmations were reviewed and retained.

Validation compiles the actual iOS UI and runs existing logic regressions, including warning dismissal after manual date confirmation. SwiftUI appearance, text reflow, and VoiceOver still require inspection on an iPhone; no simulator or device screenshot pass is claimed.

## Apple references

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)
