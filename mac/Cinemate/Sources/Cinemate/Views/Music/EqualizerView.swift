import SwiftUI

// MARK: - Equalizer Panel View

struct EqualizerView: View {
    @ObservedObject var engineManager: AudioEngineManager

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let panelBackground = Color(white: 0.08)
    private let sliderTrackColor = Color.white.opacity(0.12)
    private let gridLineColor = Color.white.opacity(0.06)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // Frequency response curve
            frequencyResponseCurve
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // EQ Sliders
            slidersSection
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Preset selector + reset
            footerSection
        }
        .frame(width: 480, height: 460)
        .background(panelBackground)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Equalizer")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Enable/Disable toggle
            HStack(spacing: 6) {
                Text(engineManager.isEQEnabled ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(engineManager.isEQEnabled ? goldAccent : .gray)

                Toggle("", isOn: $engineManager.isEQEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(goldAccent)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Frequency Response Curve

    private var frequencyResponseCurve: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Background grid
                gridLines(width: width, height: height)

                // dB labels on left
                dBLabels(height: height)

                // The curve
                if engineManager.isEQEnabled {
                    eqCurvePath(width: width, height: height)
                        .stroke(
                            LinearGradient(
                                colors: [goldAccent, goldAccent.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )

                    // Fill under curve
                    eqCurveFilledPath(width: width, height: height)
                        .fill(
                            LinearGradient(
                                colors: [goldAccent.opacity(0.15), goldAccent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Flat line when disabled
                    Path { path in
                        let y = height / 2
                        path.move(to: CGPoint(x: 30, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                }
            }
        }
        .frame(height: 100)
    }

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, _ in
            let leftMargin: CGFloat = 30

            // Horizontal grid lines at -12, -6, 0, +6, +12
            let dBValues: [Float] = [-12, -6, 0, 6, 12]
            for dB in dBValues {
                let y = yForGain(dB, height: height)
                var path = Path()
                path.move(to: CGPoint(x: leftMargin, y: y))
                path.addLine(to: CGPoint(x: width, y: y))

                let lineColor = dB == 0
                    ? Color.white.opacity(0.15)
                    : gridLineColor

                context.stroke(path, with: .color(lineColor), lineWidth: dB == 0 ? 1 : 0.5)
            }

            // Vertical lines at each frequency
            for i in 0..<AudioEngineManager.bandCount {
                let x = xForBand(i, width: width, leftMargin: leftMargin)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
                context.stroke(path, with: .color(gridLineColor), lineWidth: 0.5)
            }
        }
    }

    private func dBLabels(height: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach([-12, -6, 0, 6, 12], id: \.self) { dB in
                Text(dB > 0 ? "+\(dB)" : "\(dB)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
                    .position(x: 14, y: yForGain(Float(dB), height: height))
            }
        }
    }

    private func eqCurvePath(width: CGFloat, height: CGFloat) -> Path {
        let leftMargin: CGFloat = 30
        let points = curvePoints(width: width, height: height, leftMargin: leftMargin)

        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)

            // Smooth catmull-rom style curve through points
            if points.count >= 2 {
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[i]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )

                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
        }
    }

    private func eqCurveFilledPath(width: CGFloat, height: CGFloat) -> Path {
        let leftMargin: CGFloat = 30
        let points = curvePoints(width: width, height: height, leftMargin: leftMargin)
        let zeroY = height / 2

        return Path { path in
            guard let first = points.first, let last = points.last else { return }

            // Start from zero line at left
            path.move(to: CGPoint(x: first.x, y: zeroY))
            path.addLine(to: first)

            // Curve through points
            if points.count >= 2 {
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[i]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )

                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }

            // Close to zero line
            path.addLine(to: CGPoint(x: last.x, y: zeroY))
            path.closeSubpath()
        }
    }

    private func curvePoints(width: CGFloat, height: CGFloat, leftMargin: CGFloat) -> [CGPoint] {
        (0..<AudioEngineManager.bandCount).map { i in
            CGPoint(
                x: xForBand(i, width: width, leftMargin: leftMargin),
                y: yForGain(engineManager.bandGains[i], height: height)
            )
        }
    }

    private func xForBand(_ band: Int, width: CGFloat, leftMargin: CGFloat) -> CGFloat {
        let usableWidth = width - leftMargin
        let spacing = usableWidth / CGFloat(AudioEngineManager.bandCount - 1)
        return leftMargin + CGFloat(band) * spacing
    }

    private func yForGain(_ gain: Float, height: CGFloat) -> CGFloat {
        // Map gain (-12..+12) to y (0..height), inverted (positive gain = higher = smaller y)
        let normalized = CGFloat((gain - AudioEngineManager.minGain) / (AudioEngineManager.maxGain - AudioEngineManager.minGain))
        return height * (1 - normalized)
    }

    // MARK: - Sliders Section

    private var slidersSection: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // dB scale on left
            VStack(spacing: 0) {
                Text("+12")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                Spacer()
                Text("0")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                Spacer()
                Text("-12")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(width: 28, height: 180)
            .padding(.bottom, 20) // align with slider area (above freq label)

            // 10 band sliders
            ForEach(0..<AudioEngineManager.bandCount, id: \.self) { i in
                VStack(spacing: 4) {
                    // Gain value label
                    Text(gainLabel(engineManager.bandGains[i]))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(
                            engineManager.isEQEnabled
                                ? (abs(engineManager.bandGains[i]) > 0.5 ? goldAccent : .gray)
                                : .gray.opacity(0.4)
                        )
                        .frame(height: 12)

                    // Vertical slider
                    VerticalEQSlider(
                        value: Binding(
                            get: { engineManager.bandGains[i] },
                            set: { engineManager.setGain(band: i, gain: $0) }
                        ),
                        range: AudioEngineManager.minGain...AudioEngineManager.maxGain,
                        isEnabled: engineManager.isEQEnabled,
                        accentColor: goldAccent
                    )
                    .frame(height: 170)

                    // Frequency label
                    Text(AudioEngineManager.frequencyLabels[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(height: 14)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func gainLabel(_ gain: Float) -> String {
        if abs(gain) < 0.1 { return "0" }
        let sign = gain > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", gain))"
    }

    // MARK: - Footer (Presets + Reset)

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Preset picker
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Menu {
                    ForEach(EQPreset.allPresets) { preset in
                        Button(action: {
                            engineManager.applyPreset(preset)
                        }) {
                            HStack {
                                Text(preset.name)
                                if engineManager.selectedPreset?.id == preset.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(engineManager.selectedPreset?.name ?? "Custom")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Spacer()

            // Reset button
            Button(action: {
                engineManager.resetBands()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                    Text("Reset")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Vertical EQ Slider

struct VerticalEQSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let isEnabled: Bool
    let accentColor: Color

    @State private var isDragging = false

    private let trackWidth: CGFloat = 3
    private let thumbSize: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let centerX = width / 2

            // Normalized position (0 = bottom = min, 1 = top = max)
            let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbY = height * (1 - normalized)

            // Zero position
            let zeroNormalized = CGFloat((0 - range.lowerBound) / (range.upperBound - range.lowerBound))
            let zeroY = height * (1 - zeroNormalized)

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: trackWidth, height: height)
                    .position(x: centerX, y: height / 2)

                // Zero line marker
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 10, height: 1)
                    .position(x: centerX, y: zeroY)

                // Active fill (from zero to thumb)
                if isEnabled && abs(value) > 0.1 {
                    let fillTop = min(thumbY, zeroY)
                    let fillBottom = max(thumbY, zeroY)
                    let fillHeight = fillBottom - fillTop

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accentColor.opacity(0.6))
                        .frame(width: trackWidth, height: fillHeight)
                        .position(x: centerX, y: fillTop + fillHeight / 2)
                }

                // Thumb
                Circle()
                    .fill(isEnabled ? accentColor : Color.gray.opacity(0.4))
                    .frame(width: isDragging ? thumbSize + 2 : thumbSize,
                           height: isDragging ? thumbSize + 2 : thumbSize)
                    .shadow(color: isEnabled ? accentColor.opacity(0.3) : .clear, radius: isDragging ? 6 : 0)
                    .position(x: centerX, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        isDragging = true
                        let y = gesture.location.y
                        let clamped = max(0, min(height, y))
                        let normalized = 1 - Float(clamped / height)
                        let newValue = range.lowerBound + normalized * (range.upperBound - range.lowerBound)
                        // Snap to zero when close
                        if abs(newValue) < 0.8 {
                            value = 0
                        } else {
                            value = round(newValue * 2) / 2 // snap to 0.5 increments
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}
