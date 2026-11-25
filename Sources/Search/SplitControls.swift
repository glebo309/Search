import SwiftUI

// Each page of a split, under the pointer: a small capsule at its top with
// what was only in the divider's right-click menu and the Tabs menu: move the
// page left or right, take it out of the split as a tab of its own, or close
// it. The others stay together.

/// The capsule itself, over the top of one page of a split.
struct SplitPaneControls: View {
    @ObservedObject var browser: Browser
    let tab: Tab
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Door(icon: "chevron.left", help: "Move Left") { withAnimation(Motion.panel) { browser.moveInSplit(tab, by: -1) } }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.35 : 1)
            Door(icon: "chevron.right", help: "Move Right") { withAnimation(Motion.panel) { browser.moveInSplit(tab, by: 1) } }
                .disabled(index == count - 1)
                .opacity(index == count - 1 ? 0.35 : 1)
            Door(icon: "rectangle.portrait.and.arrow.right", help: "Out of the Split, as a Tab of Its Own") {
                withAnimation(Motion.panel) { browser.leaveSplit(tab) }
            }
            Door(icon: "xmark", help: "Close This Page") { withAnimation(Motion.panel) { browser.close(tab) } }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Capsule(style: .continuous).fill(.regularMaterial))
        .overlay(Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}
