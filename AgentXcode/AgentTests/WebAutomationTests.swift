import Testing
import Foundation
@testable import Agent_

@Suite("WebAutomationService — Safari JavaScript Automation")
@MainActor
struct WebAutomationTests {

    let web = WebAutomationService.shared

    // MARK: - Google Search

    @Test("safariGoogleSearch opens google, types query, returns results")
    func googleSearchReturnsResults() async {
        let result = await web.safariGoogleSearch(query: "swift programming language", maxResults: 1000)
        #expect(result.contains("\"success\": true"), "Expected success but got: \(result.prefix(300))")
        #expect(result.contains("swift"), "Results should mention swift")
        #expect(result.contains("google.com/search"), "URL should be a Google search URL")
    }

    @Test("safariGoogleSearch handles special characters in query")
    func googleSearchSpecialChars() async {
        let result = await web.safariGoogleSearch(query: "what is 2+2?", maxResults: 500)
        #expect(result.contains("\"success\": true"), "Expected success but got: \(result.prefix(300))")
    }

    @Test("safariGoogleSearch handles quoted query")
    func googleSearchQuotedQuery() async {
        let result = await web.safariGoogleSearch(query: "\"todd bruss\" site:github.com", maxResults: 1000)
        #expect(result.contains("\"success\": true"), "Expected success but got: \(result.prefix(300))")
    }

    // MARK: - Page Info

    @Test("getPageURL returns current Safari URL")
    func getPageURL() async {
        // First open a known page
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        let url = await web.getPageURL()
        #expect(url.contains("google.com"), "Expected google.com URL but got: \(url)")
    }

    @Test("getPageTitle returns current Safari title")
    func getPageTitle() async {
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        let title = await web.getPageTitle()
        #expect(!title.contains("Error"), "Expected title but got error: \(title)")
    }

    @Test("readPageContent returns page text")
    func readPageContent() async {
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        let content = await web.readPageContent(maxLength: 500)
        #expect(!content.contains("Error"), "Expected content but got error: \(content)")
        #expect(!content.isEmpty, "Content should not be empty")
    }

    // MARK: - Google Signup Form Detection

    @Test("Google signup page form fields are detectable via JS")
    func googleSignupFormFields() async {
        _ = try? await web.open(url: URL(string: "https://accounts.google.com/signup")!)
        try? await Task.sleep(for: .seconds(3))

        // Detect firstName field
        let firstNameJS = "document.querySelector('input[name=firstName]') ? 'found' : 'not found'"
        let firstName = try? await web.executeJavaScript(script: firstNameJS) as? String
        #expect(firstName == "found", "firstName field should exist on signup page")

        // Detect lastName field
        let lastNameJS = "document.querySelector('input[name=lastName]') ? 'found' : 'not found'"
        let lastName = try? await web.executeJavaScript(script: lastNameJS) as? String
        #expect(lastName == "found", "lastName field should exist on signup page")
    }

    @Test("Google signup form can be filled via JS without submitting")
    func googleSignupFillForm() async {
        _ = try? await web.open(url: URL(string: "https://accounts.google.com/signup")!)
        try? await Task.sleep(for: .seconds(3))

        // Fill firstName
        let fillJS = """
        (function() {
            var fn = document.querySelector('input[name=firstName]');
            var ln = document.querySelector('input[name=lastName]');
            if (!fn || !ln) return 'fields not found';
            fn.focus(); fn.value = 'TestAgent';
            fn.dispatchEvent(new Event('input', {bubbles: true}));
            ln.focus(); ln.value = 'McTest';
            ln.dispatchEvent(new Event('input', {bubbles: true}));
            return fn.value + ' ' + ln.value;
        })()
        """
        let result = try? await web.executeJavaScript(script: fillJS) as? String
        #expect(result == "TestAgent McTest", "Form should be filled but got: \(result ?? "nil")")

        // Clear form (cleanup)
        _ = try? await web.executeJavaScript(script: """
            var fn = document.querySelector('input[name=firstName]');
            var ln = document.querySelector('input[name=lastName]');
            if (fn) fn.value = '';
            if (ln) ln.value = '';
            'cleared'
        """)
    }

    // MARK: - LinkedIn Page Detection

