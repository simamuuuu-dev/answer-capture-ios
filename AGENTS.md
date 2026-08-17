# Answer Capture iOS repository rules

- Keep Apple account names, signing certificates, provisioning profiles, Development Team IDs, viewer tokens, and real answer images out of the repository.
- Preserve Android-compatible API and JSON keys unless an explicit contract decision documents a migration.
- Never send an unverified Bamboo Slate write command. Deleting a stored Slate page requires a confirmed successful server response.
- Keep stateful I/O in actors and UI mutations on `@MainActor`.
- Separate simulator/automated tests from iPhone 12, LAN, Bamboo Slate, signing, and SideStore device checks.
- Do not add an application dependency without recording the reason and license in `docs/dependency-decision.md`.
