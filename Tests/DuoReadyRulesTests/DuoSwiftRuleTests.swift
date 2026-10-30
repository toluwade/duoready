import DuoReadyCore
import DuoReadyRules
import Testing

private func check(_ rule: some SwiftRule, _ source: String) -> [Finding] {
    rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
}

@Suite("DR007 Custom bars the system can't present vertically")
struct CustomBarRuleTests {
    let rule = CustomBarRule()

    @Test("Flags hand-made toolbars, navigation bars and tab bars")
    func problematic() {
        let findings = check(rule, """
            let toolbar = UIToolbar()
            let navigationBar = UINavigationBar(frame: .zero)
            view.addSubview(UITabBar.init())
            """)
        #expect(findings.map(\.line) == [1, 2, 3])
        #expect(findings.first?.message.contains("UIToolbar") == true)
    }

    @Test("Does not flag bars managed by containers")
    func corrected() {
        let findings = check(rule, """
            toolbarItems = [shareItem, deleteItem]
            navigationController?.setToolbarHidden(false, animated: false)
            let nav = UINavigationController(navigationBarClass: BrandedBar.self, toolbarClass: nil)
            final class BrandedBar: UINavigationBar {}
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag keyboard accessory toolbars")
    func keyboardAccessory() {
        let findings = check(rule, """
            let toolbar = UIToolbar()
            toolbar.items = [doneItem]
            textField.inputAccessoryView = toolbar
            """)
        #expect(findings.isEmpty)
    }

    @Test("Still flags navigation bars in a file with a keyboard toolbar, and skips macOS code")
    func edgeCases() {
        let findings = check(rule, """
            textField.inputAccessoryView = UIToolbar()
            let bar = UINavigationBar()
            #if os(macOS)
            let other = UINavigationBar()
            #endif
            """)
        #expect(findings.map(\.line) == [2])
    }
}

@Suite("DR008 Bar items with a title but no icon")
struct TitleOnlyBarItemRuleTests {
    let rule = TitleOnlyBarItemRule()

    @Test("Flags text-only toolbar buttons and bar button items")
    func problematic() {
        let findings = check(rule, """
            var body: some View {
                List {}
                    .toolbar {
                        Button("Edit") { edit() }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { share() } label: { Text("Share") }
                        }
                    }
            }
            let sort = UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(sort))
            """)
        #expect(findings.map(\.line) == [4, 6, 10])
    }

    @Test("Does not flag items with an icon")
    func corrected() {
        let findings = check(rule, """
            List {}
                .toolbar {
                    Button("Edit", systemImage: "pencil") { edit() }
                    Button { share() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                }
            let sort = UIBarButtonItem(title: "Sort", image: UIImage(systemName: "arrow.up.arrow.down"), primaryAction: nil, menu: nil)
            let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag menus, exempt placements, buttons outside toolbars or back-button text")
    func exceptions() {
        let findings = check(rule, """
            VStack { Button("Continue") { next() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .keyboard) { Button("Done") { hideKeyboard() } }
                    Menu("More") { Button("Archive") { archive() } }
                }
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "Log in", style: .plain, target: nil, action: nil)
            let blank = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
            """)
        #expect(findings.isEmpty)
    }

    @Test("Skips UIKit items in files with a keyboard toolbar, and handles localized titles")
    func edgeCases() {
        let keyboard = check(rule, """
            let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
            field.inputAccessoryView = toolbar
            """)
        #expect(keyboard.isEmpty)

        let localized = check(rule, """
            List {}.toolbar { Button(titleKey) { save() } }
            """)
        #expect(localized.map(\.line) == [1])
    }
}

@Suite("DR009 ArrangementView inside a list, scroll view or split view")
struct ArrangementViewPlacementRuleTests {
    let rule = ArrangementViewPlacementRule()

    @Test("Flags arrangement views nested in lists, scroll views and split views")
    func problematic() {
        let findings = check(rule, """
            var body: some View {
                ScrollView {
                    ArrangementView { Map() } secondary: { Details() }
                }
                NavigationSplitView {
                    Sidebar()
                } detail: {
                    VStack { ArrangementView { Map() } secondary: { Details() } }
                }
            }
            """)
        #expect(findings.map(\.line) == [3, 8])
        #expect(findings.first?.message.contains("ScrollView") == true)
    }

    @Test("Does not flag an arrangement view that contains the scrolling content")
    func corrected() {
        let findings = check(rule, """
            var body: some View {
                ArrangementView {
                    List(items) { Row($0) }
                } secondary: {
                    ScrollView { Details() }
                }
            }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not look past the enclosing declaration")
    func declarationBoundary() {
        let findings = check(rule, """
            struct Screen: View {
                var body: some View { List { Row() } }
            }
            struct Row: View {
                var body: some View { ArrangementView { A() } secondary: { B() } }
            }
            """)
        #expect(findings.isEmpty)
    }
}

@Suite("DR012 App-wide window lookups")
struct AppWideWindowRuleTests {
    let rule = AppWideWindowRule()

    @Test("Flags keyWindow, windows and connectedScenes.first")
    func problematic() {
        let findings = check(rule, """
            let window = UIApplication.shared.keyWindow
            let width = UIApplication.shared.windows.first?.bounds.width
            let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive })
            """)
        #expect(findings.map(\.line) == [1, 2, 3])
    }

    @Test("Does not flag the view's own window or scene")
    func corrected() {
        let findings = check(rule, """
            let window = view.window
            let scene = view.window?.windowScene
            let windows = scene.windows
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag reaching the scene delegate, and handles optional chaining")
    func edgeCases() {
        let findings = check(rule, """
            if let delegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate { delegate.reload() }
            let root = UIApplication.shared.keyWindow?.rootViewController
            """)
        #expect(findings.map(\.line) == [2])
    }
}
