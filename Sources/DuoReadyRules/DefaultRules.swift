import DuoReadyCore

extension RuleRegistry {
    /// Every rule that ships with DuoReady.
    public static let builtIn = RuleRegistry(rules: [
        MainScreenRule(),
        OrientationLayoutRule(),
        DeviceIdiomLayoutRule(),
        FixedScreenDimensionRule(),
        FixedSizeConstraintRule(),
        FixedFrameRule(),
    ])
}
