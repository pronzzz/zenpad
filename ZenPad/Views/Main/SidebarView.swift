import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library = Library.shared
    @ObservedObject var session = EditorSession.shared
    @FocusState private var searchFocused: Bool
    @Namespace private var selectionSpace

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                IconButton(symbol: "square.and.pencil", help: "New Note (⌘N)") { model.newNote() }
            }
            .frame(height: 40)
            .padding(.leading, 78)
            .padding(.trailing, 8)

            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let notes = library.filteredNotes
                    if notes.isEmpty {
                        emptyState
                    }
                    ForEach(notes) { note in
                        row(note)
                    }
                    if !library.externalNotes.isEmpty && library.searchText.isEmpty {
                        Text("OPENED FILES")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 10)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                        ForEach(library.externalNotes) { note in
                            row(note)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
                .animation(.zenSpring, value: library.filteredNotes.map(\.url))
            }
            .scrollIndicators(.never)

            footer
        }
        .background(VisualEffect(material: .sidebar))
        .onChange(of: model.searchFocusToken) { searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search notes", text: $library.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($searchFocused)
                .onExitCommand { library.searchText = ""; searchFocused = false }
            if !library.searchText.isEmpty {
                Button {
                    library.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(searchFocused ? 0.08 : 0.05)))
        .animation(.zenFade, value: library.searchText.isEmpty)
    }

    private func row(_ note: Note) -> some View {
        NoteRow(note: note, isSelected: session.note?.url == note.url, namespace: selectionSpace)
            .onTapGesture {
                withAnimation(.zenSnappy) { model.select(note) }
            }
            .contextMenu {
                Button("Show in Finder") { model.reveal(note) }
                Button("Duplicate") { model.duplicate(note) }
                if note.isExternal {
                    Button("Close File") { library.closeExternal(note); if session.note?.url == note.url { session.close(); model.ensureSelection() } }
                }
                Divider()
                Button("Move to Trash", role: .destructive) { model.moveToTrash(note) }
            }
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: library.searchText.isEmpty ? "square.and.pencil" : "magnifyingglass")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            Text(library.searchText.isEmpty ? "No notes yet" : "No matches")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var footer: some View {
        Button {
            NSWorkspace.shared.open(library.folderURL)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: library.folderURL.path.contains("Mobile Documents") ? "icloud" : "folder")
                Text(library.folderURL.lastPathComponent)
                    .lineLimit(1)
                Spacer()
                Text("\(library.notes.count)")
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open the notes folder in Finder")
    }
}

struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let namespace: Namespace.ID
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(note.modified.zenRelative)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .matchedGeometryEffect(id: "selection", in: namespace)
            } else if hovering {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.zenFade) { hovering = h } }
    }
}
