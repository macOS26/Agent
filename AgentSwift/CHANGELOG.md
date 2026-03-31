# SwiftCodeChecker Changelog

## [1.1.0] - 2025-05-10

### Added
- Report generation capability that outputs detailed Markdown reports
- Standalone swift-code-checker.swift script for easier command-line usage
- Command-line argument support for both the script and demo executable
- AnalysisReporter class for generating detailed issue reports
- Issue categorization by type and severity in reports
- Additional documentation in README

### Changed
- Improved output formatting with better organization by severity
- Updated SwiftCheckerDemo to accept file paths as command-line arguments
- Refactored code to make it more modular and maintainable

### Fixed
- Made error reporting more consistent across different checkers

## [1.0.0] - 2025-05-01

### Added
- Initial release with basic Swift code checking functionality
- Support for detecting syntax errors, unused variables, and other common issues
- Advanced checkers leveraging Swift Syntax packages:
  - OperatorPrecedenceChecker using SwiftOperators
  - CodeStyleChecker using SwiftBasicFormat
  - RefactoringOpportunities using SwiftRefactor
  - SymbolUsageChecker using SwiftIDEUtils
  - MacroUsageChecker using SwiftSyntaxMacros
- Test suite for verifying checker functionality
- Demo executable for showcasing the tool's capabilities 