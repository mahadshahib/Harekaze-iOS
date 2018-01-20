/**
 *
 * VideoPlayerViewController.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2016/07/14.
 * 
 * Copyright (c) 2016-2018, Yuki MIZUNO
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 * 
 * 3. Neither the name of the copyright holder nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit
import MediaPlayer
import Crashlytics
import RealmSwift
import Hero
import FileKit
import SwiftyUserDefaults
import APIKit

class VideoPlayerViewController: UIViewController, VLCMediaPlayerDelegate {

	private lazy var __once: () = { // swiftlint:disable:this variable_name
		// Resume from last played position
		if Defaults[.resumeFromLastPlayedDownloaded] && self.download != nil {
			self.mediaPlayer.position = self.download.lastPlayedPosition
		}

		let notification = Notification(name: NSNotification.Name.UIScreenDidConnect, object: nil)
		self.screenDidConnect(notification)
	}()

	// MARK: - Private instance fileds

	private var mediaPlayer: VLCMediaPlayer! = VLCMediaPlayer()

	private var externalWindow: UIWindow! = nil
	private var savedViewConstraints: [NSLayoutConstraint] = []
	private var seekTimeTimer: Foundation.Timer!
	private var swipeGestureMode: String = "none"
	private var seekTimeUpdter: (VLCMediaPlayer) -> (String, Float) = { _ in ("", 0) }
	private var offlineMedia: Bool = false
	private let playSpeed: [Float] = [0.3, 0.5, 0.8, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0]
	private var currentPlaySpeedIndex: Int = 3

	// MARK: - Instance fileds

	var program: Program!
	var download: Download!

	// MARK: - Interface Builder outlets

	@IBOutlet var mainVideoView: UIView!
	@IBOutlet weak var mediaToolNavigationBar: UINavigationBar!
	@IBOutlet weak var mediaControlView: UIView!
	@IBOutlet weak var videoProgressSlider: UISlider!
	@IBOutlet weak var videoTimeLabel: UILabel!
	@IBOutlet weak var volumeSliderPlaceView: MPVolumeView!
	@IBOutlet weak var playPauseButton: UIButton!
	@IBOutlet weak var backwardButton: UIButton!
	@IBOutlet weak var forwardButton: UIButton!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var seekTimeLabel: UILabel!

	// MARK: - Interface Builder actions

	@IBAction func closeButtonTapped(_ sender: UIButton) {
		mediaPlayer.delegate = nil
		mediaPlayer.stop()

		self.dismiss(animated: true, completion: nil)
	}

	@IBAction func playPauseButtonTapped(_ sender: UIButton) {
		if mediaPlayer.isPlaying {
			mediaPlayer.pause()
			sender.setImage(#imageLiteral(resourceName: "play"), for: UIControlState())
		} else {
			mediaPlayer.play()
			sender.setImage(#imageLiteral(resourceName: "pause"), for: UIControlState())
		}
	}

	@IBAction func backwardButtonTapped() {
		changePlaybackPositionRelative(-30)
	}

	@IBAction func forwardButtonTapped() {
		changePlaybackPositionRelative(30)
	}

	@IBAction func videoProgressSliderValueChanged(_ sender: UISlider) {
		let time = Int(TimeInterval(sender.value) * program.duration)
		videoTimeLabel.text = NSString(format: "%02d:%02d", time / 60, time % 60) as String
	}

	@IBAction func videoProgressSliderTouchUpInside(_ sender: UISlider) {
		mediaPlayer.position = sender.value
	}

	// MARK: - View initialization

	override func viewDidLoad() {
		// Setup player view transition
		self.isHeroEnabled = true
		playPauseButton.heroID = "playButton"
		playPauseButton.heroModifiers = [.arc]
		self.heroModalAnimationType = .selectBy(presenting:.zoom, dismissing:.zoomOut)

		// Media player settings
		do {
			// Path for local media
			let localMediaPath = Path.userDownloads + "\(program.id).m2ts"

			// Find downloaded program from realm
			let predicate = NSPredicate(format: "id == %@", program.id)
			let config = Realm.configuration(class: Download.self)
			let realm = try Realm(configuration: config)

			let url: URL
			self.download = realm.objects(Download.self).filter(predicate).first
			if self.download != nil && localMediaPath.exists {
				url = localMediaPath.url
				seekTimeUpdter = getTimeFromMediaTime
			} else {
				let request = ChinachuAPI.StreamingMediaRequest(id: program.id)
				let urlRequest = try request.buildURLRequest()

				var components = URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false)
				components?.user = ChinachuAPI.Config[.username]
				components?.password = ChinachuAPI.password

				url = components!.url!
				seekTimeUpdter = getTimeFromMediaPosition
			}

			let media = VLCMedia(url: url)
			media.addOptions(["network-caching": 3333])
			mediaPlayer.videoAspectRatio = UnsafeMutablePointer<Int8>(mutating: NSString(string: "16:9").utf8String)
			mediaPlayer.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: NSString(string: "16:9").utf8String)
			mediaPlayer.drawable = self.mainVideoView
			mediaPlayer.media = media
			mediaPlayer.setDeinterlaceFilter("blend")
			mediaPlayer.delegate = self
			mediaPlayer.play()
		} catch let error as NSError {
			Answers.logCustomEvent(withName: "Video playback error", customAttributes: ["error": error, "file": #file, "function": #function, "line": #line])
		}

		titleLabel.text = program.fullTitle

		// Generate slider thumb image
		let circle = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 8, height: 8), cornerRadius: 4)
		UIGraphicsBeginImageContextWithOptions(circle.bounds.size, false, 0)
		UIColor(red: 216/255, green: 27/255, blue: 96/255, alpha: 1).setFill()
		circle.fill()
		let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

		// Generate slider track image
		let rect = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1, height: 2))
		UIGraphicsBeginImageContextWithOptions(rect.bounds.size, false, 0)
		UIColor.white.setFill()
		rect.fill()
		let trackImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

		// Set swipe gesture mode
		swipeGestureMode = Defaults[.oneFingerHorizontalSwipeMode]

		// Set slider thumb/track image
		videoProgressSlider.setThumbImage(thumbImage, for: UIControlState())
		videoProgressSlider.setMinimumTrackImage(trackImage, for: .normal)
		videoProgressSlider.setMaximumTrackImage(trackImage, for: UIControlState())
		volumeSliderPlaceView.isHidden = true

		// Set navigation bar transparent background
		let emptyImage = UIImage()
		mediaToolNavigationBar.isTranslucent = true
		mediaToolNavigationBar.shadowImage = emptyImage
		mediaToolNavigationBar.backgroundColor = UIColor.clear
		mediaToolNavigationBar.setBackgroundImage(emptyImage, for: .default)
		mediaToolNavigationBar.setBackgroundImage(emptyImage, for: .compact)

		// Change volume slider z-index
		mediaToolNavigationBar.sendSubview(toBack: volumeSliderPlaceView)

		// Add long press gesture to forward/backward button
		backwardButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(seekBackward120)))
		forwardButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(seekForward3x)))

		// Add swipe gesture to view
		if swipeGestureMode != "none" {
			for direction in [.right, .left] as [UISwipeGestureRecognizerDirection] {
				for touches in 1...2 {
					let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(seekOrChangeRate))
					swipeGesture.direction = direction
					swipeGesture.numberOfTouchesRequired = touches
					self.mainVideoView.addGestureRecognizer(swipeGesture)
				}
			}
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// Set slider thumb/track image
		for subview: AnyObject in volumeSliderPlaceView.subviews {
			if NSStringFromClass(subview.classForCoder) == "MPVolumeSlider" {
				guard let volumeSlider = subview as? UISlider else {
					continue
				}
				if let thumbImage = videoProgressSlider.currentThumbImage {
					volumeSlider.setThumbImage(thumbImage, for: UIControlState())
				}
				if let trackImage = videoProgressSlider.currentMaximumTrackImage {
					volumeSlider.setMinimumTrackImage(trackImage, for: .normal)
					volumeSlider.setMaximumTrackImage(trackImage, for: UIControlState())
				}

				volumeSliderPlaceView.isHidden = false
				break
			}
		}

		// Save current constraints
		savedViewConstraints = self.view.constraints

		// Set external display events
		NotificationCenter.default.addObserver(self, selector: #selector(VideoPlayerViewController.screenDidConnect(_:)),
		                                       name: NSNotification.Name.UIScreenDidConnect, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(VideoPlayerViewController.screenDidDisconnect(_:)),
		                                       name: NSNotification.Name.UIScreenDidDisconnect, object: nil)

		// Start remote control events
		UIApplication.shared.beginReceivingRemoteControlEvents()
		self.becomeFirstResponder()
	}

	// MARK: - View deinitialization

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		// Save last played position
		if let download = self.download {
			// Find downloaded program from realm
			let config = Realm.configuration(class: Download.self)
			let realm = try! Realm(configuration: config)
			try! realm.write {
				download.lastPlayedPosition = mediaPlayer.position
			}
		}

		// Media player settings
		mediaPlayer.delegate = nil
		mediaPlayer.stop()
		mediaPlayer = nil
		MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

		// Unset external display events
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIScreenDidConnect, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIScreenDidDisconnect, object: nil)

		// End remote control events
		UIApplication.shared.endReceivingRemoteControlEvents()
		self.resignFirstResponder()
	}

	// MARK: - Device orientation configurations

	override var shouldAutorotate: Bool {
		return externalWindow == nil
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
	}

	// MARK: - First responder configuration

	override var canBecomeFirstResponder: Bool {
		return true
	}

	// MARK: - Memory/resource management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	// MARK: - Remote control

	override func remoteControlReceived(with event: UIEvent?) {
		if event!.type == .remoteControl {
			switch event!.subtype {
			case .remoteControlPlay, .remoteControlPause, .remoteControlTogglePlayPause:
				self.playPauseButtonTapped(playPauseButton)
			default:
				break
			}
		}
	}

	// MARK: - Media player control methods

	func changePlaybackPositionRelative(_ seconds: Int32) {
		if mediaPlayer.time.intValue + (seconds * 1000) < 0 || mediaPlayer.time.intValue + (seconds * 1000) > Int32(program.duration * 1000) {
			return
		}

		let step = Float(seconds) / Float(program.duration)
		let text: String

		if seconds < 0 {
			text = "\(seconds)"
			//mediaPlayer.jumpBackward(-seconds)
		} else {
			text = "+\(seconds)"
			//mediaPlayer.jumpForward(seconds)
		}
		// NOTE: Because of VLC implementation, jumpForward/jumpBackward are available only with offline media.
		//       (not available with streaming media). Instead, use alternative method.
		let pos = TimeInterval(mediaPlayer.time!.intValue) / program.duration / 1000
		mediaPlayer.position = Float(pos) + step

		seekTimeLabel.text = text
		seekTimeLabel.isHidden = false
		seekTimeTimer?.invalidate()
		seekTimeTimer = Foundation.Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(hideSeekTimerLabel), userInfo: nil, repeats: false)

		let (time, position) = seekTimeUpdter(mediaPlayer)

		videoProgressSlider.value = position
		videoTimeLabel.text = time
	}

	@objc func seekBackward120(_ gestureRecognizer: UILongPressGestureRecognizer) {
		switch gestureRecognizer.state {
		case .began:
			changePlaybackPositionRelative(-120)
		default:
			break
		}
	}

	@objc func seekForward3x(_ gestureRecognizer: UILongPressGestureRecognizer) {
		switch gestureRecognizer.state {
		case .began:
			mediaPlayer.rate = 3
			seekTimeLabel.text = "3.0x"
			seekTimeLabel.isHidden = false
		case .ended:
			mediaPlayer.rate = 1
			seekTimeLabel.text = "1.0x"
			seekTimeLabel.isHidden = false
			seekTimeTimer?.invalidate()
			seekTimeTimer = Foundation.Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(hideSeekTimerLabel), userInfo: nil, repeats: false)
		default:
			break
		}
	}

	func changePlayRate(_ direction: Int) {
		if currentPlaySpeedIndex + direction < 0 || currentPlaySpeedIndex + direction >= playSpeed.count {
			return
		}
		currentPlaySpeedIndex += direction
		let currentRate = playSpeed[currentPlaySpeedIndex]

		mediaPlayer.rate = currentRate
		seekTimeLabel.text = NSString(format: "%4.1fx", mediaPlayer.rate) as String
		seekTimeLabel.isHidden = false

		if currentRate == 1.0 {
			seekTimeTimer?.invalidate()
			seekTimeTimer = Foundation.Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(hideSeekTimerLabel), userInfo: nil, repeats: false)
		}
	}

	@objc func seekOrChangeRate(_ gestureRecognizer: UISwipeGestureRecognizer) {
		let touches = gestureRecognizer.numberOfTouches
		let direction: Int32
		if gestureRecognizer.direction == .left {
			direction = 1
		} else if gestureRecognizer.direction == .right {
			direction = -1
		} else {
			direction = 0
		}

		if swipeGestureMode == "speed" {
			switch touches {
			case 1:
				changePlayRate(Int(direction))
			case 2:
				changePlaybackPositionRelative(direction * 30)
			default:
				break
			}
		} else if swipeGestureMode == "seek" {
			switch touches {
			case 1:
				changePlaybackPositionRelative(direction * 30)
			case 2:
				changePlayRate(Int(direction))
			default:
				break
			}
		}

	}

	@objc func hideSeekTimerLabel() {
		if mediaPlayer.rate == 1 {
			self.seekTimeLabel.isHidden = true
		} else {
			seekTimeLabel.text = NSString(format: "%4.1fx", mediaPlayer.rate) as String
		}
	}

	// MARK: - Media player delegate methods

	func getTimeFromMediaTime(_ mediaPlayer: VLCMediaPlayer) -> (time: String, position: Float) {
		return (mediaPlayer.time!.stringValue!, mediaPlayer.position)
	}

	func getTimeFromMediaPosition(_ mediaPlayer: VLCMediaPlayer) -> (time: String, position: Float) {
		let timeString = String(mediaPlayer.time!.stringValue!)
		let position = TimeInterval(mediaPlayer.time!.intValue) / program.duration / 1000
		// FIXME: HELPME: Transcoding video can't show/seek correct value
		return (timeString, Float(position))
	}

	var onceToken: Int = 0
	func mediaPlayerTimeChanged(_ aNotification: Notification!) {
		// Only when slider is not under control
		if !videoProgressSlider.isTouchInside {
			guard let mediaPlayer = aNotification.object as? VLCMediaPlayer else {
				return
			}
			let (time, position) = seekTimeUpdter(mediaPlayer)
			self.videoProgressSlider.value = position
			videoTimeLabel.text = time
		}

		// First time of video playback
		_ = self.__once
	}

	func mediaPlayerStateChanged(_ aNotification: Notification!) {
		updateMetadata()
	}

	// MARK: - Media metadata settings

	func updateMetadata() {
		if MPNowPlayingInfoCenter.default().nowPlayingInfo == nil {
			MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
			let request = ChinachuAPI.PreviewImageRequest(id: program.id, position: 25)
			Session.send(request) { result in
				switch result {
				case .success(let image):
					let thumbnail = MPMediaItemArtwork(boundsSize: CGSize(width: 1280, height: 720), requestHandler: {_ in image})
					DispatchQueue.main.async {
						MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = thumbnail
					}
				case .failure:
					return
				}
			}
		}

		let time = Int(TimeInterval(mediaPlayer.position) * program.duration)
		let videoInfo = [MPMediaItemPropertyTitle: program.title,
		                 MPMediaItemPropertyMediaType: MPMediaType.tvShow.rawValue,
		                 MPMediaItemPropertyPlaybackDuration: program.duration,
		                 MPMediaItemPropertyArtist: program.channel!.name,
		                 MPNowPlayingInfoPropertyElapsedPlaybackTime: time,
		                 MPNowPlayingInfoPropertyPlaybackRate: mediaPlayer.rate
		] as [String: Any]
		MPNowPlayingInfoCenter.default().nowPlayingInfo = videoInfo
	}

	// MARK: - Touch events

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)

		for t: UITouch in touches {
			guard let v = t.view else {
				continue
			}
			if String(reflecting: type(of: v)) == "VLCOpenGLES2VideoView" {
				self.mediaControlView.isHidden = false
				self.mediaToolNavigationBar.isHidden = false
				self.statusBarHidden = false

				UIView.animate(withDuration: 0.4, animations: {
					self.setNeedsStatusBarAppearanceUpdate()
					self.mediaControlView.alpha = 1.0
					self.mediaToolNavigationBar.alpha = 1.0
				})
			} else if v.restorationIdentifier == "MediaControlView" {
				self.statusBarHidden = true

				UIView.animate(withDuration: 0.4, animations: {
					self.setNeedsStatusBarAppearanceUpdate()
					self.mediaControlView.alpha = 0.0
					self.mediaToolNavigationBar.alpha = 0.0
					}, completion: { _ in
						self.mediaControlView.isHidden = true
						self.mediaToolNavigationBar.isHidden = true
				})
			}
		}
	}

	// MARK: - Status bar

	var statusBarHidden: Bool = false
	override var prefersStatusBarHidden: Bool {
		return statusBarHidden
	}

	override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return .fade
	}

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	// MARK: - External display

	@objc func screenDidConnect(_ aNotification: Notification) {
		let screens = UIScreen.screens
		if screens.count > 1 {
			let externalScreen = screens[1]
			let screenMode = externalScreen.availableModes.reduce(externalScreen.availableModes.first!, {(result, current) in
				result.size.width > current.size.width ? result : current
			})

			// Set up external screen
			externalScreen.currentMode = screenMode
			externalScreen.overscanCompensation = .none

			// Change device orientation to portrait
			let portraitOrientation = UIInterfaceOrientation.portrait.rawValue
			UIDevice.current.setValue(portraitOrientation, forKey: "orientation")

			if self.externalWindow == nil {
				self.externalWindow = UIWindow(frame: externalScreen.bounds)
			}

			// Set up external window
			self.externalWindow.screen = externalScreen
			self.externalWindow.isHidden = false
			self.externalWindow.layer.contentsGravity = kCAGravityResizeAspect

			// Move mainVideoView to external window
			mainVideoView.removeFromSuperview()
			let externalViewController = UIViewController()
			externalViewController.view = mainVideoView
			self.externalWindow.rootViewController = externalViewController

			// Show media controls
			self.mediaControlView.isHidden = false
			self.mediaToolNavigationBar.isHidden = false

			UIView.animate(withDuration: 0.4, animations: {
				self.mediaControlView.alpha = 1.0
				self.mediaToolNavigationBar.alpha = 1.0
			})

		}
	}

	@objc func screenDidDisconnect(_ aNotification: Notification) {
		if self.externalWindow != nil {
			// Restore mainVideoView
			mainVideoView.removeFromSuperview()
			self.view.addSubview(mainVideoView)
			self.view.sendSubview(toBack: mainVideoView)

			// Restore view constraints
			self.view.removeConstraints(self.view.constraints)
			self.view.addConstraints(savedViewConstraints)

			self.externalWindow = nil
		}
	}

}
