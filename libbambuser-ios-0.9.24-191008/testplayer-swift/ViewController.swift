/*
 * libbambuser - Bambuser iOS library
 * Copyright 2016 Bambuser AB
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

import UIKit

class ViewController: UIViewController, BambuserPlayerDelegate {
	var bambuserPlayer: BambuserPlayer
	var play: UIButton
	var pause: UIButton
	var stop: UIButton
	var slider: UISlider
	var seekerTimer: Timer
	var currentViewersLabel: UILabel
	var latencyLabel: UILabel
	var latencyTimer: Timer

	required init?(coder aDecoder: NSCoder) {
		bambuserPlayer = BambuserPlayer()
		play = UIButton(type: UIButtonType.system)
		pause = UIButton(type: UIButtonType.system)
		stop = UIButton(type: UIButtonType.system)
		slider = UISlider()
		seekerTimer = Timer()
		currentViewersLabel = UILabel()
		latencyLabel = UILabel()
		latencyTimer = Timer()
		super.init(coder: aDecoder)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		bambuserPlayer.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
		bambuserPlayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		bambuserPlayer.delegate = self
		bambuserPlayer.applicationId = "CHANGEME"
		// This is a sample video; you can get a similarly signed resource URI for your broadcasts via the
		// Bambuser Metadata API.
		bambuserPlayer.playVideo("https://cdn.bambuser.net/broadcasts/ec968ec1-2fd9-f8f3-4f0a-d8e19dccd739?da_signature_method=HMAC-SHA256&da_id=432cebc3-4fde-5cbb-e82f-88b013140ebe&da_timestamp=1456740399&da_static=1&da_ttl=0&da_signature=8e0f9b98397c53e58f9d06d362e1de3cb6b69494e5d0e441307dfc9f854a2479")
		self.view.addSubview(bambuserPlayer)

		let statusBarOffset = UIApplication.shared.statusBarFrame.height;
		play.frame = CGRect(x: 10, y: statusBarOffset, width: 100, height: 50)
		play.setTitle("Play", for: UIControlState())
		play.addTarget(bambuserPlayer, action: #selector(BambuserPlayer.playVideo as (BambuserPlayer) -> () -> Void), for: UIControlEvents.touchUpInside)
		play.isEnabled = false
		self.view.addSubview(play)

		pause.frame = CGRect(x: 10, y: 50 + statusBarOffset, width: 100, height: 50)
		pause.setTitle("Pause", for: UIControlState())
		pause.addTarget(bambuserPlayer, action: #selector(BambuserPlayer.pauseVideo), for: UIControlEvents.touchUpInside)
		pause.isEnabled = false
		self.view.addSubview(pause)

		stop.frame = CGRect(x: 10, y: 100 + statusBarOffset, width: 100, height: 50)
		stop.setTitle("Stop", for: UIControlState())
		stop.addTarget(bambuserPlayer, action: #selector(BambuserPlayer.stopVideo), for: UIControlEvents.touchUpInside)
		stop.isEnabled = false
		self.view.addSubview(stop)

		slider.frame = CGRect(x: 10, y: 200, width: self.view.frame.size.width, height: 10)
		slider.addTarget(self, action: #selector(ViewController.seekTo(_:)), for: UIControlEvents.touchUpInside)
		slider.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		slider.isEnabled = false
		slider.isHidden = true
		self.view.addSubview(slider)

		currentViewersLabel.textAlignment = NSTextAlignment.left
		currentViewersLabel.text = ""
		currentViewersLabel.font = UIFont.systemFont(ofSize: 16)
		currentViewersLabel.backgroundColor = UIColor.clear
		currentViewersLabel.textColor = UIColor.blue
		self.view.addSubview(currentViewersLabel)

		latencyLabel.textAlignment = NSTextAlignment.left
		latencyLabel.text = ""
		latencyLabel.font = UIFont.systemFont(ofSize: 16)
		latencyLabel.backgroundColor = UIColor.clear
		latencyLabel.textColor = UIColor.blue
		self.view.addSubview(latencyLabel)
	}

	override func viewWillLayoutSubviews() {
		currentViewersLabel.frame = CGRect(x: self.view.bounds.size.width - 100, y: self.view.bounds.size.height - 30, width: 100, height: 30)
		latencyLabel.frame = CGRect(x: 15, y: self.view.bounds.size.height - 30, width: 150, height: 30)
	}

	func durationKnown(_ duration: Double) {
		NSLog("Got duration: %f", duration)
		slider.minimumValue = 0
		slider.maximumValue = Float(duration)
		if (!bambuserPlayer.live) {
			slider.isEnabled = true
			slider.isHidden = false
		}
	}

	@objc func seekTo(_ sender: AnyObject) {
		let time = Double(slider.value)
		NSLog("Seeking to %f", time)
		bambuserPlayer.seek(to: time)
	}

	@objc func updateSlider() {
		if (!slider.isTracking) {
			slider.value = Float(bambuserPlayer.playbackPosition)
		}
	}

	@objc func updateLatency() {
		let latency = bambuserPlayer.endToEndLatency
		if (latency.uncertainty >= 0) {
			latencyLabel.text = String(format: "Latency: %.2f s", latency.latency)
		} else {
			latencyLabel.text = ""
		}
	}

	func videoLoadFail() {
		NSLog("videoLoadFail called")
	}

	func playbackStatusChanged(_ status: BambuserPlayerState) {
		switch status {
		case kBambuserPlayerStatePlaying:
			NSLog("status: kBambuserPlayerStatePlaying")
			stop.isEnabled = true
			if (!bambuserPlayer.live) {
				pause.isEnabled = true
			}
			play.isEnabled = false
			seekerTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.updateSlider), userInfo: nil, repeats: true)
			latencyTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.updateLatency), userInfo: nil, repeats: true)
			break
		case kBambuserPlayerStatePaused:
			NSLog("status: kBambuserPlayerStatePaused")
			seekerTimer.invalidate()
			latencyTimer.invalidate()
			pause.isEnabled = false
			play.isEnabled = true
			currentViewersLabel.text = ""
			latencyLabel.text = ""
			break
		case kBambuserPlayerStateStopped:
			NSLog("status: kBambuserPlayerStateStopped")
			seekerTimer.invalidate()
			latencyTimer.invalidate()
			stop.isEnabled = false
			pause.isEnabled = false
			play.isEnabled = false
			currentViewersLabel.text = ""
			latencyLabel.text = ""
			break
		default:
			break
		}
	}

	func currentViewerCountUpdated(_ viewers: Int32) {
		currentViewersLabel.text = "Viewers: \(viewers)"
	}

	func totalViewerCountUpdated(_ viewers: Int32) {
		print("Total viewers: \(viewers)")
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}

