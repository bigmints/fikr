---
name: validate-code
description: Run Flutter lint + type check. Must pass before any git commit.
---

# Validate Code

```bash
flutter analyze          # must report 0 issues
flutter pub get          # must complete without error
```

**A commit is blocked until both pass.**

Used by: `pre-commit.sh` git hook, `workflows/commit.md`
