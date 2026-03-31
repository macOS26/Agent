# Agent 1.0.13 Release

## What's New
- Latest version of Agent!

## Installation
Download the DMG file, open it, and drag Agent! to your Applications folder.

## Changes

### Performance Improvements
- **O(1) Tab Lookups**: Replaced 55 linear scans with dictionary lookups for instant tab access
- **AgentMCP 1.3.0**: Updated with O(1) lookups for faster MCP operations

### Scroll & UI Fixes
- **Fixed streaming scroll**: Properly sets userIsAtBottom=true after snapToEnd
- **Smooth scroll animation**: Restored for streaming content
- **Tab scroll persistence**: Scroll position saved continuously, restored on recreation
- **First visit scroll**: Automatically scrolls to bottom on first tab visit
- **Single ActivityLogView**: No more if/else view destruction causing render issues

### Architecture & Dependencies
- **AgentAudit**: New unified os.log audit framework, replaced all other loggers
- **Remote packages**: All packages switched from local to remote GitHub dependencies
- **Package renames**: xcf-swift→AgentSwift, MultiLineDiff→AgentD1F, MCPClient→AgentMCP
- **Project cleanup**: Fixed pbxproj corruption, removed orphan package refs, zero warnings

### Security & Quality
- **Block wildcard-only list_files**: Prevents wasteful operations, suggests file extension
- **Intercept wasteful shell commands**: Suggests built-in tools instead

## Bug Fixes
- Fixed scroll animation on main tab
- Fixed missed renders during tab switching
- Fixed pbxproj corruption issues
- Removed dead logging code