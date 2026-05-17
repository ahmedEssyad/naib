import SwiftUI
import ClickySDK

// Renders the finished invoice as a styled "paper" document.
// This is the visible payoff of the demo — judges see the form filled
// out by the assistant turn into a real-looking invoice.

struct DocumentPreviewScreen: View {
    let draft: InvoiceDraft
    @Binding var path: [DocumentsHomeScreen.HomeRoute]

    @State private var paperScale: CGFloat = 0.92
    @State private var paperOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.l) {
                successBadge
                invoicePaper
                Spacer(minLength: 40)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                paperScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                paperOpacity = 1
            }
        }
        .clickyScreen(id: "DocumentPreviewScreen", state: "Showing the finished invoice for \(draft.clientName), total \(formattedTotal). Done and Share buttons at bottom.")
    }

    // MARK: - Sections

    private var successBadge: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(DS.Colors.accentGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DS.Colors.accentGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Invoice ready")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("Looking good. Share, save, or come back to edit.")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(DS.Space.m)
        .card()
    }

    private var invoicePaper: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            paperHeader
            Divider()
            paperBillTo
            paperLineItems
            Divider()
            paperTotals
            if !draft.notes.isEmpty {
                Divider()
                paperNotes
            }
            paperFooter
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
        .scaleEffect(paperScale)
        .opacity(paperOpacity)
        .clickyElement("invoice-paper")
    }

    private var paperHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("INVOICE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(DS.Colors.brandPrimary)
                Text(draft.invoiceNumber)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(DS.Colors.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("From")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Ahmed Studio")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("hello@ahmedstudio.co")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }

    private var paperBillTo: some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BILL TO")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(DS.Colors.textTertiary)
                Text(draft.clientName.isEmpty ? "Client" : draft.clientName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                if !draft.clientEmail.isEmpty {
                    Text(draft.clientEmail)
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                if !draft.clientAddress.isEmpty {
                    Text(draft.clientAddress)
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                row("Issued", formattedIssueDate)
                row("Due", formattedDueDate)
            }
        }
    }

    private var paperLineItems: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DESCRIPTION")
                Spacer()
                Text("QTY")
                    .frame(width: 40, alignment: .trailing)
                Text("RATE")
                    .frame(width: 70, alignment: .trailing)
                Text("AMOUNT")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundColor(DS.Colors.textTertiary)
            .padding(.vertical, 8)

            Rectangle()
                .fill(DS.Colors.border)
                .frame(height: 1)

            HStack {
                Text(draft.lineDescription.isEmpty ? "Item" : draft.lineDescription)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text(draft.lineQuantity.isEmpty ? "0" : draft.lineQuantity)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(width: 40, alignment: .trailing)
                Text(formattedRate)
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(width: 70, alignment: .trailing)
                Text(formattedSubtotal)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 12)
        }
    }

    private var paperTotals: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Text("Subtotal")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                Text(formattedSubtotal)
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(width: 80, alignment: .trailing)
            }
            HStack {
                Spacer()
                Text("Tax (\(draft.taxPercent)%)")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                Text(formattedTax)
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(width: 80, alignment: .trailing)
            }
            HStack {
                Spacer()
                Text("TOTAL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(DS.Colors.textTertiary)
                Text(formattedTotal)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DS.Colors.brandPrimary)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding(.top, 4)
        }
    }

    private var paperNotes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(DS.Colors.textTertiary)
            Text(draft.notes)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private var paperFooter: some View {
        HStack {
            Spacer()
            Text("Generated with ClickyDocs")
                .font(.system(size: 10))
                .foregroundColor(DS.Colors.textTertiary)
            Spacer()
        }
        .padding(.top, DS.Space.s)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    // share stub
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.brandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DS.Colors.brandPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
                .clickyElement("share-document-button")

                Button {
                    path = []
                } label: {
                    Text("Done")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .clickyElement("done-button", onTap: {
                    path = []
                })
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 12)
        }
        .background(DS.Colors.surface)
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(DS.Colors.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textPrimary)
        }
    }

    private var formattedIssueDate: String { formatDate(draft.issueDate) }
    private var formattedDueDate: String { formatDate(draft.dueDate) }
    private var formattedRate: String { format(draft.rate) }
    private var formattedSubtotal: String { format(draft.subtotal) }
    private var formattedTax: String { format(draft.tax) }
    private var formattedTotal: String { format(draft.total) }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = draft.currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
