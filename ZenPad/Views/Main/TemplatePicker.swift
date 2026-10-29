import SwiftUI

struct TemplatePicker: View {
    @ObservedObject var model: AppModel
    @State private var appeared = false
    private let templates = Templates.all
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("New from Template")
                    .font(.system(size: 17, weight: .semibold))
                Text("Placeholders like {{date}} are filled in for you.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                        TemplateCard(template: template) { model.newNote(from: template) }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(.zenSpring.delay(Double(index) * 0.025), value: appeared)
                    }
                }
                .padding(2)
            }
            HStack {
                Button("Open Templates Folder") { NSWorkspace.shared.open(Templates.folder) }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                Spacer()
                Button("Cancel") { model.showTemplates = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 560, height: 540)
        .onAppear { appeared = true }
    }
}

struct TemplateCard: View {
    let template: NoteTemplate
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: template.symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 22)
                Text(template.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(template.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.07 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(hovering ? Color.accentColor.opacity(0.5) : Color.zenHairline, lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.02 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.zenSnappy) { hovering = h } }
    }
}
