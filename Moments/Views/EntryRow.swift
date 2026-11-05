import SwiftUI

/// A timeline row in the Family Album style: photos and videos as tilted prints with the date stamp,
/// voice memos as cassette cards, notes as letters. Milestones carry a marigold ribbon.
struct EntryRow: View {
    let entry: Entry
    /// In the milestones view, the time since the first milestone; the row is then a compact card
    /// with its full date, since there are no month headers.
    var elapsed: String? = nil

    var body: some View {
        if let elapsed {
            MilestoneCard(entry: entry, elapsed: elapsed)
        } else {
            switch entry.kind {
            case .photo, .video: PrintRow(entry: entry)
            case .voice: CassetteRow(entry: entry)
            case .note: LetterRow(entry: entry)
            }
        }
    }
}

/// The title (or the day, for untitled entries), then the day and place.
private struct Caption: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.title.isEmpty {
                Text(entry.rowDateLabel).monospacedDigit()
            } else {
                Text(entry.title).font(.headline)
            }
            let day = entry.title.isEmpty ? nil : entry.rowDateLabel
            if day != nil || !entry.placeName.isEmpty {
                HStack(spacing: 5) {
                    if let day { Text(day) }
                    if day != nil, !entry.placeName.isEmpty { Text(verbatim: "·") }
                    if !entry.placeName.isEmpty {
                        Image("icon.postmark").resizable().frame(width: 15, height: 15).foregroundStyle(.postmark)
                        Text(entry.placeName)
                    }
                }
                .font(.meta)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }
}

/// Loads the entry's cover photo or video frame from Photos.
private struct Thumbnail: View {
    let entry: Entry
    var size: CGSize
    @State private var image: UIImage?
    @Environment(\.photosAccess) private var photosAccess

    var body: some View {
        Color.tab
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(entry.kind.icon).foregroundStyle(.secondary)
                }
            }
            .clipped()
            .task(id: PhotoLoad(item: entry.cover?.uuid, access: photosAccess)) {
                if let item = entry.cover, let id = await PhotoService.localID(for: item) {
                    image = await PhotoService.image(id, size: size)
                }
            }
    }
}

/// A photo or video as a print: white border, a slight tilt, the date stamp in the corner.
/// With several, the cover sits on a stack with "+2" pencilled beside it; voice memos are a cassette
/// tucked under its corner. A print added on this device drops onto the page and develops in.
private struct PrintRow: View {
    let entry: Entry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropped = true
    @State private var shown = true
    @State private var developed = true

    /// Each print keeps its own tilt (from its stable `uuid`): left-leaning ones sit left, the others right.
    private var tilt: Double {
        let b = entry.uuid.uuid
        let amount = 0.8 + Double(b.1 % 8) / 10
        return b.0 % 2 == 0 ? -amount : amount
    }

    var body: some View {
        let leading = tilt < 0
        // Room below the print for the cassette tucked under its corner.
        VStack(alignment: .leading, spacing: entry.voiceMemos.isEmpty ? 12 : 24) {
            HStack(spacing: 14) {
                if !leading { morePrints }
                photoPrint
                    .rotationEffect(.degrees(dropped ? tilt : -9))
                    .offset(y: dropped ? 0 : -50)
                    .opacity(shown ? 1 : 0)
                if leading { morePrints }
            }
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
            Caption(entry: entry).padding(.leading, 4)
        }
        .onAppear(perform: arrive)
    }

    private var photoPrint: some View {
        Thumbnail(entry: entry, size: CGSize(width: 900, height: 600))
            .aspectRatio(3 / 2, contentMode: .fit)
            .frame(maxWidth: 296)
            .saturation(developed ? 1 : 0)
            .brightness(developed ? 0 : 0.3)
            .blur(radius: developed ? 0 : 5)
            .overlay(alignment: .bottomTrailing) {
                DateStamp(date: entry.date).padding(.trailing, 10).padding(.bottom, 8)
            }
            .overlay {
                if entry.kind == .video {
                    Image("icon.play")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(entry.mediaSummary))
            .padding(EdgeInsets(top: 9, leading: 9, bottom: 26, trailing: 9))
            .background(Color.card)
            .printShadow()
            .background { stack }
            .overlay(alignment: .bottomLeading) {
                if !entry.voiceMemos.isEmpty { MemoTile(entry: entry).offset(x: -10, y: 20) }
            }
            .overlay(alignment: .topTrailing) {
                if entry.isMilestone {
                    Ribbon().offset(x: -22, y: -6).transition(.move(edge: .top).combined(with: .opacity))
                }
            }
    }

    /// Blank prints peeking out from under the cover when there are more (only the cover is loaded).
    private var stack: some View {
        ZStack {
            ForEach(0..<min(entry.prints.count - 1, 2), id: \.self) { i in
                Color.card
                    .printShadow(6)
                    .rotationEffect(.degrees(i == 0 ? 3.5 : -3))
                    .offset(x: i == 0 ? 6 : -5, y: i == 0 ? 3 : 6)
            }
        }
    }

    /// "+2" pencilled in the margin beside a stack.
    @ViewBuilder private var morePrints: some View {
        if entry.prints.count > 1 {
            Text(verbatim: "+\(entry.prints.count - 1)")
                .font(.margin)
                .foregroundStyle(.pencil)
                .accessibilityHidden(true)
        }
    }

    private func arrive() {
        guard Arrival.take(entry) else { return }
        if reduceMotion {
            shown = false
            withAnimation(.easeOut(duration: 0.25)) { shown = true }
            return
        }
        dropped = false
        shown = false
        developed = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
            dropped = true
            shown = true
        }
        withAnimation(.easeOut(duration: 1.6).delay(0.2)) { developed = true }
    }
}

