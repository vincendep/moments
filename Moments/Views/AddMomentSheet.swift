import SwiftUI

/// The shutter button's sheet: four tiles for the kinds of moment, and where it will be placed.
/// Opening it the first time asks for location access (the only switch for locations).
struct AddMomentSheet: View {
    enum Choice { case camera, library, note, voice }

    var onPick: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var place: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a moment").font(AlbumFont.display(30))
                if let place {
                    Label { Text(place) } icon: { Image("icon.postmark") }
                        .font(.subheadline)
                        .foregroundStyle(.postmark)
                        .lineLimit(1)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                tile(.camera, icon: "icon.camera", title: "Camera", hint: "A photo or a video")
                tile(.library, icon: "icon.library", title: "From Library", hint: "Keeps its own date and place")
                tile(.note, icon: "icon.note", title: "Note", hint: "A few lines to remember")
                tile(.voice, icon: "icon.voice", title: "Voice Memo", hint: "A laugh, a first word")
            }
            Button("Cancel") { dismiss() }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(480), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.card)
        .presentationCornerRadius(26)
        .task {
            if await LocationService.requestAccess(), let current = await LocationService.current() {
                place = current.name
            }
        }
    }

    private func tile(_ choice: Choice, icon: String, title: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        Button { onPick(choice) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.darkroom)
                    .accessibilityHidden(true)
                Text(title).font(.headline)
                Text(hint).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.rule))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
