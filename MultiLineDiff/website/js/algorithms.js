// MultiLineDiff Algorithms - JavaScript Implementation
// Based on the Swift MultiLineDiff library by Todd Bruss

class DiffOperation {
    constructor(type, value) {
        this.type = type; // 'retain', 'insert', 'delete'
        this.value = value; // number for retain/delete, string for insert
    }
    
    static retain(count) {
        return new DiffOperation('retain', count);
    }
    
    static insert(text) {
        return new DiffOperation('insert', text);
    }
    
    static delete(count) {
        return new DiffOperation('delete', count);
    }
}

class DiffResult {
    constructor(operations, metadata = null) {
        this.operations = operations;
        this.metadata = metadata;
    }
}

class MultiLineDiff {
    // Flash Algorithm - Fastest (prefix/suffix detection with line awareness)
    static createFlashDiff(source, destination) {
        if (source === destination) {
            return new DiffResult(source.length > 0 ? [DiffOperation.retain(source.length)] : []);
        }
        
        if (source.length === 0) {
            return new DiffResult(destination.length > 0 ? [DiffOperation.insert(destination)] : []);
        }
        
        if (destination.length === 0) {
            return new DiffResult([DiffOperation.delete(source.length)]);
        }
        
        // Use line-aware approach for Flash to ensure proper emoji placement
        const sourceLines = this.efficientLines(source);
        const destLines = this.efficientLines(destination);
        
        // Find common prefix lines
        let prefixLines = 0;
        while (prefixLines < Math.min(sourceLines.length, destLines.length) && 
               sourceLines[prefixLines] === destLines[prefixLines]) {
            prefixLines++;
        }
        
        // Find common suffix lines (avoiding overlap)
        let suffixLines = 0;
        const remainingSourceLines = sourceLines.length - prefixLines;
        const remainingDestLines = destLines.length - prefixLines;
        const maxSuffixLines = Math.min(remainingSourceLines, remainingDestLines);
        
        while (suffixLines < maxSuffixLines && 
               sourceLines[sourceLines.length - 1 - suffixLines] === destLines[destLines.length - 1 - suffixLines]) {
            suffixLines++;
        }
        
        // Build operations based on line boundaries
        const operations = [];
        
        // Add prefix lines
        if (prefixLines > 0) {
            const prefixLength = sourceLines.slice(0, prefixLines).join('').length;
            operations.push(DiffOperation.retain(prefixLength));
        }
        
        // Add middle section (deleted lines)
        const middleSourceStart = prefixLines;
        const middleSourceEnd = sourceLines.length - suffixLines;
        if (middleSourceEnd > middleSourceStart) {
            const middleSourceLength = sourceLines.slice(middleSourceStart, middleSourceEnd).join('').length;
            operations.push(DiffOperation.delete(middleSourceLength));
        }
        
        // Add middle section (inserted lines)
        const middleDestStart = prefixLines;
        const middleDestEnd = destLines.length - suffixLines;
        if (middleDestEnd > middleDestStart) {
            const middleDestText = destLines.slice(middleDestStart, middleDestEnd).join('');
            operations.push(DiffOperation.insert(middleDestText));
        }
        
        // Add suffix lines
        if (suffixLines > 0) {
            const suffixLength = sourceLines.slice(-suffixLines).join('').length;
            operations.push(DiffOperation.retain(suffixLength));
        }
        
        return new DiffResult(operations);
    }
    
