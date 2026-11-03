import SwiftUI
import UIKit

// Design-system tokens for the Family Album look: album paper, white prints, darkroom red.
// The colours are asset-catalog sets with light and dark (darkroom) values; fonts are bundled
// (Moments/Fonts, OFL) and scale with Dynamic Type.

extension ShapeStyle where Self == Color {
    /// The accent: actions, toggles, links. The app's `AccentColor` set, named directly:
    /// `.accentColor` follows the inherited tint instead.
    static var darkroom: Color { Color("AccentColor") }
    /// Solid red surfaces with white glyphs: the shutter button, the record button.
    static var darkroomFill: Color { Color("DarkroomFill") }
    /// Milestone marks only: ribbons, the thread, the scrubber dots.
    static var marigold: Color { Color("Marigold") }
    /// The album page behind every list and form.
    static var paper: Color { Color("Paper") }
    /// Print white: photo borders, cards, form rows.
    static var card: Color { Color("Card") }
    /// Warm brown-black text (the default foreground, set on `RootView`).
    static var ink: Color { Color("Ink") }
    /// Places: postmarks and location labels.
    static var postmark: Color { Color("Postmark") }
    /// Handwritten notes in the margin: the time between milestones.
    static var pencil: Color { Color("Pencil") }
    /// Inactive album tabs, voice-memo tiles.
    static var tab: Color { Color("Tab") }
    /// Hairlines: the tab baseline, letter-paper lines.
    static var rule: Color { Color("Rule") }
    /// The glowing film-camera date imprint on photos. Decoration only.
    static var dateStamp: Color { Color("DateStamp") }
    /// Drop shadows under prints and cards: warm in light mode, plain black in the darkroom.
    static var shadow: Color { Color("Shadow") }
    /// Glyphs on solid red: the shutter's plus.
    static var onDarkroom: Color { Color("OnDarkroom") }
    /// Tracks: the day scrubber's capsule.
    static var track: Color { Color.secondary.opacity(0.35) }
}

/// The bundled typefaces. Fraunces is the display serif (headings only, softened with its SOFT axis),
/// Caveat the handwriting (only short margin notes), VT323 the date stamp.
enum AlbumFont {
    private static func axis(_ tag: String) -> NSNumber {
        NSNumber(value: tag.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
    }

    private static func variable(_ name: String, size: CGFloat, axes: [String: CGFloat],
                                 style: UIFont.TextStyle) -> Font {
        let variations = Dictionary(uniqueKeysWithValues: axes.map { (axis($0.key), NSNumber(value: Double($0.value))) })
        let descriptor = UIFontDescriptor(name: name, size: size)
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations])
        let font = UIFont(descriptor: descriptor, size: size)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: font))
    }

    static func display(_ size: CGFloat, italic: Bool = false, style: UIFont.TextStyle = .title1) -> Font {
        variable(italic ? "Fraunces-Italic" : "Fraunces-Regular", size: size,
                 axes: ["opsz": min(max(size, 9), 144), "wght": 400, "SOFT": 100, "WONK": 0], style: style)
    }

    static func hand(_ size: CGFloat, style: UIFont.TextStyle = .title3) -> Font {
        variable("Caveat-Regular", size: size, axes: ["wght": 600], style: style)
    }

    static func stamp(_ size: CGFloat) -> Font { .custom("VT323-Regular", fixedSize: size) }

    /// UIKit version of the display font, for the navigation bar.
    static func uiDisplay(_ size: CGFloat) -> UIFont {
        let variations = [axis("opsz"): NSNumber(value: Double(size)), axis("wght"): 400, axis("SOFT"): 100, axis("WONK"): 0]
        let descriptor = UIFontDescriptor(name: "Fraunces-Regular", size: size)
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations])
        return UIFont(descriptor: descriptor, size: size)
    }
}

extension Font {
    // The serif is for headings only (timeline names, month headers, an entry's title on its own screen);
    // everything else, row text and notes included, is the system font.
    static let month = AlbumFont.display(30, italic: true)
    static let monthYear = AlbumFont.display(30)
    static let titleField = AlbumFont.display(32)
    /// Dates and milestone distances.
    static let meta = Font.subheadline.monospacedDigit()
    /// The voice recorder's running time.
    static let timer = Font.largeTitle.weight(.light).monospacedDigit()
    /// The time between milestones, written in the margin.
    static let margin = AlbumFont.hand(24)
}

extension View {
    /// Paper behind a `List` or `Form`, replacing the system grouped background.
    func paperBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.paper)
    }

    /// The soft drop shadow under prints and cards.
    func printShadow(_ radius: CGFloat = 10) -> some View {
        shadow(color: .shadow, radius: radius, y: radius * 0.6)
    }
}

/// A `Form` on paper with print-white rows. Use it instead of `Form` everywhere.
/// Its keyboard can be dragged away or hidden with a key above it (tapping outside is `KeyboardDismissal`).
struct PaperForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form { content.listRowBackground(Color.card) }
            .paperBackground()
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { KeyboardDismissal.hideKeyboard() } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("Hide Keyboard")
                }
            }
    }
}

/// The film-camera date imprint, e.g. "'26 11 02", glowing in the corner of a photo.
struct DateStamp: View {
    let date: Date
    var size: CGFloat = 19

    var body: some View {
        Text(verbatim: Self.text(date))
            .font(AlbumFont.stamp(size))
            .foregroundStyle(.dateStamp)
            .shadow(color: .dateStamp.opacity(0.8), radius: 3)
            .accessibilityHidden(true)
    }

    static func text(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }
}

/// Lined letter paper with a red margin, behind notes. `lineHeight` must match the text's line height.
struct LetterPaper: View {
    var lineHeight: CGFloat
    var topInset: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            var y = topInset + lineHeight
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y - 1, width: size.width, height: 1)), with: .color(.postmark.opacity(0.2)))
                y += lineHeight
            }
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 2, height: size.height)), with: .color(.darkroom.opacity(0.35)))
        }
        .background(Color.card)
        .accessibilityHidden(true)
    }
}

/// A strip of washi tape holding a print to the page.
struct Tape: View {
    var color: Color = .marigold
    var body: some View {
        Rectangle().fill(color.opacity(0.55)).frame(width: 70, height: 20).accessibilityHidden(true)
    }
}
