import AppKit
import LitraCore
import SwiftUI

struct MenuView: View {
    @Bindable var state: LightState
    // State is used directly because the @State macro plugin ships only with Xcode, not the Command Line Tools.
    private let showsSpectrum = State(initialValue: false)

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Litra Beam LX").font(.headline)
                        Text(state.device.connection).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.glass)
                }

                section("Backlight", systemImage: "light.max", isOn: $state.backOn) {
                    sliderRow("Brightness", value: "\(state.backPercent) %") {
                        Slider(value: intBinding($state.backPercent), in: range(LitraProtocol.backBrightnessRange))
                    }
                    HStack {
                        Text("Color")
                        Spacer()
                        Button {
                            showsSpectrum.wrappedValue.toggle()
                        } label: {
                            Circle()
                                .fill(Color(rgb: state.backColor))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .popover(isPresented: showsSpectrum.projectedValue, arrowEdge: .trailing) {
                            SpectrumPicker(rgb: $state.backColor)
                                .padding()
                        }
                    }
                }

                section("Front light", systemImage: "light.max", rotated: true, isOn: $state.frontOn) {
                    sliderRow("Brightness", value: "\(frontPercent) %") {
                        Slider(value: intBinding($state.frontLumen), in: range(LitraProtocol.brightnessRange))
                    }
                    sliderRow("Temperature", value: "\(state.frontKelvin.formatted()) K") {
                        // Reversed: cold on the left, warm on the right.
                        Slider(
                            value: reversedKelvinBinding,
                            in: range(LitraProtocol.temperatureRange),
                            step: Double(LitraProtocol.temperatureStep)
                        )
                    }
                    HStack {
                        ForEach(temperaturePresets, id: \.kelvin) { preset in
                            Button(preset.title) { state.frontKelvin = preset.kelvin }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 320)
    }

    /// Ordered like the reversed temperature slider: cold to warm.
    private let temperaturePresets = [(title: "Cool", kelvin: 6500), (title: "Neutral", kelvin: 4500), (title: "Warm", kelvin: 2700)]

    private func section(
        _ title: String,
        systemImage: String,
        rotated: Bool = false,
        isOn: Binding<Bool>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: isOn) {
                Label {
                    Text(title).font(.headline)
                } icon: {
                    Image(systemName: systemImage).rotationEffect(.degrees(rotated ? 180 : 0))
                }
            }
            .toggleStyle(.switch)
            content()
                .disabled(!isOn.wrappedValue)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func sliderRow(_ title: String, value: String, @ViewBuilder slider: () -> some View) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit().foregroundStyle(.secondary)
            }
            slider()
        }
    }

    /// Lumen range shown as 1–100 %, like the display brightness.
    private var frontPercent: Int {
        let range = LitraProtocol.brightnessRange
        let fraction = Double(state.frontLumen - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return max(1, Int((fraction * 100).rounded()))
    }

    private var reversedKelvinBinding: Binding<Double> {
        let sum = Double(LitraProtocol.temperatureRange.lowerBound + LitraProtocol.temperatureRange.upperBound)
        return Binding(
            get: { sum - Double(state.frontKelvin) },
            set: { state.frontKelvin = Int((sum - $0).rounded()) }
        )
    }

    private func intBinding(_ binding: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(binding.wrappedValue) }, set: { binding.wrappedValue = Int($0.rounded()) })
    }

    private func range(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }
}

/// Hue from left to right, saturation from white (top) to full color (bottom).
private struct SpectrumPicker: View {
    @Binding var rgb: Int

    private let size = CGSize(width: 260, height: 180)

    var body: some View {
        let color = NSColor(Color(rgb: rgb)).usingColorSpace(.sRGB) ?? .white
        let position = CGPoint(x: color.hueComponent * size.width, y: color.saturationComponent * size.height)

        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: stride(from: 0.0, through: 1.0, by: 1.0 / 6).map { Color(hue: $0, saturation: 1, brightness: 1) },
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom)
            Circle()
                .strokeBorder(.white, lineWidth: 3)
                .shadow(radius: 2)
                .frame(width: 18, height: 18)
                .offset(x: position.x - 9, y: position.y - 9)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 14))
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { drag in
                let hue = (drag.location.x / size.width).clamped(to: 0...1)
                let saturation = (drag.location.y / size.height).clamped(to: 0...1)
                rgb = Color(hue: min(hue, 0.999), saturation: saturation, brightness: 1).rgb
            }
        )
    }
}

private extension Color {
    init(rgb: Int) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    var rgb: Int {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return 0xFFFFFF }
        let component = { (value: CGFloat) in Int((value.clamped(to: 0...1) * 255).rounded()) }
        return component(color.redComponent) << 16 | component(color.greenComponent) << 8 | component(color.blueComponent)
    }
}