/// A print's voice memos as a small cassette tile tucked under its corner; it plays the first one.
private struct MemoTile: View {
    let entry: Entry
    @State private var audio = AudioService()

    var body: some View {
        let count = entry.voiceMemos.count
        Button {
            guard let data = entry.voiceMemos.first?.audioData else { return }
            audio.isPlaying ? audio.stopPlaying() : audio.play(data)
        } label: {
            HStack(spacing: 4) {
                if audio.isPlaying {
                    Image(systemName: "stop.fill")
                } else {
                    Image("icon.voice").resizable().frame(width: 26, height: 26)
                }
                if count > 1 { Text(verbatim: "×\(count)").font(.caption.weight(.semibold)) }
            }
            .foregroundStyle(.darkroom)
            .padding(.horizontal, 10)
            .frame(minWidth: 52, minHeight: 44)
            .background(Color.tab, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.card, lineWidth: 2))
            .shadow(color: .shadow, radius: 4, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .rotationEffect(.degrees(-4))
        .accessibilityLabel(audio.isPlaying ? "Stop" : "Play Voice Memo")
        .onDisappear { audio.stopPlaying() }
    }
}

/// A voice-only entry as a cassette card; its button plays the first memo.
private struct CassetteRow: View {
    let entry: Entry
    @State private var audio = AudioService()

    var body: some View {
        CassetteCard(isPlaying: audio.isPlaying, count: entry.voiceMemos.count) {
            guard let data = entry.voiceMemos.first?.audioData else { return }
            audio.isPlaying ? audio.stopPlaying() : audio.play(data)
        } label: {
            Caption(entry: entry)
        }
        .overlay(alignment: .topTrailing) {
            if entry.isMilestone {
                Ribbon(width: 20).offset(x: -70, y: -6).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

/// A note as a letter: lined paper with a red margin, the text on the lines.
private struct LetterRow: View {
    let entry: Entry
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 26

    var body: some View {
        let spacing = max(0, lineHeight - UIFont.preferredFont(forTextStyle: .body).lineHeight)
        VStack(alignment: .leading, spacing: 0) {
            if !entry.title.isEmpty {
                Text(entry.title).fontWeight(.semibold).frame(height: lineHeight)
            }
            if !entry.text.isEmpty {
                Text(entry.text).lineSpacing(spacing).lineLimit(3)
                    .padding(.bottom, spacing)
            }
            Text(entry.rowDateLabel).font(.meta).foregroundStyle(.secondary).frame(height: lineHeight)
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LetterPaper(lineHeight: lineHeight, topInset: 10))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .printShadow(8)
        .overlay(alignment: .topTrailing) {
            if entry.isMilestone {
                Ribbon(width: 20).offset(x: -18, y: -6).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

/// A milestone in the milestones view: a small print (or the kind's tile), the title, full date and elapsed time.
private struct MilestoneCard: View {
    let entry: Entry
    let elapsed: String

    var body: some View {
        HStack(spacing: 14) {
            switch entry.kind {
            case .photo, .video:
                Thumbnail(entry: entry, size: CGSize(width: 200, height: 200))
                    .frame(width: 64, height: 64)
                    .padding(EdgeInsets(top: 4, leading: 4, bottom: 12, trailing: 4))
                    .background(Color.card)
                    .shadow(color: Color.shadow, radius: 4, y: 2)
                    .rotationEffect(.degrees(entry.uuid.uuid.0 % 2 == 0 ? -2 : 1.5))
            case .voice, .note:
                Image(entry.kind.icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.darkroom)
                    .frame(width: 72, height: 56)
                    .background(Color.tab, in: RoundedRectangle(cornerRadius: 5))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle).font(.headline).lineLimit(2)
                if !entry.title.isEmpty {
                    Text(entry.dateLabel).font(.meta).foregroundStyle(.secondary)
                }
                Text(elapsed).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 6))
        .printShadow(8)
    }
}

private extension Entry {
    /// What an entry holds, for VoiceOver, e.g. "3 photos, 1 video and 1 voice memo".
    var mediaSummary: String {
        let photos = prints.filter { $0.kind == .photo }.count
        let videos = prints.count - photos
        var parts: [String] = []
        if photos > 0 { parts.append(String(localized: "\(photos) photos")) }
        if videos > 0 { parts.append(String(localized: "\(videos) videos")) }
        if !voiceMemos.isEmpty { parts.append(String(localized: "\(voiceMemos.count) voice memos")) }
        return parts.formatted(.list(type: .and))
    }
}
