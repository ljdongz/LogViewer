import UIKit
import LogViewer

class ViewController: UIViewController {
    private let logger = AppLogger(category: "UI")
    private let networkLogger = AppLogger(category: "Network")
    private var counter = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Example"
        view.backgroundColor = .systemBackground
        setupUI()

        // Trigger A: 흔들기(shake)
        // ShakeWindow 가 발송하는 Notification 을 구독해 LogViewerView 표시.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShake),
            name: ShakeWindow.didShakeNotification,
            object: nil
        )

        logger.info("ViewController loaded")
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "LogViewer Demo"
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "기기를 흔들거나 아래 버튼으로 로그 뷰어를 엽니다"
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let infoButton = makeButton(title: "INFO 로그 생성", action: #selector(infoTapped))
        let warnButton = makeButton(title: "WARNING 로그 생성", action: #selector(warnTapped))
        let errorButton = makeButton(title: "ERROR 로그 생성", action: #selector(errorTapped))
        let networkButton = makeButton(title: "네트워크 로그 생성", action: #selector(networkTapped))
        let showButton = makeButton(title: "로그 뷰어 직접 열기", action: #selector(showLogViewer))

        [titleLabel, subtitleLabel, infoButton, warnButton, errorButton, networkButton, showButton]
            .forEach { stack.addArrangedSubview($0) }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func infoTapped() {
        counter += 1
        logger.info("버튼 탭 #\(counter)")
    }

    @objc private func warnTapped() {
        logger.warning("디스크 용량이 부족합니다 (남은: 120MB)")
    }

    @objc private func errorTapped() {
        logger.error("결제 실패: 카드 한도 초과")
    }

    @objc private func networkTapped() {
        networkLogger.info("GET /api/users → 200 OK (132ms)")
        networkLogger.warning("GET /api/products → 429 Too Many Requests")
        networkLogger.error("POST /api/orders → 500 Internal Server Error")
    }

    // Trigger B: 명시 버튼
    @objc private func showLogViewer() {
        presentLogViewer()
    }

    @objc private func handleShake() {
        // 이미 LogViewer 가 떠 있으면 중복 표시하지 않음
        guard presentedViewController == nil else { return }
        presentLogViewer()
    }

    private func presentLogViewer() {
        let vc = LogViewController()
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }
}
