import DuoReadyCore

/// DR010: UIRequiresFullScreen, which no longer prevents resizing.
public struct RequiresFullScreenRule: ProjectRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR010",
        title: "UIRequiresFullScreen no longer prevents resizing",
        category: .projectConfiguration,
        defaultSeverity: .warning,
        confidence: .high,
        rationale: """
            UIRequiresFullScreen is deprecated. Apple (TN3192): "Starting in iOS 27 and iPadOS 27, \
            UIRequiresFullScreen no longer opts your app out of resizing on either platform. Instead, \
            the system resizes your app's scene discretely." This applies when you build with the iOS \
            27 SDK. An app that relies on the key to keep a fixed size will be resized anyway, on \
            iPhone Duo and on iPad.
            """,
        suggestion: """
            Make your layouts resizable, then remove UIRequiresFullScreen (or the \
            INFOPLIST_KEY_UIRequiresFullScreen build setting). If you need more time after building \
            with the iOS 27 SDK, Apple's UIRequiresFullScreenIgnoredStartingWithVersion key controls \
            when the system starts ignoring it. See TN3192.
            """,
        limitations: """
            Reads every .plist file and Xcode project in the scanned folder. Info.plist files outside \
            that folder, and settings in .xcconfig files, are not read. A plist that also sets \
            UIRequiresFullScreenIgnoredStartingWithVersion is not reported, because its migration is \
            already planned.
            """
    )

    static let key = "UIRequiresFullScreen"
    static let buildSetting = "INFOPLIST_KEY_UIRequiresFullScreen"

    public func check(_ project: ProjectContext) -> [Finding] {
        let message = "UIRequiresFullScreen no longer stops resizing when you build with the iOS 27 SDK."
        var findings: [Finding] = []
        for plist in project.propertyLists
        where plist.root[Self.key]?.isTrue == true && plist.root["UIRequiresFullScreenIgnoredStartingWithVersion"] == nil {
            findings.append(finding(in: plist, key: Self.key, message: message))
        }
        for settings in project.projectSettings {
            for line in settings.lines(setting: Self.buildSetting, value: "YES") {
                findings.append(finding(in: settings, line: line, message: message))
            }
        }
        return findings
    }
}
