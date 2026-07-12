import SwiftUI

enum WriterPalette {
    static let shell = Color(red: 0.020, green: 0.090, blue: 0.145)
    static let glassTint = Color(red: 0.80, green: 0.92, blue: 0.98)
    static let glassTintElevated = Color(red: 0.88, green: 0.98, blue: 0.96)
    static let paper = Color(red: 0.985, green: 0.965, blue: 0.910)
    static let paperTop = Color(red: 0.955, green: 0.975, blue: 0.990)
    static let paperInk = Color(red: 0.035, green: 0.045, blue: 0.055)
    static let sage = Color(red: 0.68, green: 0.90, blue: 0.86)
    static let amber = Color(red: 0.93, green: 0.72, blue: 0.38)
    static let hairline = Color.white.opacity(0.62)
    static let innerHighlight = Color.white.opacity(0.46)
}

enum WriterLayout {
    static let panelRadius: CGFloat = 22
    static let controlRadius: CGFloat = 16
    static let outerPadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 22
    static let sidebarWidth: CGFloat = 350
}

struct WriterBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.78)

            Rectangle()
                .fill(WriterPalette.shell.opacity(0.16))

            Rectangle()
                .fill(WriterPalette.glassTint.opacity(0.06))
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 8
    var material: Material = .ultraThinMaterial
    var strokeOpacity: Double = 0.16

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(strokeOpacity), lineWidth: 1)
            }
    }
}

struct WriterButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(isProminent ? WriterPalette.shell : Color.white.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 30)
            .background(buttonFill(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isProminent ? WriterPalette.sage.opacity(0.40) : Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isProminent ? 0.18 : 0.10), radius: isProminent ? 10 : 6, x: 0, y: 5)
    }

    private func buttonFill(isPressed: Bool) -> Color {
        if isProminent {
            return WriterPalette.sage.opacity(isPressed ? 0.74 : 0.92)
        }

        return Color.white.opacity(isPressed ? 0.20 : 0.11)
    }
}

extension View {
    func glassPanel(
        cornerRadius: CGFloat = 8,
        material: Material = .ultraThinMaterial,
        strokeOpacity: Double = 0.16
    ) -> some View {
        modifier(
            GlassPanel(
                cornerRadius: cornerRadius,
                material: material,
                strokeOpacity: strokeOpacity
            )
        )
    }

    func writerControlChrome(cornerRadius: CGFloat = 8) -> some View {
        background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(WriterPalette.hairline, lineWidth: 1)
            }
    }

    func writerInputChrome(cornerRadius: CGFloat = 14) -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(WriterPalette.glassTintElevated.opacity(0.34)),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.52), lineWidth: 1)
            }
    }

    func liquidGlassSurface(cornerRadius: CGFloat = 18, tintOpacity: Double = 0.54) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular.tint(WriterPalette.glassTint.opacity(tintOpacity)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(WriterPalette.glassTintElevated.opacity(tintOpacity * 0.12))
                }
        }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.44), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(WriterPalette.innerHighlight, lineWidth: 1)
                    .blendMode(.plusLighter)
                    .padding(1)
            }
            .shadow(color: .white.opacity(0.12), radius: 2, x: 0, y: -1)
            .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 8)
    }

    func puffyGlassSurface(cornerRadius: CGFloat = 22, tintOpacity: Double = 0.46) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular.tint(WriterPalette.glassTintElevated.opacity(tintOpacity)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.48), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                .padding(1)
        }
        .shadow(color: .white.opacity(0.14), radius: 2, x: 0, y: -1)
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    func liquidPaperSurface(cornerRadius: CGFloat = 18) -> some View {
        background(
            WriterPalette.paper,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}