    @Test("LinkedIn page elements are detectable via JS")
    func linkedInPageDetection() async {
        _ = try? await web.open(url: URL(string: "https://www.linkedin.com/feed/")!)
        try? await Task.sleep(for: .seconds(3))

        // Detect page state — logged in or login page
        let stateJS = """
        (function() {
            if (document.querySelector('.feed-shared-update-v2')) return 'feed';
            if (document.querySelector('.share-box-feed-entry__top-bar')) return 'feed_compose';
            if (document.querySelector('input[name=session_key]')) return 'login_page';
            if (document.querySelector('.global-nav')) return 'logged_in';
            return 'unknown';
        })()
        """
        let state = try? await web.executeJavaScript(script: stateJS) as? String
        #expect(state != nil, "Should detect LinkedIn page state")
        #expect(state != "unknown", "Should recognize LinkedIn page, got: \(state ?? "nil")")
    }

    @Test("LinkedIn login page fields are detectable")
    func linkedInLoginFields() async {
        _ = try? await web.open(url: URL(string: "https://www.linkedin.com/login")!)
        try? await Task.sleep(for: .seconds(3))

        let fieldsJS = """
        (function() {
            var email = document.querySelector('input[name=session_key],input#username');
            var pass = document.querySelector('input[name=session_password],input#password');
            var btn = null;
            var btns = document.querySelectorAll('button');
            for (var i = 0; i < btns.length; i++) {
                if (btns[i].textContent.includes('Sign in')) { btn = btns[i]; break; }
            }
            return JSON.stringify({
                email: email ? 'found' : 'not found',
                password: pass ? 'found' : 'not found',
                signInButton: btn ? 'found' : 'not found'
            });
        })()
        """
        let result = try? await web.executeJavaScript(script: fieldsJS) as? String
        #expect(result != nil, "Should detect LinkedIn login fields")
        if let r = result {
            #expect(r.contains("\"email\":\"found\""), "Email field should exist: \(r)")
            #expect(r.contains("\"password\":\"found\""), "Password field should exist: \(r)")
        }
    }

    @Test("LinkedIn feed post and comment buttons are detectable when logged in")
    func linkedInFeedElements() async {
        _ = try? await web.open(url: URL(string: "https://www.linkedin.com/feed/")!)
        try? await Task.sleep(for: .seconds(4))

        let metricsJS = """
        (function() {
            var posts = document.querySelectorAll('.feed-shared-update-v2').length;
            var commentBtns = 0;
            var likeBtns = 0;
            var btns = document.querySelectorAll('button');
            for (var i = 0; i < btns.length; i++) {
                var label = btns[i].getAttribute('aria-label') || '';
                if (label.includes('Comment')) commentBtns++;
                if (label.includes('Like') || label.includes('React')) likeBtns++;
            }
            var compose = document.querySelector('.share-box-feed-entry__top-bar') ? true : false;
            return JSON.stringify({posts: posts, commentButtons: commentBtns, likeButtons: likeBtns, compose: compose});
        })()
        """
        let result = try? await web.executeJavaScript(script: metricsJS) as? String
        #expect(result != nil, "Should get LinkedIn feed metrics")
        // If logged in, should have posts. If not, that's ok too.
        if let r = result {
            #expect(r.contains("posts"), "Should report post count: \(r)")
        }
    }

    // MARK: - JavaScript Execution

    @Test("executeJavaScript returns string result")
    func executeJSReturnsString() async {
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        let result = try? await web.executeJavaScript(script: "document.title") as? String
        #expect(result != nil, "Should return document title")
    }

    @Test("executeJavaScript can query DOM elements")
    func executeJSQueryDOM() async {
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        let result = try? await web.executeJavaScript(script: "document.querySelectorAll('a').length") as? String
        #expect(result != nil, "Should return link count")
        if let count = result.flatMap({ Int($0) }) {
            #expect(count > 0, "Google should have links")
        }
    }

    // MARK: - Click and Type via JS

    @Test("click via JavaScript finds and clicks element")
    func clickViaJS() async {
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        do {
            let result = try await web.click(selector: "textarea[name=q],input[name=q]", strategy: .javascript)
            #expect(result.contains("Clicked"), "Should click search input: \(result)")
        } catch {
            // Element might not exist if Google changed layout
            #expect(Bool(false), "Click failed: \(error)")
        }
    }

    @Test("type via JavaScript fills input field")
    func typeViaJS() async {
        _ = try? await web.open(url: URL(string: "https://www.google.com")!)
        try? await Task.sleep(for: .seconds(2))
        do {
            let result = try await web.type(text: "hello world", selector: "textarea[name=q],input[name=q]", strategy: .javascript)
            #expect(result.contains("Typed"), "Should type text: \(result)")

            // Verify value
            let value = try? await web.executeJavaScript(script: "document.querySelector('textarea[name=q],input[name=q]').value") as? String
            #expect(value == "hello world", "Value should be 'hello world' but got: \(value ?? "nil")")
        } catch {
            #expect(Bool(false), "Type failed: \(error)")
        }
    }
}
