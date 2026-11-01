# MURY development team

Persistent session roster — 1 November 2026.

Parent: MURY branding audit (e6c403f1-7f3f-49e2-ab9e-1be29bff3832). Owns requirements, architecture decisions, shared-file assignments, integration, review and approval boundaries. Reuse existing sessions instead of creating duplicates.

1. **Brand foundation** — session ID: 2c283022-76d4-4232-8585-7a3f0274b2ef

2. **Screens and sharing** — session ID: 7a60c141-31ea-41a4-8725-239720eff625

3. **Build verification** — session ID: 8dbeac1c-8a32-4e71-a74f-f7bad940049b

4. **GPS, HealthKit and activity data** — session ID: 81ba9f3b-02b9-4051-90c0-0255000fe2e7

5. **Maps and 3D replay** — session ID: 027c690c-e7a6-4bfd-9ef4-44d98752ae6e

6. **Independent review and privacy** — session ID: 265e9eba-3f7e-4be0-837a-9b278b386195

## Standing workstreams

- Brand foundation: supplied brand pack, logo/font assets, theme tokens, onboarding and appearance compatibility.
- Screens and sharing: dashboard, recording UI, history/details/statistics/profile/settings and existing media composers.
- Build verification: local checks, simulator CI evidence, device checklist and TestFlight preparation.
- GPS, HealthKit and activity data: recording/background tracking, pause/resume, data integrity, imports/backups and health integration.
- Maps and 3D replay: route rendering and existing MapKit replay; proposal assessment for further cinematic features.
- Independent review and privacy: review actual diffs for correctness, accessibility, privacy/security and regressions; no implementation in others' files.

## Coordination rules

Sessions share the workspace. The parent assigns exact files before edits; never two implementers on the same file. Shared theme, app entry, project and configuration changes are serialized. Preparation sessions currently have read-only task scope; implementation requires a concrete parent assignment and suitable tool capabilities. No ongoing monitoring is promised: sessions run assigned tasks, report, and remain available for reuse.

Use feature/mury-branding; protect main, bundle rdyy.larping, original TestFlight release, activity storage, GPS algorithms and HealthKit. No unapproved signing, secrets, workflow, permissions or schema changes. Commits/pushes and each TestFlight upload follow explicit owner authorization; creating the team does not authorize a release.

## Current handoff

Ricardo rejected the reconstructed route-pin logo and fonts and has now supplied MURY-Full-Brand-Pack.zip (Open Air v1.3). The app-relevant source assets are imported at design/branding/brand-pack; see docs/mury-brand-pack-intake.md. The combined blue/red direction remains intended. Do not implement the rejected artwork. The current branding design is a draft, not approved final artwork. Existing TestFlight 1.1(1) uses prior branding. Cinematic 3D export, clubs, follows and social-feed features shown in references remain outside authorized implementation.

Team setup is complete; this is not a claim that the app build or new branding is complete. New child sessions are doing bounded preparation; the original three retain their completed findings.


## Owner logo colour correction — 1 November 2026

Logo symbol and Mury lettering: red, white and light blue only. No navy/charcoal/black in the identity artwork. Navy/charcoal remains allowed in the interface. This overrides the supplied primary preview and conflicting pack guidance. Use existing red, white and blue/white masters without changing geometry; see docs/mury-brand-pack-intake.md.

## App implementation worker

MURY — App implementation (fb467067-7278-403d-9b24-3c00466ef93a) has write/build tools for approved code changes. The original Brand foundation, Screens and sharing and Build verification sessions retain their read-only advisory role. Parent assigns precise files; maps keeps separate view ownership. This worker exists because read-only sessions cannot be silently upgraded through a prompt.
