protocol Shady {
	/// Shadow values for the theme being shown. A black shadow at 8% is
	/// invisible on the dark canvas, so each theme has its own set.
	func shadow(_ gShadow: Shadow, dark: Bool) -> ShadowData
}
