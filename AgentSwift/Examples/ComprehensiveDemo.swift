// ComprehensiveDemo.swift
// A demo file with examples of all the issues our SwiftCodeChecker can detect

import Foundation
import UIKit  // Unused import

// MARK: - Syntax Error Example
class syntaxError {  // Should be UpperCamelCase
    func brokenFunc() {
        let x = 10
        if x > 5 {
            print("Greater than 5")
        // Missing closing brace here
    }
}

// MARK: - Unused Variables
func unusedVariableDemo() {
    let unusedConstant = 42  // Unused variable
    var unusedVariable = "Hello"  // Unused variable
    
    let usedConstant = 100
    print("The value is: \(usedConstant)")
}

// MARK: - Immutable Assignment
func immutableAssignmentDemo() {
    let constantValue = 10
    constantValue = 20  // Error: Cannot assign to value: 'constantValue' is a 'let' constant
    
    var mutableValue = 5
    mutableValue = 15  // This is fine
}

// MARK: - Unreachable Code
func unreachableCodeDemo() {
    print("This will execute")
    return
    print("This will never execute")  // Unreachable code
}

// MARK: - Cyclomatic Complexity
func highComplexityFunction(value: Int) -> String {  // High cyclomatic complexity
    if value < 0 {
        return "Negative"
    } else if value == 0 {
        return "Zero"
    } else if value < 10 {
        return "Small"
    } else if value < 20 {
        return "Medium"
    } else if value < 30 {
        return "Large"
    } else if value < 40 {
        return "Extra Large"
    } else if value < 50 {
        return "Extra Extra Large"
    } else if value < 60 {
        return "Huge"
    } else if value < 70 {
        return "Enormous"
    } else if value < 80 {
        return "Gigantic"
    } else if value < 90 {
        return "Colossal"
    } else {
        return "Titanic"
    }
}

// MARK: - Force Unwrap
func forceUnwrapDemo() {
    let optionalValue: String? = "Value"
    let unwrapped = optionalValue!  // Force unwrap
    
    let dict = ["key": "value"]
    let value = dict["nonexistent"]!  // Dangerous force unwrap
    
    let object: Any = "string"
    let string = object as! String  // Force cast
}

// MARK: - Long Method
func veryLongMethodDemo() {
    // Imagine this method is 100+ lines long
    print("Line 1")
    print("Line 2")
    print("Line 3")
    // ... many more lines ...
    print("Line 49")
    print("Line 50")
    print("Line 51")  // Exceeds recommended length
}

// MARK: - Guard Usage
func missingGuardDemo(optionalValue: String?) {
    if let value = optionalValue {  // Should use guard for early return
        print("Got value: \(value)")
    } else {
        print("No value")
        return
    }
    
    // More code here...
    print("Processing...")
}

// MARK: - Magic Numbers
func magicNumbersDemo() {
    let result = calculateValue() * 1.15  // Magic number 1.15
    
    if result > 27.5 {  // Magic number 27.5
        print("Result exceeded threshold")
    }
    
    // Wait for 300 milliseconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {  // Magic number 0.3
        print("Done waiting")
    }
}

func calculateValue() -> Double {
    return 42.0
}

// MARK: - Naming Conventions
class invalidClassName {  // Should start with uppercase
    let SCREAMING_SNAKE_CASE = "WRONG"  // Should be camelCase
    var _privateName = "value"  // Starts with underscore but not marked private
    
    func InvalidMethodName() {  // Should start with lowercase
        // ...
    }
}

// MARK: - Access Control
public class PublicType {
    var internalProperty = "value"  // Should be marked public
    let anotherProperty = 42  // Should be marked public
    
    func internalMethod() {  // Should be marked public
        // ...
    }
}

// MARK: - Empty Catch Blocks
func emptyCatchDemo() {
    do {
        try riskyOperation()
    } catch {
        // Empty catch block
    }
}

func riskyOperation() throws {
    throw NSError(domain: "Example", code: 1, userInfo: nil)
}

// MARK: - Memory Leaks
class RetainCycleDemo {
    var completionHandler: (() -> Void)?
    
    func setupHandler() {
        completionHandler = {
            self.handleCompletion()  // Strong reference to self - potential retain cycle
        }
    }
    
    func handleCompletion() {
        print("Completed!")
    }
}

// MARK: - Empty Collection Checks
func emptyCollectionDemo() {
    let numbers = [1, 2, 3]
    
    if numbers.count == 0 {  // Should use isEmpty
        print("Array is empty")
    }
    
    if numbers.count > 0 {  // Should use !isEmpty
        print("Array has elements")
    }
}

// MARK: - Deprecated Usage
@available(iOS, deprecated: 13.0)
func deprecatedAPIDemo() {
    let webView = UIWebView()  // UIWebView is deprecated
    
    let path = "/path/to/file"
    let result = path.stringByAppendingPathComponent("file.txt")  // Deprecated
    
    print("Value of pi: \(M_PI)")  // M_PI is deprecated
}

// MARK: - String Literal Hardcoding
func stringLiteralDemo() {
    let title = "Welcome to the application"  // Should be localized
    let message = "Please enter your username and password to continue"  // Should be localized
    
    print(title)
    print(message)
}

// MARK: - Optional Chaining Depth
func optionalChainingDemo() {
    let user: User? = User()
    
    // Excessive optional chaining
    let zipCode = user?.address?.city?.postalCode?.primaryCode?.value
    
    print("Zip code: \(zipCode ?? "Unknown")")
}

class User {
    var address: Address? = Address()
}

class Address {
    var city: City? = City()
}

class City {
    var postalCode: PostalCode? = PostalCode()
}

class PostalCode {
    var primaryCode: Code? = Code()
}

class Code {
    var value: String? = "12345"
}

// MARK: - Code Duplication
func originalFunction() {
    let value = 10
    if value > 5 {
        print("Value is greater than 5")
        print("Performing operation...")
        let result = value * 2
        print("Result: \(result)")
        print("Operation complete")
    }
}

func duplicateFunction() {
    let value = 20
    if value > 5 {
        print("Value is greater than 5")
        print("Performing operation...")
        let result = value * 2
        print("Result: \(result)")
        print("Operation complete")
    }
} 