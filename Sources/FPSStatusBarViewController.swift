//
//  FPSStatusBarViewController.swift
//  fps-counter
//
//  Created by Markus Gasser on 04.03.16.
//  Copyright © 2016 konoma GmbH. All rights reserved.
//

import UIKit


/// A view controller to show a FPS label in the status bar.
///
class FPSStatusBarViewController: UIViewController {

    fileprivate let fpsCounter = FPSCounter()
    private let label = UILabel()


    // MARK: - Initialization

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        self.commonInit()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        self.commonInit()
    }

    private func commonInit() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(FPSStatusBarViewController.updateStatusBarFrame(_:)),
            name: UIApplication.didChangeStatusBarOrientationNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    // MARK: - View Lifecycle and Events

    override func loadView() {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let ultraSmall = UIScreen.main.bounds.size.width <= 320
        let appWindow = UIApplication.shared.keyWindow!
        let maxWindowSide = max(appWindow.frame.width, appWindow.frame.height)
        let minWindowSide = min(appWindow.frame.width, appWindow.frame.height)
        let screenRatio = maxWindowSide / minWindowSide
        let hasNotch = screenRatio > 16/9 + 0.3 // 0.3 here is delta for not all screens are pure 16/9

        self.view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))

        let font = UIFont.boldSystemFont(ofSize: {
          if isPad {
            12
          } else {
            if ultraSmall {
              8
            } else {
              10
            }
          }
        }())

        let rect = self.view.bounds.insetBy(dx: 10.0, dy: 0.0)

        self.label.frame = CGRect(x: rect.origin.x, y: rect.maxY - font.lineHeight - 1.0, width: rect.width, height: font.lineHeight)
        self.label.font = font

        self.label.textAlignment = .center
        self.label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)

        NSLayoutConstraint.activate([
          label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
          {
            if isPad {
              label.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 3)
            } else {
              if hasNotch {
                label.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0)
              } else {
                label.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 17)
              }
            }
          }()
        ])

        self.fpsCounter.delegate = self

        self.view.backgroundColor = .clear
    }

    @objc func updateStatusBarFrame(_ notification: Notification) {
        let application = notification.object as? UIApplication
        let frame = CGRect(x: 0.0, y: 0.0, width: application?.keyWindow?.bounds.width ?? 0.0, height: 20.0)

        FPSStatusBarViewController.statusBarWindow.frame = frame
    }


    // MARK: - Getting the shared status bar window

    @objc static var statusBarWindow: UIWindow = {
        let window = FPStatusBarWindow()
        window.backgroundColor = .clear
        window.windowLevel = .statusBar
        window.rootViewController = FPSStatusBarViewController()
        return window
    }()
}


// MARK: - FPSCounterDelegate

extension FPSStatusBarViewController: FPSCounterDelegate {

    @objc func fpsCounter(_ counter: FPSCounter, didUpdateFramesPerSecond fps: Int) {
        self.resignKeyWindowIfNeeded()

        let milliseconds = 1000 / max(fps, 1)
        self.label.text = "\(fps) FPS (\(milliseconds)ms)"

        switch fps {
        case 50...:
            self.label.textColor = .green
        case 30...:
            self.label.textColor = .orange
        default:
            self.label.textColor = .red
        }
    }

    private func resignKeyWindowIfNeeded() {
        // prevent the status bar window from becoming the key window and steal events
        // from the main application window
        if FPSStatusBarViewController.statusBarWindow.isKeyWindow {
            UIApplication.shared.delegate?.window??.makeKey()
        }
    }
}


public extension FPSCounter {

    // MARK: - Show FPS in the status bar

    /// Add a label in the status bar that shows the applications current FPS.
    ///
    /// - Note:
    ///   Only do this in debug builds. Apple may reject your app if it covers the status bar.
    ///
    /// - Parameters:
    ///   - application: The `UIApplication` to show the FPS for
    ///   - runloop:     The `NSRunLoop` to use when tracking FPS. Default is the main run loop
    ///   - mode:        The run loop mode to use when tracking. Default uses `RunLoop.Mode.common`
    ///
    @objc class func showInStatusBar(
        application: UIApplication = .shared,
        runloop: RunLoop = .main,
        mode: RunLoop.Mode = .common
    ) {
        let window = FPSStatusBarViewController.statusBarWindow
        window.frame = application.statusBarFrame
        window.isHidden = false

        if let controller = window.rootViewController as? FPSStatusBarViewController {
            controller.fpsCounter.startTracking(
                inRunLoop: runloop,
                mode: mode
            )
        }
    }

    /// Removes the label that shows the current FPS from the status bar.
    ///
    @objc class func hide() {
        let window = FPSStatusBarViewController.statusBarWindow

        if let controller = window.rootViewController as? FPSStatusBarViewController {
            controller.fpsCounter.stopTracking()
            window.isHidden = true
        }
    }

    /// Returns wether the FPS counter is currently visible or not.
    ///
    @objc class var isVisible: Bool {
        return !FPSStatusBarViewController.statusBarWindow.isHidden
    }
}
