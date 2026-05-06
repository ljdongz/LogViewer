import SwiftUI
import LogViewer

// 이 예제는 "버튼 트리거" 패턴만 시연합니다.
// 흔들기(shake) 트리거는 커스텀 UIWindow 서브클래스가 필요하므로
// Examples/UIKitExample (ShakeWindow) 의 패턴을 참고하세요.
struct ContentView: View {
    private let logger = AppLogger(category: "UI")
    private let networkLogger = AppLogger(category: "Network")
    @State private var counter = 0
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("LogViewer Demo")
                    .font(.title)

                Text("아래 '로그 보기' 버튼을 눌러 로그 뷰어를 엽니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Button("INFO 로그 생성") {
                    counter += 1
                    logger.info("버튼 탭 #\(counter)")
                }

                Button("WARNING 로그 생성") {
                    logger.warning("디스크 용량이 부족합니다 (남은: 120MB)")
                }

                Button("ERROR 로그 생성") {
                    logger.error("결제 실패: 카드 한도 초과")
                }

                Button("네트워크 로그 생성") {
                    networkLogger.info("GET /api/users → 200 OK (132ms)")
                    networkLogger.warning("GET /api/products → 429 Too Many Requests")
                    networkLogger.error("POST /api/orders → 500 Internal Server Error")
                }

                Divider()

                // Trigger: 명시 버튼으로 LogViewerView 시트 표시
                Button("로그 보기") {
                    showLog = true
                }
            }
            .padding()
            .navigationTitle("SwiftUI Example")
            .sheet(isPresented: $showLog) {
                LogViewerView()
            }
        }
    }
}
