import Foundation
import SwiftUI

/// Point sizes of the Dynamic Island and the Lock Screen banner on a 6.1-inch iPhone Pro, used by the previews.
public enum DynamicIslandMetrics {
    /// The island around the camera when nothing runs.
    public static let pillSize = CGSize(width: 126, height: 37)
    /// The width of each side of the compact presentation.
    public static let compactSideWidth: CGFloat = 74
    /// The diameter of the minimal presentation.
    public static let minimalDiameter: CGFloat = 37
    /// The width of the expanded island.
    public static let expandedWidth: CGFloat = 371
    /// The corner radius of the expanded island.
    public static let expandedCornerRadius: CGFloat = 44
    /// The width of the Lock Screen banner.
    public static let lockScreenWidth: CGFloat = 364
}

/// A drawn Dynamic Island in its compact presentation: the leading and trailing views beside the camera.
///
/// Live Activities only show on a device's real Dynamic Island; this draws one so galleries, previews and
/// screenshots can show every presentation side by side.
public struct DynamicIslandCompactPreview<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: DynamicIslandMetrics.compactSideWidth - 12, alignment: .leading)
                .padding(.leading, 12)
            Color.clear
                .frame(width: DynamicIslandMetrics.pillSize.width - 20)
            trailing
                .frame(width: DynamicIslandMetrics.compactSideWidth - 12, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .frame(height: DynamicIslandMetrics.pillSize.height)
        .background(Color.black, in: Capsule())
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// A drawn Dynamic Island in its minimal presentation: the island beside a small circle with the view, the way it
/// looks when two activities share the island.
public struct DynamicIslandMinimalPreview<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.black)
                .frame(width: DynamicIslandMetrics.pillSize.width, height: DynamicIslandMetrics.pillSize.height)
            content
                .frame(width: DynamicIslandMetrics.minimalDiameter - 10, height: DynamicIslandMetrics.minimalDiameter - 10)
                .frame(width: DynamicIslandMetrics.minimalDiameter, height: DynamicIslandMetrics.minimalDiameter)
                .background(Color.black, in: Circle())
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// A drawn Dynamic Island in its expanded presentation, with the leading and trailing regions beside the camera,
/// the center below it and the bottom region across.
public struct DynamicIslandExpandedPreview<Leading: View, Trailing: View, Center: View, Bottom: View>: View {
    private let leading: Leading
    private let trailing: Trailing
    private let center: Center
    private let bottom: Bottom

    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder center: () -> Center,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.center = center()
        self.bottom = bottom()
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                leading
                    .frame(maxWidth: .infinity, alignment: .leading)
                // The camera sits between the leading and trailing regions.
                Capsule()
                    .fill(Color(white: 0.08))
                    .frame(width: 92, height: 26)
                    .padding(.top, 4)
                trailing
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            center
                .frame(maxWidth: .infinity)
            bottom
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: DynamicIslandMetrics.expandedWidth)
        .background(Color.black, in: RoundedRectangle(cornerRadius: DynamicIslandMetrics.expandedCornerRadius, style: .continuous))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// A Lock Screen banner around a Lock Screen view: the padding, corner radius and dark translucent background the
/// system gives it, up to the banner's width.
public struct LockScreenActivityPreview<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(16)
            .frame(maxWidth: DynamicIslandMetrics.lockScreenWidth, alignment: .leading)
            .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}

extension LiveActivityTemplate {
    /// The template's compact island, drawn.
    @MainActor
    public static func compactPreview(_ attributes: Self, state: ContentState, isStale: Bool = false) -> some View {
        DynamicIslandCompactPreview {
            makeView(attributes: attributes, state: state, presentation: .compactLeading, isStale: isStale)
        } trailing: {
            makeView(attributes: attributes, state: state, presentation: .compactTrailing, isStale: isStale)
        }
    }

    /// The template's minimal island, drawn.
    @MainActor
    public static func minimalPreview(_ attributes: Self, state: ContentState, isStale: Bool = false) -> some View {
        DynamicIslandMinimalPreview {
            makeView(attributes: attributes, state: state, presentation: .minimal, isStale: isStale)
        }
    }

    /// The template's expanded island, drawn.
    @MainActor
    public static func expandedPreview(_ attributes: Self, state: ContentState, isStale: Bool = false) -> some View {
        DynamicIslandExpandedPreview {
            makeView(attributes: attributes, state: state, presentation: .expandedLeading, isStale: isStale)
        } trailing: {
            makeView(attributes: attributes, state: state, presentation: .expandedTrailing, isStale: isStale)
        } center: {
            makeView(attributes: attributes, state: state, presentation: .expandedCenter, isStale: isStale)
        } bottom: {
            makeView(attributes: attributes, state: state, presentation: .expandedBottom, isStale: isStale)
        }
    }

    /// The template's Lock Screen banner, drawn.
    @MainActor
    public static func lockScreenPreview(_ attributes: Self, state: ContentState, isStale: Bool = false) -> some View {
        LockScreenActivityPreview {
            makeView(attributes: attributes, state: state, presentation: .lockScreen, isStale: isStale)
        }
    }
}
