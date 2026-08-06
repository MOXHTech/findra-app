import SwiftUI

enum FindraPalette {
    static func windowBackground(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
            ? LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.065, blue: 0.075),
                    Color(red: 0.030, green: 0.035, blue: 0.042)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            : LinearGradient(
                colors: [
                    Color(red: 0.965, green: 0.975, blue: 0.980),
                    Color(red: 0.925, green: 0.940, blue: 0.950)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.075, green: 0.085, blue: 0.095)
            : Color(red: 0.985, green: 0.990, blue: 0.992)
    }

    static func sidebar(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.060, green: 0.066, blue: 0.078)
            : Color(red: 0.925, green: 0.935, blue: 0.945)
    }

    static func toolbar(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.082, green: 0.092, blue: 0.104)
            : Color(red: 0.965, green: 0.972, blue: 0.976)
    }

    static func statusBar(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.052, green: 0.058, blue: 0.068)
            : Color(red: 0.925, green: 0.936, blue: 0.944)
    }

    static func selectedRow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.000, green: 0.455, blue: 0.525).opacity(0.34)
            : Color(red: 0.000, green: 0.470, blue: 0.560).opacity(0.16)
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.10)
    }
}
