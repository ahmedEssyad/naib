import Foundation

// The integrating app owns its own app map and passes it to ClickySDK
// via ClickyConfig.appMapJSON.
enum AppMapDefinition {
    static let json = #"""
{
  "appName": "ClickyDocs",
  "description": "A polished document-creation app. The user can pick a template (Invoice, Letter, Contract, Receipt, NDA, CV), fill in the form, and get a preview-ready document. The Invoice flow is the main demo path: DocumentsHomeScreen → TemplatePickerScreen → InvoiceEditorScreen → DocumentPreviewScreen.",
  "screens": [
    {
      "id": "DocumentsHomeScreen",
      "title": "Home — list of documents",
      "description": "Home screen. Shows greeting, a hero gradient 'New document' call-to-action, a horizontal scroller of quick templates (Invoice, Letter, Contract, Receipt), and a list of recent documents.",
      "elements": [
        { "id": "search-button", "label": "Search button (top right)", "type": "button" },
        { "id": "new-document-button", "label": "New document hero CTA card (purple gradient with + icon)", "type": "button", "description": "Opens the template picker screen." }
      ]
    },
    {
      "id": "TemplatePickerScreen",
      "title": "Pick a template",
      "description": "Grid of document templates. Tapping a card opens that template's editor. Only Invoice has a working editor in this demo; other templates are stubs.",
      "elements": [
        { "id": "template-invoice", "label": "Invoice template card", "type": "button", "description": "Bill a client for work done. Opens InvoiceEditorScreen." },
        { "id": "template-letter", "label": "Letter template card", "type": "button" },
        { "id": "template-contract", "label": "Contract template card", "type": "button" },
        { "id": "template-receipt", "label": "Receipt template card", "type": "button" },
        { "id": "template-nda", "label": "NDA template card", "type": "button" },
        { "id": "template-resume", "label": "CV / Resume template card", "type": "button" }
      ]
    },
    {
      "id": "InvoiceEditorScreen",
      "title": "Invoice editor",
      "description": "Form-heavy invoice editor. Three sections: Bill To (client name, email, address), Invoice details (number, issue date, due date, currency), Line item (description, quantity, rate, amount auto-computed), Tax & notes (tax %, notes). Totals card at the bottom shows subtotal, tax, total. Save & preview button at the bottom is disabled until client name + description + a positive total are entered. Tapping Save navigates to DocumentPreviewScreen.",
      "elements": [
        { "id": "client-name-field", "label": "Client name field", "type": "textfield", "description": "Full name of the client being billed. Required." },
        { "id": "client-email-field", "label": "Client email field", "type": "textfield" },
        { "id": "client-address-field", "label": "Client address field", "type": "textfield" },
        { "id": "invoice-number-field", "label": "Invoice number field", "type": "textfield", "description": "Pre-filled as INV-0042; user can change it." },
        { "id": "issue-date-picker", "label": "Issue date picker", "type": "datepicker" },
        { "id": "due-date-picker", "label": "Due date picker", "type": "datepicker", "description": "Defaults to 7 days after issue." },
        { "id": "currency-picker", "label": "Currency picker (USD / EUR / GBP / MAD / MRU / XOF)", "type": "picker" },
        { "id": "line-description-field", "label": "Line item description field", "type": "textfield", "description": "What was sold or rendered. Required." },
        { "id": "line-quantity-field", "label": "Line item quantity field (hours, units, etc.)", "type": "textfield" },
        { "id": "line-rate-field", "label": "Line item rate field (price per unit)", "type": "textfield" },
        { "id": "add-line-button", "label": "Add another line button", "type": "button", "description": "Stub for the demo — not implemented." },
        { "id": "tax-percent-field", "label": "Tax percentage field", "type": "textfield" },
        { "id": "notes-field", "label": "Notes / terms field", "type": "textfield" },
        { "id": "totals-card", "label": "Subtotal / tax / total summary card", "type": "card" },
        { "id": "save-invoice-button", "label": "Save & preview button (pinned to bottom)", "type": "button", "description": "Disabled until client name + line description + total > 0. Navigates to DocumentPreviewScreen." }
      ]
    },
    {
      "id": "DocumentPreviewScreen",
      "title": "Document preview",
      "description": "Renders the finished invoice as a styled paper document with header, bill-to, line items, totals, optional notes, and footer. Two buttons at bottom: Share and Done. Done returns to the documents home.",
      "elements": [
        { "id": "invoice-paper", "label": "The rendered invoice 'paper' card", "type": "card" },
        { "id": "share-document-button", "label": "Share button", "type": "button" },
        { "id": "done-button", "label": "Done button (pinned at bottom right)", "type": "button", "description": "Closes the preview and returns to the documents home." }
      ]
    }
  ]
}
"""#
}
