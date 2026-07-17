# Security

## Threat Model

Codex Vitals is a local-only macOS menu bar and Windows system tray utility. Its main sensitive asset is the user's Codex/OpenAI auth data stored on disk.

Codex Vitals assumes:

- The signed-in macOS or Windows user account is trusted.
- Other local users and processes should not be able to read Codex Vitals token files.
- Network responses from unofficial ChatGPT/Codex endpoints may fail or change shape.
- Users only add and switch accounts/workspaces they own or are authorized to use.

## Local Storage

On macOS, Codex Vitals stores token-containing files under `~/Library/Application Support/CodexVitals/` with owner-only permissions. On Windows, app data is stored under `%APPDATA%\CodexVitals` inside the current user's profile. The app writes the active `.codex/auth.json` only after an explicit manual switch action.

Codex Vitals does not intentionally log access tokens, refresh tokens, ID tokens, bearer headers, OAuth response bodies, or full auth JSON.

## Network

Codex Vitals calls best-effort ChatGPT/Codex web endpoints directly from the local app. It does not sync tokens, share data with a remote service, or run external automation hooks.

The temporary OAuth callback listener binds to localhost during login capture and closes after success, cancellation, timeout, or app termination.

## Reporting

For now, report security issues privately to the repository owner. Do not include live tokens or full auth files in bug reports.
