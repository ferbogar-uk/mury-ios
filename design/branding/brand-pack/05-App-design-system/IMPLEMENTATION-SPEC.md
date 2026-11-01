# MURY UI brand specifications

These are visual specifications and static editable brand examples, not a runnable application.

- Read type/colour/spacing/radius roles from ../04-Colours-and-type/mury-tokens.json and the matching CSS. Native colour asset examples are in MuryColors.xcassets.
- Minimum interactive target 44 × 44 design units; primary button 52 high, radius 16, horizontal padding 24. Cards use radius 20. Inputs have at least 48 height and a visible 1-unit contrasting outline.
- Body 16/24 at Rubik 400, label 14/20 at 600, captions 12/18. Screen titles 28/36 and live metrics 48/56 at 700. Support native text scaling and monospaced/tabular digits; never shrink values to hide missing layout room.
- Primary light action: white on blood red. Primary dark action: charcoal on baby blue. Focus: 2-unit contrasting ring with 3-unit offset. Distinguish focus, pressed, disabled, loading and error with labels/structure; loading retains a stable button label.
- Light navigation: baby-blue background, charcoal inactive items, red selected item plus label. Dark navigation: charcoal background, white labels and blue active state. Centre recording action is prominent but still labelled.
- Red on charcoal is only 2.08:1; do not use it alone for functional text/icons. Flat 2D route: 4-unit red foreground with 8-unit white casing. Cinematic route: white core inside a blood-red band and glow, with a red progress marker bordered in white. Scale/test against the real renderer; endpoints need labelled markers.
- Functional icons use the supplied Lucide 24-unit family at consistent stroke width. They are not brand-logo substitutes. Charcoal/red versions suit light surfaces; white and blue highlight roles suit dark surfaces.
- Prioritise one primary task per screen: record, pause/finish, review an activity, or deliberately open replay. Saved, uploaded, paused and finished are separate states.
- Press feedback starts at 120 ms; small transitions about 200 ms. Respect Reduce Motion. Replay is user-triggered with pause/stop visible. Provide a static/crossfade alternative to camera travel.
- Sample metrics, routes and screen layouts are illustrative. Developers must bind real state, accessibility semantics, screen-reader labels and permission handling in the app.
