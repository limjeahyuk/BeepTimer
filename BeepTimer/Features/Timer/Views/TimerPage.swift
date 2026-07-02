//
//  File.swift
//  BeepTimer
//
//  Created by 임재혁 on 9/14/25.
//

import SwiftUI
import RealmSwift

// MARK: - 프로그램별 TimerController 스토어 (동시 실행 지원)

final class TimerControllerStore: ObservableObject {
    private var controllers: [ObjectId: TimerController] = [:]

    /// 다른 페이지에 있는 동안 끝난(울린) 타이머들
    @Published var rangIds: Set<ObjectId> = []
    @Published var lastRangTitle: String?

    /// 현재 화면에 보이는 프로그램 id — 보고 있는 타이머가 울린 건 배지 처리하지 않는다
    var visibleId: ObjectId?

    func controller(for program: RTimerProgram) -> TimerController {
        let id = program._id
        if let c = controllers[id] { return c }

        let c = TimerController()
        apply(program.toModel(), to: c)
        let notify: () -> Void = { [weak self, weak c] in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.visibleId != id {
                    self.rangIds.insert(id)
                    self.lastRangTitle = c?.timerTitle
                }
            }
        }
        c.onEnded = notify                      // 전체 완료
        c.onPhaseEnded = { _ in notify() }      // Time/Rest 페이즈 종료
        controllers[id] = c
        return c
    }

    func existingController(id: ObjectId?) -> TimerController? {
        guard let id else { return nil }
        return controllers[id]
    }

    var allControllers: [TimerController] { Array(controllers.values) }

    /// 페이지에 도착: 울림 배지 해제 + 현재 페이지로 기록
    func markSeen(_ id: ObjectId) {
        visibleId = id
        rangIds.remove(id)
        if rangIds.isEmpty { lastRangTitle = nil }
    }

    /// 라이브러리에서 편집된 값을 idle 컨트롤러에 반영
    func syncFromRealm(_ program: RTimerProgram) {
        guard let c = controllers[program._id], case .idle = c.state else { return }
        apply(program.toModel(), to: c, onlyIfChanged: true)
    }

    /// 삭제된 프로그램의 컨트롤러 정리 (돌고 있으면 멈춤)
    func cleanup(existing ids: Set<ObjectId>) {
        for (id, c) in controllers where !ids.contains(id) {
            c.stop()
            controllers.removeValue(forKey: id)
            rangIds.remove(id)
        }
        if rangIds.isEmpty { lastRangTitle = nil }
    }

    private func apply(_ model: TimerModel, to c: TimerController, onlyIfChanged: Bool = false) {
        // 상세(커스텀) 프로그램: 단계 배열 그대로 적용
        if model.isCustom {
            let steps = model.steps.map {
                TimerController.CustomStep(title: $0.title ?? "",
                                           isRest: $0.kind == .rest,
                                           seconds: TimeInterval(max(1, $0.seconds)))
            }
            if onlyIfChanged, c.timerTitle == model.title, c.customSteps == steps { return }
            c.configureCustom(title: model.title, steps: steps)
            return
        }

        let time: Int
        let rest: Int
        if let trs = model.asTimeRestSets() {
            time = trs.time; rest = trs.rest
        } else {
            time = model.steps.first { $0.kind == .time }?.seconds ?? 30
            rest = model.steps.first { $0.kind == .rest }?.seconds ?? 0
        }
        let sets = max(1, model.setsCount)

        if onlyIfChanged,
           c.timerTitle == model.title, !c.isCustomMode,
           Int(c.timeSec) == time, Int(c.restSec) == rest, c.totalSets == sets {
            return
        }
        c.configure(title: model.title, time: max(1, time), rest: max(0, rest), sets: sets)
    }
}

// MARK: - 페이저

struct TimerPager: View {
    @StateObject private var store = TimerControllerStore()
    @Environment(\.scenePhase) var scenePhase

    @ObservedResults(RTimerProgram.self,
                     sortDescriptor: SortDescriptor(keyPath: "createdAt", ascending: true))
    var programs

    @State private var page = 0
    @State private var showLibrary = false

