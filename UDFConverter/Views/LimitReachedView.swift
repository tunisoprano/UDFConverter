import SwiftUI

struct LimitReachedView: View {
    let nextResetDate: Date

    @Environment(\.dismiss) private var dismiss

    private var resetDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE"
        return formatter.string(from: nextResetDate)
    }

    var body: some View {
        ScrollView {
            content
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var content: some View {
        VStack(spacing: 20) {
            IconBadge(
                systemName: "hourglass",
                gradient: .brandAccent,
                diameter: 88
            )
            .padding(.top, 12)

            Text("Haftalık Limit Doldu")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text("Bu haftaki ücretsiz dönüştürme hakkınız bitti.\nHaklarınız **\(resetDateText)** tarihinde yenilenecek.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button("Tamam") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 4)
        }
        .padding(.vertical, 36)
    }
}
