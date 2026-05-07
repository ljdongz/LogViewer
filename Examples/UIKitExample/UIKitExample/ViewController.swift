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

        // Trigger A: shake gesture.
        // Subscribe to the Notification posted by ShakeWindow to present LogViewerView.
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
        subtitleLabel.text = "Shake the device or tap the button below to open the log viewer."
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let infoButton = makeButton(title: "Generate INFO log", action: #selector(infoTapped))
        let warnButton = makeButton(title: "Generate WARNING log", action: #selector(warnTapped))
        let errorButton = makeButton(title: "Generate ERROR log", action: #selector(errorTapped))
        let networkButton = makeButton(title: "Generate Network logs", action: #selector(networkTapped))
        let showButton = makeButton(title: "Show Logs", action: #selector(showLogViewer))

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
        logger.info("Button tap #\(counter)")
    }

    @objc private func warnTapped() {
        logger.warning("Low disk space (remaining: 120MB)")
    }

    @objc private func errorTapped() {
        logger.error("Payment failed: card limit exceeded")
    }

    @objc private func networkTapped() {
        networkLogger.info("GET /api/users → 200 OK (132ms)")
        networkLogger.warning("GET /api/products → 429 Too Many Requests")
        networkLogger.error("POST /api/orders → 500 Internal Server Error")
    }

    // Trigger B: explicit button.
    @objc private func showLogViewer() {
        presentLogViewer()
    }

    @objc private func handleShake() {
        // Don't double-present if LogViewer is already on screen.
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
