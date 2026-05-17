import SwiftUI
import ClickySDK

struct InvoiceEditorScreen: View {
    @Binding var path: [DocumentsHomeScreen.HomeRoute]
    @State private var draft: InvoiceDraft = InvoiceDraft()

    private let currencies = ["USD", "EUR", "GBP", "MAD", "MRU", "XOF"]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.l) {
                clientSection
                detailsSection
                lineItemSection
                taxNotesSection
                totalsCard
                Spacer(minLength: 40)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle("New invoice")
        .navigationBarTitleDisplayMode(.inline)
        .clickyScreen(id: "InvoiceEditorScreen", state: stateSummary)
    }

    // MARK: - Sections

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            sectionTitle("Bill to")
            VStack(spacing: 0) {
                editorRow(label: "Client name", placeholder: "e.g. John Smith", text: $draft.clientName)
                    .clickyElement("client-name-field", onSetText: { draft.clientName = $0 })
                Divider().padding(.leading, DS.Space.m)
                editorRow(label: "Email", placeholder: "client@example.com", text: $draft.clientEmail, keyboard: .emailAddress)
                    .clickyElement("client-email-field", onSetText: { draft.clientEmail = $0 })
                Divider().padding(.leading, DS.Space.m)
                editorRow(label: "Address", placeholder: "Street, city, country", text: $draft.clientAddress)
                    .clickyElement("client-address-field", onSetText: { draft.clientAddress = $0 })
            }
            .card()
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            sectionTitle("Invoice details")
            VStack(spacing: 0) {
                editorRow(label: "Invoice no.", placeholder: "INV-0001", text: $draft.invoiceNumber)
                    .clickyElement("invoice-number-field", onSetText: { draft.invoiceNumber = $0 })
                Divider().padding(.leading, DS.Space.m)
                HStack {
                    Text("Issue date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.Colors.textPrimary)
                    Spacer()
                    DatePicker("", selection: $draft.issueDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(DS.Colors.brandPrimary)
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 12)
                .clickyElement("issue-date-picker")
                Divider().padding(.leading, DS.Space.m)
                HStack {
                    Text("Due date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.Colors.textPrimary)
                    Spacer()
                    DatePicker("", selection: $draft.dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(DS.Colors.brandPrimary)
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 12)
                .clickyElement("due-date-picker")
                Divider().padding(.leading, DS.Space.m)
                HStack {
                    Text("Currency")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.Colors.textPrimary)
                    Spacer()
                    Menu {
                        ForEach(currencies, id: \.self) { code in
                            Button(code) { draft.currency = code }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(draft.currency)
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(DS.Colors.brandPrimary)
                    }
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 12)
                .clickyElement("currency-picker")
            }
            .card()
        }
    }

    private var lineItemSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            sectionTitle("Line item")
            VStack(spacing: 0) {
                editorRow(label: "Description", placeholder: "e.g. Consulting services", text: $draft.lineDescription)
                    .clickyElement("line-description-field", onSetText: { draft.lineDescription = $0 })
                Divider().padding(.leading, DS.Space.m)
                editorRow(label: "Quantity", placeholder: "0", text: $draft.lineQuantity, keyboard: .decimalPad)
                    .clickyElement("line-quantity-field", onSetText: { draft.lineQuantity = $0 })
                Divider().padding(.leading, DS.Space.m)
                editorRow(label: "Rate", placeholder: "0.00", text: $draft.lineRate, keyboard: .decimalPad)
                    .clickyElement("line-rate-field", onSetText: { draft.lineRate = $0 })
                Divider().padding(.leading, DS.Space.m)
                HStack {
                    Text("Amount")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.Colors.textPrimary)
                    Spacer()
                    Text(formattedSubtotal)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 12)
            }
            .card()

            Button {
                // stub — adding more line items left for post-demo
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text("Add another line")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.brandPrimary)
            }
            .clickyElement("add-line-button")
        }
    }

    private var taxNotesSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            sectionTitle("Tax & notes")
            VStack(spacing: 0) {
                editorRow(label: "Tax (%)", placeholder: "0", text: $draft.taxPercent, keyboard: .decimalPad)
                    .clickyElement("tax-percent-field", onSetText: { draft.taxPercent = $0 })
                Divider().padding(.leading, DS.Space.m)
                editorRow(label: "Notes", placeholder: "Thanks for your business", text: $draft.notes)
                    .clickyElement("notes-field", onSetText: { draft.notes = $0 })
            }
            .card()
        }
    }

    private var totalsCard: some View {
        VStack(spacing: 0) {
            totalsRow("Subtotal", formattedSubtotal)
            Divider().padding(.leading, DS.Space.m)
            totalsRow("Tax", formattedTax)
            Divider().padding(.leading, DS.Space.m)
            HStack {
                Text("Total")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(formattedTotal)
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 14)
            .foregroundColor(DS.Colors.textPrimary)
        }
        .card()
        .clickyElement("totals-card")
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                if draft.canSave {
                    path.append(.documentPreview(draft))
                }
            } label: {
                HStack(spacing: 8) {
                    Text(draft.canSave ? "Save & preview" : "Fill the required fields")
                    if draft.canSave {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: draft.canSave))
            .disabled(!draft.canSave)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 12)
            .clickyElement("save-invoice-button", onTap: {
                if draft.canSave { path.append(.documentPreview(draft)) }
            })
        }
        .background(DS.Colors.surface)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DS.Colors.textTertiary)
            .padding(.leading, 4)
    }

    private func editorRow(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Colors.textPrimary)
                .frame(width: 110, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 14))
                .multilineTextAlignment(.trailing)
                .foregroundColor(DS.Colors.textPrimary)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 12)
    }

    private func totalsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Colors.textPrimary)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 12)
    }

    private var formattedSubtotal: String { format(draft.subtotal) }
    private var formattedTax: String { format(draft.tax) }
    private var formattedTotal: String { format(draft.total) }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = draft.currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var stateSummary: String {
        """
        Client name: \(draft.clientName.isEmpty ? "(empty)" : draft.clientName). \
        Description: \(draft.lineDescription.isEmpty ? "(empty)" : draft.lineDescription). \
        Quantity: \(draft.lineQuantity.isEmpty ? "(empty)" : draft.lineQuantity). \
        Rate: \(draft.lineRate.isEmpty ? "(empty)" : draft.lineRate). \
        Currency: \(draft.currency). \
        Total: \(format(draft.total)). \
        Save enabled: \(draft.canSave).
        """
    }
}
