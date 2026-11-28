import SwiftUI
import UIKit

// MARK: - View Modifier for Target Registration
extension View {
    func spotlightTarget(step: SpotlightStep) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightFramePreferenceKey.self,
                    value: [step: geo.frame(in: .named("SpotlightCoordinateSpace"))]
                )
            }
        )
    }
}

// MARK: - Live UITabBar Target Frame Discovery (iOS 17 / 18 / 26 Liquid Glass Compatible)
private struct TabBarSpotlightFrameProbe: UIViewRepresentable {
    let tabIndex: Int
    let totalTabs: Int
    let onFrame: (CGRect) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.tabIndex = tabIndex
        view.totalTabs = totalTabs
        view.onFrame = onFrame
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.tabIndex = tabIndex
        uiView.totalTabs = totalTabs
        uiView.onFrame = onFrame
        uiView.measureIfPossible()
    }

    final class ProbeView: UIView {
        var tabIndex: Int = 2
        var totalTabs: Int = 5
        var onFrame: ((CGRect) -> Void)?
        private var lastReportedFrame: CGRect = .zero

        override func didMoveToWindow() {
            super.didMoveToWindow()
            measureIfPossible()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            measureIfPossible()
        }

        func measureIfPossible() {
            guard let window, bounds.width > 0, bounds.height > 0 else { return }
            guard let tabBar = findTabBar(in: window) else { return }
            let computed = computeTabItemRect(in: tabBar)
            guard computed.width > 12, computed.height > 12 else { return }

            if abs(computed.minX - lastReportedFrame.minX) > 0.5 ||
                abs(computed.minY - lastReportedFrame.minY) > 0.5 ||
                abs(computed.width - lastReportedFrame.width) > 0.5 ||
                abs(computed.height - lastReportedFrame.height) > 0.5 {
                lastReportedFrame = computed
                DispatchQueue.main.async { [weak self] in
                    self?.onFrame?(computed)
                }
            }
        }

        private func computeTabItemRect(in tabBar: UITabBar) -> CGRect {
            let fullBarRect = tabBar.convert(tabBar.bounds, to: self)
            let pillRect = findFloatingPlatterRect(in: tabBar, fullBarRect: fullBarRect) ?? fullBarRect

            let buttons = collectInteractiveTabButtons(in: tabBar)
                .map { $0.convert($0.bounds, to: self) }
                .sorted { $0.minX < $1.minX }

            if buttons.count == totalTabs, tabIndex < buttons.count {
                return buttons[tabIndex].insetBy(dx: -2, dy: 0)
            }

            let bottomSafe = window?.safeAreaInsets.bottom ?? 0
            let highlightHeight: CGFloat
            let highlightCenterY: CGFloat
            if pillRect.height > 72 && bottomSafe > 0 {
                // Docked classic tab bar includes home-indicator safe area at bottom.
                let activeBarHeight = pillRect.height - bottomSafe
                highlightHeight = min(52, max(44, activeBarHeight - 4))
                highlightCenterY = pillRect.minY + activeBarHeight / 2
            } else {
                highlightHeight = min(54, max(44, pillRect.height - 6))
                highlightCenterY = pillRect.midY
            }

            let count = max(tabBar.items?.count ?? totalTabs, 1)
            let slotWidth = pillRect.width / CGFloat(count)
            let highlightWidth = min(68, max(54, slotWidth - 8))

            // On iOS 26 Floating Liquid Glass UITabBar, the active tab's selection platter can be
            // slightly wider than inactive items, shifting geometric equal-slice centers by ~5pt.
            // Measure the actual rendered tab title label inside UITabBar to stay pixel-centered.
            if let exactLabelRect = findTabTitleRect(in: tabBar, pillRect: pillRect) {
                let clampedWidth = min(70, max(highlightWidth, exactLabelRect.width + 20))
                return CGRect(
                    x: exactLabelRect.midX - clampedWidth / 2,
                    y: highlightCenterY - highlightHeight / 2,
                    width: clampedWidth,
                    height: highlightHeight
                )
            }

            let centerX = pillRect.minX + slotWidth * (CGFloat(tabIndex) + 0.5)
            return CGRect(
                x: centerX - highlightWidth / 2,
                y: highlightCenterY - highlightHeight / 2,
                width: highlightWidth,
                height: highlightHeight
            )
        }

        private func findTabTitleRect(in tabBar: UITabBar, pillRect: CGRect) -> CGRect? {
            let expectedTitle: String = {
                if let items = tabBar.items, tabIndex < items.count, let title = items[tabIndex].title, !title.isEmpty {
                    return title
                }
                return String(localized: "AI Chef")
            }()
            let normalizedTarget = expectedTitle.trimmingCharacters(in: .whitespacesAndNewlines)

            var labelCandidates: [CGRect] = []
            func scanLabels(_ view: UIView) {
                guard !view.isHidden, view.alpha > 0.01 else { return }
                if let label = view as? UILabel {
                    let text = (label.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if text == normalizedTarget {
                        let rect = label.convert(label.bounds, to: self)
                        if rect.width > 8, rect.height > 4,
                           rect.midX >= pillRect.minX, rect.midX <= pillRect.maxX {
                            labelCandidates.append(rect)
                        }
                    }
                } else {
                    for subview in view.subviews {
                        scanLabels(subview)
                    }
                }
            }
            scanLabels(tabBar)

            guard !labelCandidates.isEmpty else { return nil }
            // Prefer the candidate closest to the expected slot if duplicates exist (e.g., lens effect layer)
            let expectedX = pillRect.minX + (pillRect.width / CGFloat(max(totalTabs, 1))) * (CGFloat(tabIndex) + 0.5)
            return labelCandidates.min { abs($0.midX - expectedX) < abs($1.midX - expectedX) }
        }

        private func findTabBar(in root: UIView) -> UITabBar? {
            if let tabBar = root as? UITabBar, !tabBar.isHidden, tabBar.alpha > 0.01 {
                return tabBar
            }
            for subview in root.subviews {
                if let found = findTabBar(in: subview) {
                    return found
                }
            }
            return nil
        }

        private func collectInteractiveTabButtons(in root: UIView) -> [UIView] {
            var matches: [UIView] = []
            let maxControlWidth = (root.window?.bounds.width ?? 430) * 0.4
            for subview in root.subviews where !subview.isHidden && subview.alpha > 0.01 {
                let rect = subview.bounds
                if subview is UIControl,
                   rect.width >= 32,
                   rect.width <= maxControlWidth,
                   rect.height >= 28,
                   rect.height <= 70 {
                    matches.append(subview)
                } else {
                    matches.append(contentsOf: collectInteractiveTabButtons(in: subview))
                }
            }
            return matches
        }

        private func findFloatingPlatterRect(in tabBar: UITabBar, fullBarRect: CGRect) -> CGRect? {
            var best: CGRect?
            func scan(_ view: UIView) {
                for subview in view.subviews where !subview.isHidden && subview.alpha > 0.01 {
                    let rect = subview.convert(subview.bounds, to: self)
                    if rect.width >= fullBarRect.width * 0.65,
                       rect.width <= fullBarRect.width - 6,
                       rect.height >= 44,
                       rect.height <= 68 {
                        if best == nil || rect.width > best!.width {
                            best = rect
                        }
                    }
                    scan(subview)
                }
            }
            scan(tabBar)
            return best
        }
    }
}

