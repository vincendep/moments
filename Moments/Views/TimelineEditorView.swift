import SwiftUI

/// A timeline's settings: creates one (`timeline == nil`) or edits and deletes an existing one.
struct TimelineEditorView: View {
    let timeline: Timeline?
    /// Called with the new timeline after creating one.
    var onCreate: (Timeline) -> Void = { _ in }
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var albumMode = AlbumMode.perTimeline
    @State private var addImports = true
    @State private var confirmDelete = false

    /// "Moments 1.0 (1)": MARKETING_VERSION and CURRENT_PROJECT_VERSION from project.yml.
    private static let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return String(localized: "Moments \(short) (\(build))")
    }()

    var body: some View {
        NavigationStack {
            PaperForm {
                TextField("Name", text: $name)
                Section {
                    Picker("Save to", selection: $albumMode) {
                        ForEach(AlbumMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Toggle("Add library imports to album", isOn: $addImports)
                        .disabled(albumMode == .none)
                } header: {
                    Text("Media")
                } footer: {
                    Text("Photos and videos are always kept in your Photos library. This only changes which album new ones are added to.")
                }
                if timeline != nil {
                    Section {
                        Button("Delete Timeline", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                            .confirmationDialog("Delete \"\(timeline?.name ?? "")\"?", isPresented: $confirmDelete,
                                                titleVisibility: .visible) {
                                Button("Delete Timeline", role: .destructive, action: delete)
                            } message: {
                                Text("Its entries and voice memos will be deleted. Photos and videos stay in your Photos library.")
                            }
                    } footer: {
                        Text(Self.version)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
            }
            .navigationTitle(timeline?.name ?? String(localized: "timelineEditor.newTitle", defaultValue: "New Timeline"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let timeline else { return }
                name = timeline.name
                albumMode = timeline.albumMode
                addImports = timeline.addImportsToAlbum
            }
        }
    }

    private func save() {
        let newName = name.trimmingCharacters(in: .whitespaces)
        let t: Timeline
        if let timeline {
            if newName != timeline.name, let albumID = PhotoService.albumID(for: timeline) {
                Task { try? await PhotoService.renameAlbum(albumID, to: newName) }
            }
            t = timeline
            t.name = newName
        } else {
            t = Timeline(name: newName)
            ctx.insert(t)
            onCreate(t)
        }
        t.albumMode = albumMode
        t.addImportsToAlbum = addImports
        t.modifiedAt = .now
        dismiss()
    }

    private func delete() {
        guard let timeline else { return }
        ctx.delete(timeline)
        try? ctx.save()
        dismiss()
    }
}