    // Zoom Algorithm - Simple line-based (line-aware for proper emoji placement)
    static createZoomDiff(source, destination) {
        if (source === destination) {
            return new DiffResult(source.length > 0 ? [DiffOperation.retain(source.length)] : []);
        }
        
        if (source.length === 0) {
            return new DiffResult(destination.length > 0 ? [DiffOperation.insert(destination)] : []);
        }
        
        if (destination.length === 0) {
            return new DiffResult([DiffOperation.delete(source.length)]);
        }
        
        // Use line-aware approach for Zoom to ensure proper emoji placement
        const sourceLines = this.efficientLines(source);
        const destLines = this.efficientLines(destination);
        
        // Simple line-based comparison (similar to Flash but simpler)
        let prefixLines = 0;
        while (prefixLines < Math.min(sourceLines.length, destLines.length) && 
               sourceLines[prefixLines] === destLines[prefixLines]) {
            prefixLines++;
        }
        
        let suffixLines = 0;
        const remainingSourceLines = sourceLines.length - prefixLines;
        const remainingDestLines = destLines.length - prefixLines;
        const maxSuffixLines = Math.min(remainingSourceLines, remainingDestLines);
        
        while (suffixLines < maxSuffixLines && 
               sourceLines[sourceLines.length - 1 - suffixLines] === destLines[destLines.length - 1 - suffixLines]) {
            suffixLines++;
        }
        
        // Build operations based on line boundaries
        const operations = [];
        
        // Add prefix lines
        if (prefixLines > 0) {
            const prefixLength = sourceLines.slice(0, prefixLines).join('').length;
            operations.push(DiffOperation.retain(prefixLength));
        }
        
        // Add middle section (deleted lines)
        const middleSourceStart = prefixLines;
        const middleSourceEnd = sourceLines.length - suffixLines;
        if (middleSourceEnd > middleSourceStart) {
            const middleSourceLength = sourceLines.slice(middleSourceStart, middleSourceEnd).join('').length;
            operations.push(DiffOperation.delete(middleSourceLength));
        }
        
        // Add middle section (inserted lines)
        const middleDestStart = prefixLines;
        const middleDestEnd = destLines.length - suffixLines;
        if (middleDestEnd > middleDestStart) {
            const middleDestText = destLines.slice(middleDestStart, middleDestEnd).join('');
            operations.push(DiffOperation.insert(middleDestText));
        }
        
        // Add suffix lines
        if (suffixLines > 0) {
            const suffixLength = sourceLines.slice(-suffixLines).join('').length;
            operations.push(DiffOperation.retain(suffixLength));
        }
        
        return new DiffResult(operations);
    }
    
    // Optimus Algorithm - Line-aware with CollectionDifference simulation
    static createOptimusDiff(source, destination) {
        if (source === destination) {
            return new DiffResult(source.length > 0 ? [DiffOperation.retain(source.length)] : []);
        }
        
        if (source.length === 0) {
            return new DiffResult(destination.length > 0 ? [DiffOperation.insert(destination)] : []);
        }
        
        if (destination.length === 0) {
            return new DiffResult([DiffOperation.delete(source.length)]);
        }
        
        // Split into lines preserving line endings
        const sourceLines = this.efficientLines(source);
        const destLines = this.efficientLines(destination);
        
        // Use line-based difference algorithm
        const lineOperations = this.computeLineDifference(sourceLines, destLines);
        
        // Convert to character-based operations
        return this.convertLineDifferenceToOperations(lineOperations, sourceLines, destLines);
    }
    
    // Starscream Algorithm - Swift native line processing (same as Optimus)
    static createStarscreamDiff(source, destination) {
        if (source === destination) {
            return new DiffResult(source.length > 0 ? [DiffOperation.retain(source.length)] : []);
        }
        
        if (source.length === 0) {
            return new DiffResult(destination.length > 0 ? [DiffOperation.insert(destination)] : []);
        }
        
        if (destination.length === 0) {
            return new DiffResult([DiffOperation.delete(source.length)]);
        }
        
        // Use same line-based approach as Optimus for consistent operation counts
        const sourceLines = this.efficientLines(source);
        const destLines = this.efficientLines(destination);
        
        // Use line-based difference algorithm (same as Optimus)
        const lineOperations = this.computeLineDifference(sourceLines, destLines);
        
        // Convert to character-based operations
        return this.convertLineDifferenceToOperations(lineOperations, sourceLines, destLines);
    }
    
    // Megatron Algorithm - Semantic analysis
    static createMegatronDiff(source, destination) {
        if (source === destination) {
            return new DiffResult(source.length > 0 ? [DiffOperation.retain(source.length)] : []);
        }
        
        if (source.length === 0) {
            return new DiffResult(destination.length > 0 ? [DiffOperation.insert(destination)] : []);
        }
        
        if (destination.length === 0) {
            return new DiffResult([DiffOperation.delete(source.length)]);
        }
        
        // Enhanced semantic analysis using line processing
        const sourceLines = this.efficientLines(source);
        const destLines = this.efficientLines(destination);
        
        // Use LCS-based algorithm for semantic understanding
        const lcsOperations = this.computeLCS(sourceLines, destLines);
        
        return this.createDiffFromLineOperations(lcsOperations, sourceLines, destLines);
    }
    