// MARK: - Interactive Editorial Spotlight Overlay (Calm Warm Oat Focus Ring)
struct SpotlightOverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var manager: SpotlightTourManager = .shared
    @State private var ringScale: CGFloat = 0.96

    var body: some View {
        ZStack {
            if SpotlightTourManager.shouldMeasureTabBar(isTourActive: manager.isTourActive) {
                TabBarSpotlightFrameProbe(tabIndex: 2, totalTabs: 5) { rect in
                    manager.tabBarChefFrame = rect
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            if manager.isTourActive {
                GeometryReader { screenGeo in
                    let activeRect = resolvedTargetRect(for: manager.currentStep)
                    if let targetRect = activeRect,
                       targetRect.width > 0,
                       targetRect.height > 0 {
                        let rawPaddedRect = targetRect.insetBy(dx: -5, dy: -5)
                        let minAllowedTop = max(screenGeo.safeAreaInsets.top + 2, 58)
                        let topTrim = max(0, minAllowedTop - rawPaddedRect.minY)
                        let paddedRect = CGRect(
                            x: rawPaddedRect.minX,
                            y: rawPaddedRect.minY + topTrim,
                            width: rawPaddedRect.width,
                            height: max(24, rawPaddedRect.height - topTrim)
                        )
                        let cornerRadius = manager.currentStep.ringCornerRadius(for: paddedRect)
                        let placement = cardPlacement(for: paddedRect, in: screenGeo)

                        ZStack(alignment: .topLeading) {
                            interactiveBackdrop

                            // Clean calm focus ring matching the target shape
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(EditorialPalette.oat, lineWidth: 1.75)
                                .background(
                                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                        .stroke(Color.white.opacity(0.22), lineWidth: 5)
                                )
                                .frame(width: paddedRect.width, height: paddedRect.height)
                                .scaleEffect(reduceMotion ? 1.0 : ringScale)
                                .position(x: paddedRect.midX, y: paddedRect.midY)
                                .onTapGesture {
                                    advanceWithHaptic()
                                }

                            VStack(spacing: 0) {
                                if placement.placeAbove {
                                    Spacer(minLength: placement.topMargin)
                                }

                                tourCard
                                    .padding(.horizontal, 20)
                                    .padding(.top, placement.placeAbove ? 0 : placement.topPadding)
                                    .padding(.bottom, placement.placeAbove ? placement.bottomPadding : 0)

                                if !placement.placeAbove {
                                    Spacer(minLength: placement.bottomMargin)
                                }
                            }
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        }
                    } else {
                        ZStack {
                            interactiveBackdrop
                            tourCard
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84), value: manager.currentStep)
                .onAppear {
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            ringScale = 1.0
                        }
                    }
                }
                .onChange(of: manager.currentStep) { _, _ in
                    guard !reduceMotion else { return }
                    ringScale = 0.96
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        ringScale = 1.0
                    }
                }
            }
        }
    }

    private func resolvedTargetRect(for step: SpotlightStep) -> CGRect? {
        if step == .aiChef, manager.tabBarChefFrame.width > 12, manager.tabBarChefFrame.height > 12 {
            return manager.tabBarChefFrame
        }
        return manager.targetFrames[step]
    }

    private func cardPlacement(
        for paddedRect: CGRect,
        in screenGeo: GeometryProxy
    ) -> (placeAbove: Bool, topPadding: CGFloat, bottomPadding: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat) {
        let topSafe = max(screenGeo.safeAreaInsets.top + 2, 58)
        let tabBarTop = manager.tabBarChefFrame.height > 12
            ? manager.tabBarChefFrame.minY
            : screenGeo.size.height - max(screenGeo.safeAreaInsets.bottom, 34) - 56
        let bottomSafe = max(max(screenGeo.safeAreaInsets.bottom, 24), screenGeo.size.height - tabBarTop + 10)

        let spaceAbove = max(0, paddedRect.minY - topSafe - 14)
        let spaceBelow = max(0, (screenGeo.size.height - bottomSafe) - paddedRect.maxY - 14)
        let placeAbove = spaceAbove > spaceBelow

        let maxCardTopBelow = max(topSafe, screenGeo.size.height - bottomSafe - 210)
        let clampedTopBelow = min(max(topSafe, paddedRect.maxY + 14), maxCardTopBelow)
        let rawBottomAbove = max(max(screenGeo.safeAreaInsets.bottom, 24), screenGeo.size.height - paddedRect.minY + 14)
        let maxBottomAbove = max(24, screenGeo.size.height - topSafe - 210)
        let clampedBottomAbove = min(rawBottomAbove, maxBottomAbove)

        return (placeAbove, clampedTopBelow, clampedBottomAbove, topSafe, bottomSafe)
    }

    private var interactiveBackdrop: some View {
        Color.black.opacity(0.56)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onTapGesture {
                advanceWithHaptic()
            }
    }

    private var tourCard: some View {
        FloatingTourCard(
            step: manager.currentStep,
            onNext: { advanceWithHaptic() },
            onPrev: {
                HapticManager.shared.impact(style: .light)
                manager.previousStep()
            },
            onSkip: {
                HapticManager.shared.impact(style: .light)
                manager.finishTour()
            }
        )
    }

    private func advanceWithHaptic() {
        HapticManager.shared.impact(style: .medium)
        manager.nextStep()
    }
}

