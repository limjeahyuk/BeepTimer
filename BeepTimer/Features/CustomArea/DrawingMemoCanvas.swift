//
//  DrawingMemoCanvas.swift
//  BeepTimer
//
//  투명 배경 그림 메모 캔버스 — 타이머 위에 올려도 시간이 그대로 보인다
//

import SwiftUI

struct DrawingMemoCanvas: View {
    @Binding var strokes: [DrawingStroke]
    /// 펜 색 — 상세 설정에서 선택
    var penColorHex: String = DrawingPalette.colors[0]

    @State private var currentPoints: [CGPoint] = []

    private let lineWidth: CGFloat = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            Canvas { context, _ in
                for stroke in strokes {
                    context.stroke(Self.path(stroke.points),
                                   with: .color(Color(hex: stroke.colorHex)),
                                   style: StrokeStyle(lineWidth: stroke.lineWidth,
                                                      lineCap: .round, lineJoin: .round))
                }
                if !currentPoints.isEmpty {
                    context.stroke(Self.path(currentPoints),
                                   with: .color(Color(hex: penColorHex)),
                                   style: StrokeStyle(lineWidth: lineWidth,
                                                      lineCap: .round, lineJoin: .round))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { currentPoints.append($0.location) }
                    .onEnded { _ in
                        guard var pts = currentPoints.isEmpty ? nil : currentPoints else { return }
                        // 탭 한 번(점 하나)도 점으로 남도록 살짝 늘려준다
                        if pts.count == 1 {
                            pts.append(CGPoint(x: pts[0].x + 0.3, y: pts[0].y + 0.3))
                        }
                        strokes.append(DrawingStroke(colorHex: penColorHex,
                                                     lineWidth: lineWidth,
                                                     points: pts))
                        currentPoints = []
                    }
            )

            toolbar
        }
    }

    private static func path(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        path.addLines(points)
        return path
    }

    // MARK: - 하단 도구 막대 (되돌리기 / 전체 지우기)

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                if !strokes.isEmpty { strokes.removeLast() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(strokes.isEmpty ? 0.3 : 0.9))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("되돌리기")

            Button {
                strokes.removeAll()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(strokes.isEmpty ? 0.3 : 0.9))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("전체 지우기")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .padding(.bottom, 2)
    }
}