    // Main entry point
    static createDiff(source, destination, algorithm = 'megatron') {
        const startTime = performance.now();
        
        let result;
        switch (algorithm) {
            case 'flash':
                result = this.createFlashDiff(source, destination);
                break;
            case 'zoom':
                result = this.createZoomDiff(source, destination);
                break;
            case 'optimus':
                result = this.createOptimusDiff(source, destination);
                break;
            case 'starscream':
                result = this.createStarscreamDiff(source, destination);
                break;
            case 'megatron':
            default:
                result = this.createMegatronDiff(source, destination);
                break;
        }
        
        const endTime = performance.now();
        const processingTime = endTime - startTime;
        
        // Add metadata
        result.metadata = {
            algorithm: algorithm,
            processingTime: processingTime,
            sourceLength: source.length,
            destinationLength: destination.length,
            operationCount: result.operations.length
        };
        
        return result;
    }
    
    // Apply diff to source string
    static applyDiff(source, diffResult) {
        let result = '';
        let currentIndex = 0;
        
        for (const operation of diffResult.operations) {
            switch (operation.type) {
                case 'retain':
                    const retainLength = Math.min(operation.value, source.length - currentIndex);
                    result += source.slice(currentIndex, currentIndex + retainLength);
                    currentIndex += retainLength;
                    break;
                    
                case 'insert':
                    result += operation.value;
                    break;
                    
                case 'delete':
                    const deleteLength = Math.min(operation.value, source.length - currentIndex);
                    currentIndex += deleteLength;
                    break;
            }
        }
        
        return result;
    }
    
    // Generate ASCII diff format
    static generateASCIIDiff(diffResult, source) {
        const parts = [];
        let sourceIndex = 0;
        
        for (const operation of diffResult.operations) {
            switch (operation.type) {
                case 'retain':
                    const retainText = source.slice(sourceIndex, sourceIndex + operation.value);
                    if (retainText) {
                        parts.push(this.prefixLines(retainText, '📎'));
                    }
                    sourceIndex += operation.value;
                    break;
                    
                case 'delete':
                    const deleteText = source.slice(sourceIndex, sourceIndex + operation.value);
                    if (deleteText) {
                        parts.push(this.prefixLines(deleteText, '❌'));
                    }
                    sourceIndex += operation.value;
                    break;
                    
                case 'insert':
                    if (operation.value) {
                        parts.push(this.prefixLines(operation.value, '✅'));
                    }
                    break;
            }
        }
        
        // Join parts and ensure proper line separation
        let result = parts.join('');
        
        // Fix any cases where emoji symbols appear in the middle of lines
        // This can happen when operations don't align with line boundaries
        result = this.cleanupEmojiPlacement(result);
        
        return result;
    }
    
    static cleanupEmojiPlacement(text) {
        if (!text) return text;
        
        // Split into lines and fix any emoji symbols that appear in the middle
        const lines = text.split('\n');
        const fixedLines = [];
        
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            
            // Check if line has emoji symbols in the middle (not at the start)
            const emojiRegex = /(📎|❌|✅)/g;
            const matches = [...line.matchAll(emojiRegex)];
            
            if (matches.length > 1) {
                // Multiple emoji symbols on the same line - need to split into separate lines
                let currentPos = 0;
                
                for (let j = 0; j < matches.length; j++) {
                    const match = matches[j];
                    const emojiPos = match.index;
                    const emoji = match[0];
                    
                    if (j === 0 && emojiPos === 0) {
                        // First emoji at start of line - this is correct
                        continue;
                    }
                    
                    // Split the line at this emoji position
                    const beforeEmoji = line.slice(currentPos, emojiPos);
                    const afterEmoji = line.slice(emojiPos + 2); // +2 to skip emoji and space
                    
                    if (beforeEmoji.trim()) {
                        // Add the content before the emoji as a separate line
                        fixedLines.push(beforeEmoji);
                    }
                    
                    // Start a new line with the emoji
                    line = `${emoji} ${afterEmoji}`;
                    currentPos = 0;
                }
                
                fixedLines.push(line);
            } else {
                // Single or no emoji - line is fine as is
                fixedLines.push(line);
            }
        }
        
