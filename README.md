# JARVIS-Nova

A native macOS assistant project built with Swift and SwiftUI.

This repository contains the source snapshot prepared for independent code review. See `QUALITY-FIXES-REPORT.md` for the changes and validation performed on 15 November 2026.

## Build and test

```bash
swift build -c release
swift test
```

Runtime behavior involving macOS permissions, audio devices, network services, and hardware still requires manual verification on a Mac.
