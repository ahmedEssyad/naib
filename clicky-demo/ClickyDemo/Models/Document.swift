import Foundation
import SwiftUI

// MARK: - Document templates

enum DocumentTemplate: String, CaseIterable, Identifiable {
    case invoice = "Invoice"
    case letter = "Letter"
    case contract = "Contract"
    case receipt = "Receipt"
    case nda = "NDA"
    case resume = "CV / Resume"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .invoice: return "doc.text.fill"
        case .letter: return "envelope.fill"
        case .contract: return "doc.append.fill"
        case .receipt: return "list.bullet.rectangle.fill"
        case .nda: return "lock.doc.fill"
        case .resume: return "person.text.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .invoice: return DS.Colors.brandPrimary
        case .letter: return DS.Colors.accentGreen
        case .contract: return DS.Colors.brandSecondary
        case .receipt: return DS.Colors.accentOrange
        case .nda: return DS.Colors.textPrimary
        case .resume: return DS.Colors.accentRed
        }
    }

    var blurb: String {
        switch self {
        case .invoice: return "Bill a client for work done"
        case .letter: return "Formal business correspondence"
        case .contract: return "Service or work agreement"
        case .receipt: return "Confirmation of payment received"
        case .nda: return "Non-disclosure agreement"
        case .resume: return "Professional summary"
        }
    }
}

// MARK: - Saved documents

struct SavedDocument: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let templateName: String
    let templateIcon: String
    let updatedRelative: String
    let tint: Color

    static func == (lhs: SavedDocument, rhs: SavedDocument) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let sample: [SavedDocument] = [
        .init(
            title: "Invoice — Acme Corp",
            templateName: "Invoice",
            templateIcon: "doc.text.fill",
            updatedRelative: "Edited 2h ago",
            tint: DS.Colors.brandPrimary
        ),
        .init(
            title: "Mutual NDA — Patel & Co.",
            templateName: "NDA",
            templateIcon: "lock.doc.fill",
            updatedRelative: "Edited yesterday",
            tint: DS.Colors.textPrimary
        ),
        .init(
            title: "Letter to ContraFusion S.A.",
            templateName: "Letter",
            templateIcon: "envelope.fill",
            updatedRelative: "Edited 3d ago",
            tint: DS.Colors.accentGreen
        ),
    ]
}

// MARK: - Saved clients (for fast pick during invoice creation)

struct SavedClient: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let company: String
    let email: String
    let address: String

    static let sample: [SavedClient] = [
        .init(name: "John Smith", company: "Acme Corp.", email: "john@acme.io", address: "1 Park Ave · New York, NY"),
        .init(name: "Sophie Laurent", company: "Lumen Studio", email: "sophie@lumen.co", address: "12 rue de Rivoli · Paris"),
        .init(name: "Karim Benali", company: "Atlas Trading", email: "karim@atlas.ma", address: "Bd Mohamed V · Casablanca"),
    ]
}

// MARK: - Invoice data

struct InvoiceDraft: Equatable, Hashable {
    var clientName: String = ""
    var clientEmail: String = ""
    var clientAddress: String = ""
    var invoiceNumber: String = "INV-0042"
    var issueDate: Date = Date()
    var dueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var lineDescription: String = ""
    var lineQuantity: String = ""
    var lineRate: String = ""
    var taxPercent: String = "0"
    var notes: String = ""
    var currency: String = "USD"

    var quantity: Double { Double(lineQuantity) ?? 0 }
    var rate: Double { Double(lineRate) ?? 0 }
    var subtotal: Double { quantity * rate }
    var tax: Double { subtotal * (Double(taxPercent) ?? 0) / 100 }
    var total: Double { subtotal + tax }

    var canSave: Bool {
        !clientName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lineDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && total > 0
    }
}