        return fixedLines.join('\n');
    }
    
    // Helper methods
    static commonPrefix(str1, str2) {
        let i = 0;
        const minLength = Math.min(str1.length, str2.length);
        while (i < minLength && str1[i] === str2[i]) {
            i++;
        }
        return i;
    }
    
    static commonSuffix(str1, str2) {
        let i = 0;
        const minLength = Math.min(str1.length, str2.length);
        while (i < minLength && str1[str1.length - 1 - i] === str2[str2.length - 1 - i]) {
            i++;
        }
        return i;
    }
    
    static enhancedCommonRegions(source, destination) {
        const prefixLength = this.commonPrefix(source, destination);
        
        const remainingSourceLength = source.length - prefixLength;
        const remainingDestLength = destination.length - prefixLength;
        const maxSuffixLength = Math.min(remainingSourceLength, remainingDestLength);
        
        let suffixLength = 0;
        if (maxSuffixLength > 0) {
            const sourceSuffix = source.slice(source.length - maxSuffixLength);
            const destSuffix = destination.slice(destination.length - maxSuffixLength);
            suffixLength = this.commonSuffix(sourceSuffix, destSuffix);
        }
        
        return {
            prefixLength: prefixLength,
            suffixLength: suffixLength,
            sourceMiddleLength: source.length - prefixLength - suffixLength,
            destMiddleLength: destination.length - prefixLength - suffixLength
        };
    }
    
    static efficientLines(text) {
        if (!text) return [];
        
        const lines = [];
        let currentIndex = 0;
        
        while (currentIndex < text.length) {
            const newlineIndex = text.indexOf('\n', currentIndex);
            if (newlineIndex !== -1) {
                // Include the newline character in the line
                lines.push(text.slice(currentIndex, newlineIndex + 1));
                currentIndex = newlineIndex + 1;
            } else {
                // Last line without newline
                lines.push(text.slice(currentIndex));
                break;
            }
        }
        
        return lines;
    }
    
    static computeLineDifference(sourceLines, destLines) {
        // Simple line difference algorithm
        const operations = [];
        let sourceIndex = 0;
        let destIndex = 0;
        
        while (sourceIndex < sourceLines.length || destIndex < destLines.length) {
            if (sourceIndex < sourceLines.length && destIndex < destLines.length && 
                sourceLines[sourceIndex] === destLines[destIndex]) {
                operations.push({ type: 'retain', sourceIndex: sourceIndex });
                sourceIndex++;
                destIndex++;
            } else if (sourceIndex < sourceLines.length && 
                      (destIndex >= destLines.length || !this.findLineInRange(sourceLines[sourceIndex], destLines, destIndex))) {
                operations.push({ type: 'delete', sourceIndex: sourceIndex });
                sourceIndex++;
            } else if (destIndex < destLines.length) {
                operations.push({ type: 'insert', destIndex: destIndex });
                destIndex++;
            }
        }
        
        return operations;
    }
    

    
    static findLineInRange(line, lines, startIndex) {
        for (let i = startIndex; i < Math.min(lines.length, startIndex + 5); i++) {
            if (lines[i] === line) return true;
        }
        return false;
    }
    
    static convertLineDifferenceToOperations(lineOperations, sourceLines, destLines) {
        const operations = [];
        
        for (const lineOp of lineOperations) {
            switch (lineOp.type) {
                case 'retain':
                    if (lineOp.sourceIndex < sourceLines.length) {
                        operations.push(DiffOperation.retain(sourceLines[lineOp.sourceIndex].length));
                    }
                    break;
                    
                case 'delete':
                    if (lineOp.sourceIndex < sourceLines.length) {
                        operations.push(DiffOperation.delete(sourceLines[lineOp.sourceIndex].length));
                    }
                    break;
                    
                case 'insert':
                    if (lineOp.destIndex < destLines.length) {
                        operations.push(DiffOperation.insert(destLines[lineOp.destIndex]));
                    }
                    break;
            }
        }
        
        return new DiffResult(this.consolidateOperations(operations));
    }
    

    
    static computeLCS(sourceLines, destLines) {
        // Simplified LCS algorithm for line-based comparison
        const operations = [];
        const dp = Array(sourceLines.length + 1).fill(null).map(() => Array(destLines.length + 1).fill(0));
        
        // Build LCS table
        for (let i = 1; i <= sourceLines.length; i++) {
            for (let j = 1; j <= destLines.length; j++) {
                if (sourceLines[i - 1] === destLines[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                } else {
                    dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
                }
            }
        }
        
        // Backtrack to find operations
        let i = sourceLines.length;
        let j = destLines.length;
        
        while (i > 0 || j > 0) {
            if (i > 0 && j > 0 && sourceLines[i - 1] === destLines[j - 1]) {
                operations.unshift({ type: 'retain', sourceIndex: i - 1 });
                i--;
                j--;
            } else if (i > 0 && (j === 0 || dp[i - 1][j] >= dp[i][j - 1])) {
                operations.unshift({ type: 'delete', sourceIndex: i - 1 });
                i--;
            } else {
                operations.unshift({ type: 'insert', destIndex: j - 1 });
                j--;
            }
        }
        
        return operations;
    }
    
    static createDiffFromLineOperations(lcsOperations, sourceLines, destLines) {
        const operations = [];
        
        for (const lineOp of lcsOperations) {
            switch (lineOp.type) {
                case 'retain':
                    if (lineOp.sourceIndex < sourceLines.length) {
                        operations.push(DiffOperation.retain(sourceLines[lineOp.sourceIndex].length));
                    }
                    break;
                    
                case 'delete':
                    if (lineOp.sourceIndex < sourceLines.length) {
                        operations.push(DiffOperation.delete(sourceLines[lineOp.sourceIndex].length));
                    }
                    break;
                    
                case 'insert':
                    if (lineOp.destIndex < destLines.length) {
                        operations.push(DiffOperation.insert(destLines[lineOp.destIndex]));
                    }
                    break;
            }
        }
        
        return new DiffResult(this.consolidateOperations(operations));
    }
    
    static consolidateOperations(operations) {
        if (operations.length === 0) return operations;
        
        const consolidated = [];
        let current = operations[0];
        
        for (let i = 1; i < operations.length; i++) {
            const next = operations[i];
            
            if (current.type === next.type) {
                if (current.type === 'retain' || current.type === 'delete') {
                    current = new DiffOperation(current.type, current.value + next.value);
                } else if (current.type === 'insert') {
                    current = new DiffOperation(current.type, current.value + next.value);
                }
            } else {
                consolidated.push(current);
                current = next;
            }
        }
        
        consolidated.push(current);
        return consolidated;
    }
    
    static prefixLines(text, prefix) {
        if (!text) return '';
        
        // Split text into lines while preserving line endings
        const lines = [];
        let currentIndex = 0;
        
        while (currentIndex < text.length) {
            const newlineIndex = text.indexOf('\n', currentIndex);
            if (newlineIndex !== -1) {
                // Include the newline character in the line
                const line = text.slice(currentIndex, newlineIndex + 1);
                lines.push(line);
                currentIndex = newlineIndex + 1;
            } else {
                // Last line without newline
                const line = text.slice(currentIndex);
                if (line.length > 0) {
                    lines.push(line);
                }
                break;
            }
        }
        
        // Add prefix to each line, ensuring emoji only goes at the start
        return lines.map(line => {
            if (line.endsWith('\n')) {
                // Line with newline: prefix + content + newline
                const content = line.slice(0, -1);
                return `${prefix} ${content}\n`;
            } else {
                // Last line without newline: prefix + content
                return `${prefix} ${line}`;
            }
        }).join('');
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { MultiLineDiff, DiffOperation, DiffResult };
} else if (typeof window !== 'undefined') {
    window.MultiLineDiff = MultiLineDiff;
    window.DiffOperation = DiffOperation;
    window.DiffResult = DiffResult;
} 