import AppKit
import SwiftUI

// SPM executables launch as background processes by default.
// We must set the activation policy to .regular before SwiftUI
// initialises NSApplication, otherwise no window will ever appear.
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)

JSONViewerApp.main()
