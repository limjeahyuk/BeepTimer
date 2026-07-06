//
//  CustomAreaWebView.swift
//  BeepTimer
//
//  커스텀 영역 웹뷰 — 저장된 시작 URL(기본 Google)을 타이머 위에 띄운다
//

import SwiftUI
import WebKit

struct CustomAreaWebView: View {
    let initialURL: URL

    @State private var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        return WKWebView(frame: .zero, configuration: config)
    }()

    /// 설정에 저장된 문자열 → 열 수 있는 URL (스킴 없으면 https 붙이고, 실패하면 Google)
    static func makeURL(from raw: String) -> URL {
        let google = URL(string: "https://www.google.com")!
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return google }
        let withScheme = (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
            ? trimmed
            : "https://" + trimmed
        // 한글 등 URL에 못 쓰는 문자는 퍼센트 인코딩
        let encoded = withScheme.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? withScheme
        return URL(string: encoded) ?? google
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            WebViewContainer(webView: webView)
                .background(Color.black)

            toolbar
        }
        .onAppear {
            if webView.url == nil {
                webView.load(URLRequest(url: initialURL))
            }
        }
    }

    // MARK: - 하단 도구 막대 (뒤로 / 앞으로 / 새로고침) — 그림 메모 툴바와 같은 스타일

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                webView.goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Button {
                webView.goForward()
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("앞으로")

            Button {
                webView.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("새로고침")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .padding(.bottom, 6)
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
