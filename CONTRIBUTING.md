# Contributing

Thanks for helping improve Codex Vitals.

Before opening a pull request:

- Keep the app local-first. Do not add remote sync, account sharing, or automation hooks.
- Do not log tokens, bearer headers, OAuth responses, or full auth JSON.
- Keep sensitive files owner-only and preserve the documented storage contract.
- For macOS changes, run `swift test`; for UI or packaging changes, also run `./build-app.sh`.
- For Windows changes, set `PYTHONPATH=windows` and run `python -m unittest discover windows\tests`.

Security reports should follow [SECURITY.md](SECURITY.md).
