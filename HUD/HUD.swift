//
//  HUD.swift
//  HUD
//
//  Created by Philip Kluz on 6/13/14.
//  Copyright (c) 2016 NSExceptional. All rights reserved.
//  Licensed under the MIT license.
//

import UIKit

/// The HUD object controls showing and hiding of the HUD, as well as its contents and touch response behavior.
open class HUD: NSObject {
    fileprivate struct Constants {
        static let sharedHUD = HUD()
    }

    public var viewToPresentOn: UIView?

    fileprivate let container = ContainerView()
    fileprivate var hideTimer: Timer?

    public typealias TimerAction = (Bool) -> Void
    fileprivate var timerActions = [String: TimerAction]()

    /// Grace period is the time (in seconds) that the invoked method may be run without
    /// showing the HUD. If the task finishes before the grace time runs out, the HUD will
    /// not be shown at all.
    /// This may be used to prevent HUD display for very short tasks.
    /// Defaults to 0 (no grace time).
    public var gracePeriod: TimeInterval = 0
    fileprivate var graceTimer: Timer?

    // MARK: Public

    open class var shared: HUD {
        return Constants.sharedHUD
    }

    override public init() {
        super.init()

        #if swift(>=4.2)
        let notificationName = UIApplication.willEnterForegroundNotification
        #else
        let notificationName = NSNotification.Name.UIApplicationWillEnterForeground
        #endif

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(HUD.willEnterForeground(_:)),
                                               name: notificationName,
                                               object: nil)
        userInteractionOnUnderlyingViewsEnabled = false
        container.frameView.autoresizingMask = [.flexibleLeftMargin,
                                                .flexibleRightMargin,
                                                .flexibleTopMargin,
                                                .flexibleBottomMargin]

        container.isAccessibilityElement = true
        container.accessibilityIdentifier = "HUD"
    }

    public convenience init(viewToPresentOn view: UIView) {
        self.init()
        viewToPresentOn = view
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    open var dimsBackground = true
    open var userInteractionOnUnderlyingViewsEnabled: Bool {
        get {
            return !container.isUserInteractionEnabled
        }
        set {
            container.isUserInteractionEnabled = !newValue
        }
    }

    open var isVisible: Bool {
        return !container.isHidden
    }

    open var contentView: UIView {
        get {
            return container.frameView.content
        }
        set {
            container.frameView.content = newValue
            startAnimatingContentView()
        }
    }

    open var effect: UIVisualEffect? {
        get {
            return container.frameView.effect
        }
        set {
            container.frameView.effect = newValue
        }
    }

    open var leadingMargin: CGFloat = 0

    open var trailingMargin: CGFloat = 0

    open func show(onView view: UIView? = nil) {
        let view: UIView = view ?? viewToPresentOn ?? UIApplication.shared.keyWindow!
        if !view.subviews.contains(container) {
            view.addSubview(container)
            container.frame.origin = CGPoint.zero
            container.frame.size = view.frame.size
            container.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            container.isHidden = true
        }
        if dimsBackground {
            container.showBackground(animated: true)
        }

        // If the grace time is set, postpone the HUD display
        if gracePeriod > 0.0 {
            let timer = Timer(timeInterval: gracePeriod, target: self, selector: #selector(HUD.handleGraceTimer(_:)), userInfo: nil, repeats: false)
            #if swift(>=4.2)
            RunLoop.current.add(timer, forMode: .common)
            #else
            RunLoop.current.add(timer, forMode: .commonModes)
            #endif
            graceTimer = timer
        } else {
            showContent()
        }
    }

    func showContent() {
        graceTimer?.invalidate()
        container.showFrameView()
        startAnimatingContentView()
    }

    open func hide(animated anim: Bool = true, completion: TimerAction? = nil) {
        graceTimer?.invalidate()

        container.hideFrameView(animated: anim, completion: completion)
        stopAnimatingContentView()
    }

    open func hide(_ animated: Bool, completion: TimerAction? = nil) {
        hide(animated: animated, completion: completion)
    }

    open func hide(afterDelay delay: TimeInterval, completion: TimerAction? = nil) {
        let key = UUID().uuidString
        let userInfo = ["timerActionKey": key]
        if let completion = completion {
            timerActions[key] = completion
        }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(timeInterval: delay,
                                         target: self,
                                         selector: #selector(HUD.performDelayedHide(_:)),
                                         userInfo: userInfo,
                                         repeats: false)
    }

    // MARK: Internal

    @objc internal func willEnterForeground(_ notification: Notification?) {
        startAnimatingContentView()
    }

    internal func startAnimatingContentView() {
        if let animatingContentView = contentView as? HUDAnimating, isVisible {
            animatingContentView.startAnimation()
        }
    }

    internal func stopAnimatingContentView() {
        if let animatingContentView = contentView as? HUDAnimating {
            animatingContentView.stopAnimation?()
        }
    }

    internal func registerForKeyboardNotifications() {
        container.registerForKeyboardNotifications()
    }

    internal func deregisterFromKeyboardNotifications() {
        container.deregisterFromKeyboardNotifications()
    }

    // MARK: Timer callbacks

    @objc internal func performDelayedHide(_ timer: Timer? = nil) {
        let userInfo = timer?.userInfo as? [String: AnyObject]
        let key = userInfo?["timerActionKey"] as? String
        var completion: TimerAction?

        if let key = key, let action = timerActions[key] {
            completion = action
            timerActions[key] = nil
        }

        hide(animated: true, completion: completion)
    }

    @objc internal func handleGraceTimer(_ timer: Timer? = nil) {
        // Show the HUD only if the task is still running
        if (graceTimer?.isValid)! {
            showContent()
        }
    }
}
