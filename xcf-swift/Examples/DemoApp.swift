// Demo Swift file with various issues to test our SwiftCodeChecker

import Foundation

// Unused import (no warning for this in our checker)
import Combine

// Function with unused parameter (should be marked with _)
func processData(data: String, count: Int) {
    // Unused variable
    let unusedValue = 100
    
    // Correct variable usage
    let length = data.count
    print("Data length: \(length)")
    
    // Attempted assignment to let constant
    let maxValue = 50
    maxValue = 60  // Error
    
    // Unreachable code after return
    return
    print("This will never be executed")
    
    // Control flow issue - if statement without braces (not detected by our current checker)
    if count > 10
        print("Count is greater than 10")
}

// Class with missing closing brace
class DataProcessor {
    func process() {
        let data = "test data"
        processData(data: data, count: 5)
    
    // Missing closing brace for class
} 