    var body: some View {
        ZStack {
            if programs.isEmpty {
                // 저장된 타이머가 없으면 기본 타이머 한 페이지
                ContentView()
                    .environmentObject(TimerController.shared)
                    .onTapGesture { hideKeyboard() }
            } else {
                TabView(selection: $page) {
                    ForEach(Array(programs.enumerated()), id: \.element._id) { idx, p in
                        ContentView()
                            .environmentObject(store.controller(for: p))
                            .tag(idx)
                            .onTapGesture { hideKeyboard() }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // 상단 바: 리스트 / 페이지 인디케이터 / +
            VStack(spacing: 6) {
                HStack {
                    Button {
                        hideKeyboard()
                        showLibrary = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("타이머 관리")

                    Spacer()

                    PageDots(count: programs.count,
                             current: page,
                             alert: rangIndices)

                    Spacer()

                    Button {
                        addTimer()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("새 타이머 추가")
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                // 다른 페이지의 타이머가 울렸을 때 알림
                if let rangTitle = store.lastRangTitle {
                    Text("\"\(rangTitle)\" 타이머가 울렸어요!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.red.opacity(0.15)))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: store.lastRangTitle)
        }
        .background(Color(hex: "#1A1E24").ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showLibrary) {
            NavigationStack {
                TimerLibraryView(
                    onPick: { _ in
                        if let activeId = ActiveProgramStore.activeId(),
                           let idx = programs.firstIndex(where: { $0._id == activeId }) {
                            page = idx
                            arrived(at: idx)
                        }
                        showLibrary = false
                    }
                )
            }
        }
        .onAppear {
            if programs.isEmpty {
                let c = TimerController.shared
                if let last = c.loadLastUsed() {
                    c.configure(title: last.title,
                                time: max(1, last.time),
                                rest: max(0, last.rest),
                                sets: max(1, last.sets))
                } else {
                    c.configure(title: "Beep Timer", time: 30, rest: 10, sets: 3)
                }
            } else if let activeId = ActiveProgramStore.activeId(),
                      let idx = programs.firstIndex(where: { $0._id == activeId }) {
                page = idx
                arrived(at: idx)
            } else {
                page = 0
                arrived(at: 0)
            }
        }
        .onChange(of: page) { newValue in
            logger.d("페이지 변경 \(newValue)")
            hideKeyboard()
            arrived(at: newValue)
        }
        .onChange(of: programs.count) { _ in
            store.cleanup(existing: Set(programs.map(\._id)))
            if page >= programs.count { page = max(0, programs.count - 1) }
        }
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .background:
                // 백그라운드로 갈 때: 모든 실행 중 타이머의 Live Activity 동기화 + 페이즈 알림 예약
                logger.d("background scene phase")
                for c in store.allControllers {
                    c.isInBackground = true
                    c.scheduleBackgroundNotifications()
                    Task { await c.syncLiveActivityForCurrentState() }
                }
            case .active:
                // 복귀: 예약 알림 취소 + 백그라운드에서 흘러간 만큼 상태 보정
                logger.d("active ground scene ")
                for c in store.allControllers {
                    c.isInBackground = false
                    Task { await c.handleReturnToForeground() }
                }
            default:
                break
            }
        }
        .onOpenURL { url in
            // Live Activity / Dynamic Island 버튼 딥링크 처리
            // beeptimer://toggle , beeptimer://next
            guard url.scheme == "beeptimer" else { return }
            let action = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            logger.d("onOpenURL action=\(action)")
            let controller = currentController
            switch action {
            case "toggle":
                controller.toggle()
            case "next":
                _ = controller.nextSet()
            case "start":
                // 홈 위젯에서 진입: idle이면 바로 시작
                if case .idle = controller.state { controller.start() }
            case "open":
                break   // 앱만 열기
            default:
                break
            }
        }
    }

    // MARK: - 현재 페이지

    private var currentController: TimerController {
        guard page >= 0, page < programs.count else { return TimerController.shared }
        return store.controller(for: programs[page])
    }

    private var rangIndices: Set<Int> {
        Set(programs.enumerated()
            .filter { store.rangIds.contains($0.element._id) }
            .map(\.offset))
    }

    /// 페이지 도착 처리: 활성 기록 + 울림 배지 해제 + 라이브러리 편집분 동기화
    private func arrived(at index: Int) {
        guard index >= 0, index < programs.count else { return }
        let p = programs[index]
        ActiveProgramStore.setActive(p)
        store.markSeen(p._id)
        store.syncFromRealm(p)
    }

    // MARK: - 타이머 추가 (+ 버튼)

    /// 현재 목록에서 "TimerN"의 최댓값을 찾아 "Timer\(N+1)" 반환
    private func nextDefaultTitle() -> String {
        let pattern = #"^\s*Timer\s*(\d+)\s*$"#
        let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        var maxN = 0
        for t in programs.map(\.title) {
            guard let re, let m = re.firstMatch(in: t, options: [], range: NSRange(location: 0, length: (t as NSString).length)),
                  m.numberOfRanges >= 2 else { continue }
            let numRange = m.range(at: 1)
            if numRange.location != NSNotFound {
                let n = Int((t as NSString).substring(with: numRange)) ?? 0
                maxN = max(maxN, n)
            }
        }
        return "Timer\(maxN + 1)"
    }

    private func addTimer() {
        hideKeyboard()
        let obj = RTimerProgram()
        obj.title = nextDefaultTitle()
        obj.createdAt = Date()

        let steps = RealmSwift.List<RStep>()
        let t = RStep(); t.kindRaw = "time"; t.seconds = 30
        let r = RStep(); r.kindRaw = "rest"; r.seconds = 15
        steps.append(objectsIn: [t, r])
        obj.steps = steps

        $programs.append(obj)

        // 새 타이머 페이지로 이동 (createdAt 오름차순 → 마지막 페이지)
        DispatchQueue.main.async {
            withAnimation {
                page = programs.count - 1
            }
        }
    }
}

/// 상단 페이지 인디케이터: 현재 페이지는 크게, 울린 타이머는 빨간 점으로 표시
private struct PageDots: View {
    let count: Int
    let current: Int
    var alert: Set<Int> = []

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Circle()
                    .fill(alert.contains(i)
                          ? Color.red
                          : Color.white.opacity(i == current ? 0.9 : 0.3))
                    .frame(width: i == current || alert.contains(i) ? 8 : 6,
                           height: i == current || alert.contains(i) ? 8 : 6)
                    .animation(.easeInOut(duration: 0.15), value: current)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .opacity(count > 1 ? 1 : 0)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
