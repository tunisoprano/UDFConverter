import SwiftUI

extension Color {
    static let brandPrimary     = Color(red: 0x25 / 255, green: 0x63 / 255, blue: 0xEB / 255)
    static let brandPrimaryDark = Color(red: 0x1E / 255, green: 0x40 / 255, blue: 0xAF / 255)
    static let brandAccent      = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
}

extension LinearGradient {
    static let brandPrimary = LinearGradient(
        colors: [.brandPrimary, .brandPrimaryDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandAccent = LinearGradient(
        colors: [.brandAccent, .brandAccent.opacity(0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// Ana eylem butonları için ortak stil: basılı tutulunca hafifçe küçülür, gölgesi yumuşar.
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = .brandPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.brandPrimary.opacity(configuration.isPressed ? 0.12 : 0.28),
                    radius: configuration.isPressed ? 6 : 16,
                    y: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Degrade arka planlı, yuvarlak ikon rozeti — ekranlardaki hero ikonları için ortak görünüm.
struct IconBadge: View {
    var systemName: String
    var gradient: LinearGradient = .brandPrimary
    var diameter: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient.opacity(0.14))
                .frame(width: diameter, height: diameter)
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(gradient)
        }
    }
}
