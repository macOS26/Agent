// Test file to verify algorithm implementations
// This file can be loaded in the browser console for testing

function testAlgorithms() {
    console.log('🧪 Testing MultiLineDiff Algorithms...\n');
    
    // Test data
    const testCases = [
        {
            name: 'Simple text change',
            source: 'Hello, world!',
            destination: 'Hello, Swift!'
        },
        {
            name: 'Function signature change',
            source: `func greet(name: String) -> String {
    return "Hello, \\(name)!"
}`,
            destination: `func greet(name: String, greeting: String = "Hello") -> String {
    return "\\(greeting), \\(name)!"
}`
        },
        {
            name: 'Class modification',
            source: `class Calculator {
    private var result: Double = 0
    
    func add(_ value: Double) {
        result += value
    }
}`,
            destination: `class Calculator {
    private var result: Double = 0
    private var history: [Double] = []
    
    func add(_ value: Double) -> Double {
        result += value
        history.append(value)
        return result
    }
}`
        }
    ];
    
    const algorithms = ['flash', 'zoom', 'optimus', 'starscream', 'megatron'];
    
    testCases.forEach((testCase, index) => {
        console.log(`\n📝 Test Case ${index + 1}: ${testCase.name}`);
        console.log('─'.repeat(50));
        
        algorithms.forEach(algorithm => {
            try {
                const startTime = performance.now();
                
                // Create diff
                const diffResult = MultiLineDiff.createDiff(testCase.source, testCase.destination, algorithm);
                
                // Apply diff
                const result = MultiLineDiff.applyDiff(testCase.source, diffResult);
                
                const endTime = performance.now();
                const totalTime = (endTime - startTime).toFixed(3);
                
                // Verify result
                const isCorrect = result === testCase.destination;
                const status = isCorrect ? '✅' : '❌';
                
                console.log(`${status} ${algorithm.toUpperCase()}: ${totalTime}ms, ${diffResult.operations.length} ops, ${isCorrect ? 'PASS' : 'FAIL'}`);
                
                if (!isCorrect) {
                    console.log(`   Expected: "${testCase.destination}"`);
                    console.log(`   Got:      "${result}"`);
                }
                
                // Show ASCII diff for first test case
                if (index === 0 && algorithm === 'flash') {
                    console.log('\n📊 ASCII Diff (Flash):');
                    const asciiDiff = MultiLineDiff.generateASCIIDiff(diffResult, testCase.source);
                    console.log(asciiDiff);
                }
                
            } catch (error) {
                console.log(`❌ ${algorithm.toUpperCase()}: ERROR - ${error.message}`);
            }
        });
    });
    
    console.log('\n🎯 Algorithm Comparison Summary:');
    console.log('─'.repeat(50));
    
    // Performance comparison
    const perfTest = testCases[1]; // Use function signature test
    const results = {};
    
    algorithms.forEach(algorithm => {
        try {
            const iterations = 100;
            const times = [];
            
            for (let i = 0; i < iterations; i++) {
                const start = performance.now();
                const diffResult = MultiLineDiff.createDiff(perfTest.source, perfTest.destination, algorithm);
                const result = MultiLineDiff.applyDiff(perfTest.source, diffResult);
                const end = performance.now();
                times.push(end - start);
            }
            
            const avgTime = times.reduce((a, b) => a + b, 0) / times.length;
            const diffResult = MultiLineDiff.createDiff(perfTest.source, perfTest.destination, algorithm);
            
            results[algorithm] = {
                avgTime: avgTime.toFixed(3),
                operations: diffResult.operations.length,
                correct: MultiLineDiff.applyDiff(perfTest.source, diffResult) === perfTest.destination
            };
            
        } catch (error) {
            results[algorithm] = { error: error.message };
        }
    });
    
    // Display results
    Object.entries(results).forEach(([algorithm, data]) => {
        if (data.error) {
            console.log(`❌ ${algorithm.toUpperCase()}: ERROR - ${data.error}`);
        } else {
            const emoji = algorithm === 'flash' ? '🥇' : algorithm === 'zoom' ? '🥈' : '📊';
            console.log(`${emoji} ${algorithm.toUpperCase()}: ${data.avgTime}ms avg, ${data.operations} ops, ${data.correct ? 'PASS' : 'FAIL'}`);
        }
    });
    
    console.log('\n✨ Testing complete!');
    return results;
}

// Auto-run test if MultiLineDiff is available
if (typeof MultiLineDiff !== 'undefined') {
    // Wait a bit for everything to load
    setTimeout(() => {
        console.log('🚀 MultiLineDiff algorithms loaded successfully!');
        console.log('💡 Run testAlgorithms() to test all implementations');
    }, 1000);
} else {
    console.log('⚠️ MultiLineDiff not found. Make sure algorithms.js is loaded first.');
}

// Export for manual testing
window.testAlgorithms = testAlgorithms; 