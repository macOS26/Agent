@preconcurrency import Foundation
import MCPClient
import MultiLineDiff
import os.log
import Cocoa

private let coreHandlerLog = Logger(subsystem: "Agent.app.toddbruss", category: "TabCoreHandlers")

extension AgentViewModel {

    /// Handle Core tool calls for tab tasks.
    func handleTabCoreTool(
        tab: ScriptTab, name: String, input: [String: Any], toolId: String
    ) async -> TabToolResult {

        if name == "task_complete" {
            let summary = input["summary"] as? String ?? "Done"
            tab.appendLog("✅ Completed: \(summary)")
            tab.flush()
            
            // Apple Intelligence mediator summary (same as main task)
            let mediator = AppleIntelligenceMediator.shared
            if mediator.isEnabled && mediator.showAnnotationsToUser {
                coreHandlerLog.info("[\(tab.displayTitle)] Apple AI mediator: summarizing completion...")
                if let summaryAnnotation = await mediator.summarizeCompletion(summary: summary, commandsRun: []) {
                    if mediator.trainingEnabled {
                        TrainingDataStore.shared.captureAppleAIDecision(summaryAnnotation.content)
                    }
                    tab.appendLog(summaryAnnotation.formatted)
                    tab.flush()
                }
            }
            
            // If this is the Messages tab, reply to the iMessage sender
            if tab.isMessagesTab, let handle = tab.replyHandle {
                tab.replyHandle = nil
                sendMessagesTabReply(summary, handle: handle)
            }
            return TabToolResult(toolResult: nil, isComplete: true)
        }

        if name == "plan_mode" {
            let action = input["action"] as? String ?? "read"
            let output = Self.handlePlanMode(action: action, input: input, projectFolder: tab.projectFolder.isEmpty ? projectFolder : tab.projectFolder, tabName: tab.displayTitle)
            tab.appendLog(output)
            tab.flush()
            return TabToolResult(
                toolResult: ["type": "tool_result", "tool_use_id": toolId, "content": output],
                isComplete: false
            )
        }

        // Fallback
        let output = await executeNativeTool(name, input: input)
        tab.appendLog(output); tab.flush()
        return tabResult(output, toolId: toolId)
    }
}
