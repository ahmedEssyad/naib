import SwiftUI
import ClickySDK

struct DocumentsHomeScreen: View {
    @State private var path: [HomeRoute] = []
    private let documents = SavedDocument.sample

    enum HomeRoute: Hashable {
        case templatePicker
        case invoiceEditor
        case documentPreview(InvoiceDraft)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: DS.Space.l) {
                    header
                    heroNewDocumentCard
                    quickTemplates
                    recentDocuments
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.bottom, 140)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .templatePicker:
                    TemplatePickerScreen(path: $path)
                case .invoiceEditor:
                    InvoiceEditorScreen(path: $path)
                case .documentPreview(let draft):
                    DocumentPreviewScreen(draft: draft, path: $path)
                }
            }
        }
        .clickyScreen(id: "DocumentsHomeScreen", state: "User has \(documents.count) recent documents.")
    }

    private var header: some View {
        HStack(spacing: DS.Space.m) {
            Circle()
                .fill(DS.Colors.heroGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Text("A")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Good morning")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.textSecondary)
                Text("Your documents")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(DS.Colors.textPrimary)
            }
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DS.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(DS.Colors.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.Colors.border, lineWidth: 1))
                .clickyElement("search-button")
        }
        .padding(.top, DS.Space.s)
    }

    private var heroNewDocumentCard: some View {
        Button {
            path.append(.templatePicker)
        } label: {
            HStack(spacing: DS.Space.m) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("New document")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Invoice, letter, contract, NDA…")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(DS.Space.l)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .fill(DS.Colors.heroGradient)
            )
            .shadow(color: DS.Colors.brandPrimary.opacity(0.25), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .clickyElement("new-document-button", onTap: {
            path.append(.templatePicker)
        })
    }

    private var quickTemplates: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Quick templates")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DS.Colors.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.s) {
                    ForEach(Array(DocumentTemplate.allCases.prefix(4)), id: \.self) { template in
                        QuickTemplateChip(template: template) {
                            if template == .invoice {
                                path.append(.invoiceEditor)
                            } else {
                                path.append(.templatePicker)
                            }
                        }
                    }
                }
            }
        }
    }

    private var recentDocuments: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                Text("Recent")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Button("See all") {}
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.brandPrimary)
            }
            VStack(spacing: 0) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, doc in
                    DocumentRow(document: doc)
                    if index < documents.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .card()
        }
    }
}

private struct QuickTemplateChip: View {
    let template: DocumentTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(template.tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: template.iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(template.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(template.blurb)
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160, alignment: .leading)
            .padding(DS.Space.m)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DocumentRow: View {
    let document: SavedDocument

    var body: some View {
        HStack(spacing: DS.Space.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(document.tint.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: document.templateIcon)
                    .font(.system(size: 19))
                    .foregroundColor(document.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(document.templateName) · \(document.updatedRelative)")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 14)
    }
}
