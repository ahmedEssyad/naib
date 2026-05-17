import SwiftUI
import ClickySDK

struct TemplatePickerScreen: View {
    @Binding var path: [DocumentsHomeScreen.HomeRoute]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.l) {
                header
                templateGrid
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Pick a template")
        .navigationBarTitleDisplayMode(.inline)
        .clickyScreen(id: "TemplatePickerScreen", state: "Choosing a document template. Tapping a template card opens its editor.")
    }

    private var header: some View {
        VStack(spacing: DS.Space.s) {
            Text("What are you creating?")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(DS.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Pick a template and we'll set up the structure for you.")
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, DS.Space.s)
    }

    private var templateGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Space.s), GridItem(.flexible(), spacing: DS.Space.s)], spacing: DS.Space.s) {
            ForEach(DocumentTemplate.allCases) { template in
                TemplateCard(template: template) {
                    if template == .invoice {
                        path.append(.invoiceEditor)
                    }
                    // Other templates left as stubs for the demo.
                }
                .clickyElement(elementId(for: template), onTap: {
                    if template == .invoice {
                        path.append(.invoiceEditor)
                    }
                })
            }
        }
    }

    private func elementId(for template: DocumentTemplate) -> String {
        switch template {
        case .invoice: return "template-invoice"
        case .letter: return "template-letter"
        case .contract: return "template-contract"
        case .receipt: return "template-receipt"
        case .nda: return "template-nda"
        case .resume: return "template-resume"
        }
    }
}

private struct TemplateCard: View {
    let template: DocumentTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.tint.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: template.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(template.tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(template.blurb)
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Space.m)
            .frame(height: 140)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