// MARK: - Editorial Matte Slate Spotlight Tooltip
private struct FloatingTourCard: View {
    let step: SpotlightStep
    let onNext: () -> Void
    let onPrev: () -> Void
    let onSkip: () -> Void

    var isLastStep: Bool {
        step == SpotlightStep.allCases.last
    }

    var isFirstStep: Bool {
        step == SpotlightStep.allCases.first
    }

    var body: some View {
        EditorialDarkCard(cornerRadius: 20, borderColor: EditorialPalette.cardBorderDarkFocused, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(SpotlightStep.allCases) { item in
                        Capsule()
                            .fill(item.rawValue <= step.rawValue ? EditorialPalette.oat : Color.white.opacity(0.14))
                            .frame(height: 3)
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(step.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(step.tag)
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(EditorialPalette.oat)

                    Button(action: onSkip) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .accessibilityIdentifier("spotlight_skip_button")
                    .accessibilityLabel("Skip")
                }

                Text(step.description)
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if !isFirstStep {
                        Button(action: onPrev) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(EditorialPalette.chipDark)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                                )
                        }
                    }

                    Button(action: onNext) {
                        Text(isLastStep ? String(localized: "Done") : String(localized: "Next"))
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .oat, height: 44, cornerRadius: 12))
                }
            }
        }
    }
}
