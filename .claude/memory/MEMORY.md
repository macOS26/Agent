# Agent Project Memory

## Project Status
- Fully functional macOS app with privileged daemon
- Located at ~/Documents/Github/Agent/
- Originally developed at ~/Agent/ then moved via rsync

## Architecture Decisions
- See [architecture.md](architecture.md) for detailed architecture notes
- See [development-history.md](development-history.md) for full development timeline

## Key Conventions
- Build with XCF (ensure correct project is selected)
- Development Team: 469UCUB275
- macOS 26.0 deployment target, Swift 6.0
- @Observable pattern with stored properties + didSet (not computed)
- UserDefaults for API key and model persistence

## Resolved Issues
- SMAppService: always call register() directly, don't check status first
- Image paste: use NSEvent.addLocalMonitorForEvents + dedicated button
- Daemon home dir: ~ = /var/root, must inject real user home path
- SourceKit false positives: ignore "Cannot find type" errors, trust Xcode build
