## Summary

## Validation

- [ ] `swift test`
- [ ] `./build-app.sh` for UI, icon, Info.plist, or packaging changes
- [ ] `python -m unittest discover windows\tests` for Windows changes

## Security checklist

- [ ] No tokens, bearer headers, OAuth responses, or full auth JSON are logged
- [ ] Sensitive app-owned files keep owner-only permissions
- [ ] The change stays local-first
