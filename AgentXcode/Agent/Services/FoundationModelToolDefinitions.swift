import FoundationModels
import Foundation

// MARK: - @Generable Argument Structs for Native Tools
// These structs define the arguments for each native tool using Apple's @Generable macro.

@Generable
struct ShellArgs {
    @Guide(description: "Bash command to execute")
    var command: String
}

@Generable
struct AppleScriptArgs {
    @Guide(description: "AppleScript code")
    var source: String
}

@Generable
struct OsaScriptArgs {
    @Guide(description: "AppleScript code")
    var script: String
}

@Generable
struct ReadFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "Start line")
    var offset: Int?
    @Guide(description: "Max lines")
    var limit: Int?
}

@Generable
struct WriteFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "File content")
    var content: String
}

@Generable
struct EditFileArgs {
    @Guide(description: "File path")
    var file_path: String
    @Guide(description: "Text to find")
    var old_string: String
    @Guide(description: "Replacement")
    var new_string: String
    @Guide(description: "Replace all")
    var replace_all: Bool?
}

@Generable
struct GlobArgs {
    @Guide(description: "Glob pattern")
    var pattern: String
    @Guide(description: "Directory")
    var path: String?
}

@Generable
struct SearchArgs {
    @Guide(description: "Regex pattern")
    var pattern: String
    @Guide(description: "Directory")
    var path: String?
    @Guide(description: "File filter")
    var include: String?
}

@Generable
struct TaskCompleteArgs {
    @Guide(description: "Summary")
    var summary: String
}

@Generable
struct GitRepoArgs {
    @Guide(description: "Repo path")
    var path: String?
}

@Generable
struct GitCommitArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Message")
    var message: String
}

@Generable
struct GitLogArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Count")
    var count: Int?
}

@Generable
struct GitDiffArgs {
    @Guide(description: "Repo path")
    var path: String?
    @Guide(description: "Staged only")
    var staged: Bool?
    @Guide(description: "Target branch")
    var target: String?
}

@Generable
struct JXAArgs {
    @Guide(description: "JavaScript for Automation source code")
    var source: String
}