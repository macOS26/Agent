// This is a test Swift file with various issues

func testFunction() {
    // Unused variable (warning)
    let unusedVar = 10
    
    // Mutable variable
    var x = 5
    
    // Immutable variable assignment (error)
    let y = 20
    y = 30
    
    // Missing closing brace in if statement
    if x > 3 {
        print("x is greater than 3")
    
    // Unreachable code (after return)
    return
    print("This code will never be executed")
    
    // Regular code
    x += 1
    print("Final value of x: \(x)")
}

// Testing force unwraps
func testForceUnwraps() {
    let optionalValue: String? = "test"
    let forcedValue = optionalValue!  // Force unwrap
    
    let dict: [String: Any] = ["key": "value"]
    let forcedCast = dict["missing"] as! String  // Forced cast
}

// Testing empty catch blocks
func testEmptyCatch() {
    do {
        try FileManager.default.removeItem(atPath: "/nonexistent/path")
    } catch {
        // Empty catch block
    }
}

// Testing retain cycles (memory leaks)
class RetainCycleExample {
    var handler: (() -> Void)?
    
    func setupHandler() {
        handler = {
            self.doSomething()  // Captures self strongly
        }
    }
    
    func doSomething() {
        print("Doing something")
    }
}

// Testing improper empty collection checks
func testEmptyCollectionCheck() {
    let array = [Int]()
    if array.count == 0 {  // Should use isEmpty
        print("Array is empty")
    }
}

// Testing excessive optional chaining
class DeepChain {
    var level1: Level1?
    
    class Level1 {
        var level2: Level2?
    }
    
    class Level2 {
        var level3: Level3?
    }
    
    class Level3 {
        var value: String?
    }
}

func testExcessiveChaining() {
    let deep = DeepChain()
    let value = deep.level1?.level2?.level3?.value  // Deep optional chaining
}

// Testing high cyclomatic complexity
func complexFunction(a: Int, b: Int, c: Int) -> Bool {
    if a > 0 {
        if b > 0 {
            if c > 0 {
                return true
            } else if c < -10 {
                return true
            } else {
                return false
            }
        } else if b < -10 {
            if c == 0 {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    } else if a < -10 {
        if b == 0 {
            return true
        } else {
            return false
        }
    }
    return false
} 