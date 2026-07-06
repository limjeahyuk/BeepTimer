//
//  SudokuView.swift
//  BeepTimer
//
//  커스텀 영역 스도쿠 화면 — 9×9 판 + 숫자 패드. 타이머 정사각 영역 위에 겹친다.
//

import SwiftUI

struct SudokuView: View {
    @StateObject private var game: SudokuGame

    init(memoKey: String) {
        _game = StateObject(wrappedValue: SudokuGame(memoKey: memoKey))
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            board
            numberPad
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#161B22"))
    }

    // MARK: - 상단 (제목 / 난이도 / 새 게임)

    private var header: some View {
        HStack(spacing: 8) {
            if game.state.isSolved {
                Text("완성! 🎉")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#34D399"))
            } else {
                Text("스도쿠")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Menu {
                ForEach(SudokuDifficulty.allCases, id: \.self) { d in
                    Button {
                        game.newGame(d)
                    } label: {
                        Label(d.label, systemImage: game.state.difficulty == d ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(game.state.difficulty.label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }

            Button {
                game.newGame(game.state.difficulty)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("새 게임")
        }
    }

    // MARK: - 9×9 판

    private var board: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                // 칸 배경 + 숫자
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { c in
                                cell(r * 9 + c, size: side / 9)
                            }
                        }
                    }
                }
                // 얇은 칸 선
                SudokuGridLines(step: 1)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                // 3×3 굵은 박스 선
                SudokuGridLines(step: 3)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.6)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay {
                if game.isGenerating {
                    // 생성이 끝날 때까지 판을 가려 빈 칸에 입력하는 것을 막는다
                    ZStack {
                        Color(hex: "#161B22").opacity(0.85)
                        ProgressView()
                            .tint(.white)
                    }
                    .frame(width: side, height: side)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cell(_ i: Int, size: CGFloat) -> some View {
        let value = game.state.current[i]
        let isGiven = game.state.given[i] != 0
        let isSelected = game.selected == i
        let conflict = value != 0 && game.state.isConflict(at: i)
        // 선택한 칸과 같은 줄/칸/박스면 은은하게 강조
        let peer = isPeer(of: game.selected, i)
        // 선택한 칸과 같은 숫자면 강조
        let sameValue = value != 0 && game.selected != nil && game.state.current[game.selected!] == value

        return Rectangle()
            .fill(
                isSelected ? Color(hex: "#2563EB").opacity(0.55)
                : sameValue ? Color(hex: "#2563EB").opacity(0.22)
                : peer ? Color.white.opacity(0.06)
                : Color.clear
            )
            .frame(width: size, height: size)
            .overlay(
                Text(value == 0 ? "" : "\(value)")
                    .font(.system(size: size * 0.5, weight: isGiven ? .bold : .medium))
                    .foregroundStyle(
                        conflict ? Color(hex: "#F87171")
                        : isGiven ? .white
                        : Color(hex: "#7DD3FC")
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture { game.select(i) }
    }

    /// a칸과 b칸이 같은 줄/칸/3×3 박스에 있는지
    private func isPeer(of a: Int?, _ b: Int) -> Bool {
        guard let a, a != b else { return false }
        let (ar, ac) = (a / 9, a % 9)
        let (br, bc) = (b / 9, b % 9)
        if ar == br || ac == bc { return true }
        return (ar / 3 == br / 3) && (ac / 3 == bc / 3)
    }

    // MARK: - 숫자 패드

    private var numberPad: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(1...9, id: \.self) { n in
                    Button {
                        game.enter(n)
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.white.opacity(0.1),
                                       in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(game.selected == nil)
                    .opacity(game.selected == nil ? 0.45 : 1)
                }
            }

            Button {
                game.erase()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eraser")
                    Text("지우기")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color.white.opacity(0.08),
                           in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(game.selected == nil)
            .opacity(game.selected == nil ? 0.45 : 1)
        }
    }
}

// MARK: - 격자 선 (step 1 = 모든 칸, step 3 = 3×3 박스)

private struct SudokuGridLines: Shape {
    let step: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cell = rect.width / 9
        for i in stride(from: 0, through: 9, by: step) {
            let x = cell * CGFloat(i)
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
            let y = cell * CGFloat(i)
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return p
    }
}
