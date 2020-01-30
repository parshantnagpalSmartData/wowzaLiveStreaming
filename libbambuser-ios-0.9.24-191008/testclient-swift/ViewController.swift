/*
 * libbambuser - Bambuser iOS library
 * Copyright 2015 Bambuser AB
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
import MobileCoreServices
import Photos

class ViewController: UIViewController, BambuserViewDelegate, FileUploaderDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIGestureRecognizerDelegate {
	var bambuserView: BambuserView
	var broadcastButton: UIButton
	var swapButton: UIButton
	var uploadButton: UIButton
	var endTalkbackButton: UIButton
	var talkbackStatus: UILabel
	var currentViewersLabel: UILabel
	var pinchRecognizer: UIPinchGestureRecognizer
	var initialZoom: Float
	var popover: UIPopoverController?
	var fileUploader: FileUploader?
	var uploadAlertController: UIAlertController?
	var progressBar: UIProgressView?

	required init?(coder aDecoder: NSCoder) {
		bambuserView = BambuserView(preparePreset: kSessionPresetAuto)
		broadcastButton = UIButton(type: UIButtonType.system)
		swapButton = UIButton(type: UIButtonType.system)
		uploadButton = UIButton(type: UIButtonType.system)
		endTalkbackButton = UIButton(type: UIButtonType.system)
		talkbackStatus = UILabel()
		currentViewersLabel = UILabel()
		pinchRecognizer = UIPinchGestureRecognizer()
		initialZoom = 0.0

		super.init(coder: aDecoder)

		bambuserView.delegate = self;
		bambuserView.applicationId = "CHANGEME"
		bambuserView.broadcastTitle = "Test broadcast"

		bambuserView.talkback = true

		bambuserView.orientation = UIApplication.shared.statusBarOrientation

		bambuserView.startCapture()

		fileUploader = FileUploader(_delegate: self)

		broadcastButton.addTarget(self, action: #selector(ViewController.broadcast), for: UIControlEvents.touchUpInside)
		broadcastButton.setTitle("Broadcast", for: UIControlState())

		swapButton.addTarget(bambuserView, action: #selector(BambuserView.swapCamera), for: UIControlEvents.touchUpInside)
		swapButton.setTitle("Swap", for: UIControlState())

		talkbackStatus.textAlignment = NSTextAlignment.left;
		talkbackStatus.text = ""
		talkbackStatus.backgroundColor = UIColor.clear
		talkbackStatus.textColor = UIColor.white
		talkbackStatus.shadowColor = UIColor.black
		talkbackStatus.shadowOffset = CGSize(width: 1, height: 1)

		uploadButton.addTarget(self, action: #selector(ViewController.showImagePicker), for: UIControlEvents.touchUpInside)
		uploadButton.setTitle("Upload", for: UIControlState())
		pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ViewController.handlePinchGesture(_:)))

		currentViewersLabel.textAlignment = NSTextAlignment.left
		currentViewersLabel.text = ""
		currentViewersLabel.font = UIFont.systemFont(ofSize: 16)
		currentViewersLabel.backgroundColor = UIColor.clear
		currentViewersLabel.textColor = UIColor.blue
	}

	override func loadView() {
		super.loadView()
		self.view.addSubview(bambuserView.view)
		self.view.addSubview(bambuserView.chatView)

		self.view.addSubview(broadcastButton)
		self.view.addSubview(uploadButton)
		self.view.addSubview(talkbackStatus)
		self.view.addSubview(currentViewersLabel)
		if (bambuserView.hasFrontCamera) {
			self.view.addSubview(swapButton)
		}
		self.view.addGestureRecognizer(pinchRecognizer);
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func viewWillLayoutSubviews() {
		var statusBarOffset : CGFloat = 0.0
		statusBarOffset = CGFloat(self.topLayoutGuide.length)

		broadcastButton.frame = CGRect(x: 0.0, y: 0.0 + statusBarOffset, width: 100.0, height: 50.0);
		uploadButton.frame = CGRect(x: self.view.bounds.size.width - 100.0, y: 0.0 + statusBarOffset, width: 100.0, height: 50.0);
		if (bambuserView.hasFrontCamera) {
			swapButton.frame = CGRect(x: 0.0, y: 50.0 + statusBarOffset, width: 100.0, height: 50.0);
		}
		talkbackStatus.frame = CGRect(x: 110.0, y: 100.0 + statusBarOffset, width: 180.0, height: 50.0);
		currentViewersLabel.frame = CGRect(x: self.view.bounds.size.width - 100 , y: self.view.bounds.size.height - 30, width: 100, height: 30)
		bambuserView.previewFrame = CGRect(x: 0.0, y: 0.0 + statusBarOffset, width: self.view.bounds.size.width, height: self.view.bounds.size.height - statusBarOffset)
		bambuserView.chatView.frame = CGRect(x: 0.0, y: self.view.bounds.size.height-self.view.bounds.size.height/3.0, width: self.view.bounds.size.width, height: self.view.bounds.size.height/3.0)
	}

	override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
		return UIInterfaceOrientationMask.allButUpsideDown
	}

	override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
		bambuserView.setOrientation(toInterfaceOrientation, previewOrientation: toInterfaceOrientation)
	}

	override var shouldAutorotate : Bool {
		return broadcastButton.isEnabled && broadcastButton.currentTitle != "Stop";
	}

	override var prefersStatusBarHidden : Bool {
		return false
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@objc func showImagePicker() {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.allowsEditing = false
		picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
		picker.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
		picker.videoQuality = UIImagePickerControllerQualityType.typeIFrame1280x720
		if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
			popover = UIPopoverController(contentViewController: picker)
			popover?.present(from: uploadButton.frame, in: self.view, permittedArrowDirections: UIPopoverArrowDirection.any, animated: true)
		} else {
			self.present(picker, animated: true, completion: nil)
		}
	}

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {

		let referenceURL = info[UIImagePickerControllerReferenceURL] as! URL

		let fetchResult:PHFetchResult = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
		if (fetchResult.firstObject != nil) {
			self.uploadAsset(fetchResult.firstObject!, info: info as [String : AnyObject])
		} else {
			print("Asset not found")
		}

		picker.dismiss(animated: true, completion: nil)
	}

	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true, completion: nil);
	}

	func uploadAsset(_ asset: NSObject, info:[String : AnyObject]) {
		let dictionary = ["exampleKey" : "exampleValue"]
		var ticketAssets = [
			"info" : info,
			"fileType" : (info[UIImagePickerControllerMediaType] as! String == "public.image" ? "image" : "video"),
			"author" : "JOHN CHANGEME",
			"title" : "Test broadcast",
			"deleteAfterUpload" : true,
			"dictionary" : dictionary,
			"asset" : asset
		] as [String : Any]

		if (!(self.bambuserView.applicationId ?? "").isEmpty) {
			ticketAssets["applicationId"] = self.bambuserView.applicationId
		}
		DispatchQueue.main.async {
			self.fileUploader!.getTicketAndUpload(ticketAssets as Dictionary<String, AnyObject>)
		}
	}

	@objc func broadcast() {
		broadcastButton.setTitle("Connecting", for: UIControlState())
		broadcastButton.isEnabled = false
		bambuserView.startBroadcasting()
	}

	func broadcastButtonStop() {
		broadcastButton.setTitle("Stop", for: UIControlState())
		broadcastButton.isEnabled = true
		broadcastButton.removeTarget(nil, action: nil, for: UIControlEvents.touchUpInside)
		broadcastButton.addTarget(bambuserView, action: #selector(BambuserView.stopBroadcasting), for: UIControlEvents.touchUpInside)
	}

	func broadcastStarted() {
		self.broadcastButtonStop()
		print("Received broadcastStarted signal")
	}

	func broadcastButtonBroadcast() {
		broadcastButton.setTitle("Broadcast", for: UIControlState())
		broadcastButton.isEnabled = true
		broadcastButton.removeTarget(nil, action: nil, for: UIControlEvents.touchUpInside)
		broadcastButton.addTarget(self, action: #selector(ViewController.broadcast), for: UIControlEvents.touchUpInside)
	}

	func broadcastStopped() {
		self.broadcastButtonBroadcast()
		self.currentViewersLabel.text = ""
	}

	func recordingComplete(_ filename : String) {
		let url = URL(fileURLWithPath: filename)
		/*
		 * We need to do this check since the performChanges call returns
		 * before the user has granted access in cases it is not yet determined
		 */
		let authorizationStatus = PHPhotoLibrary.authorizationStatus()
		switch (authorizationStatus) {
		case PHAuthorizationStatus.notDetermined:
			PHPhotoLibrary.requestAuthorization({ (status) in
				if (status == PHAuthorizationStatus.authorized) {
					self.recordingComplete(filename)
				}
			})
			break
		case PHAuthorizationStatus.authorized:
			PHPhotoLibrary.shared().performChanges({
				PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
				}, completionHandler: { (success, error) in
					self.saveComplete(success, filename: filename)
			})
			break
		case PHAuthorizationStatus.restricted:
			fallthrough
		case PHAuthorizationStatus.denied:
			fallthrough
		default:
			/*
			 *  This scenario is likely to happen if the user denies access to the camera roll.
			 *  If exporting to camera roll is your only option, make sure to recover or remove this video file.
			 */
			self.showError("Video not saved locally, access to Photos not granted")
			break
		}
	}

	func saveComplete(_ success:Bool, filename:String) {
		if (success) {
			print("Exported recording from " + filename + " to camera roll")
			let fileManager = FileManager.default
			do {
				try fileManager.removeItem(atPath: filename)
				print("Removing file from " + filename)
			} catch {
				print("Failed to remove temporary recording")
			}
		} else {
			/*
			 *  This scenario is likely to happen if the user denies access to the camera roll.
			 *  If exporting to camera roll is your only option, make sure to recover or remove this video file.
			 */
			print("Failed to export recording from " + filename)
		}
	}

	func showError(_ errorMessage : String) {
		let alertController:UIAlertController =  UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
		let cancelAction = UIAlertAction(title: "OK", style: .default, handler: nil)
		alertController.addAction(cancelAction)
		self.present(alertController, animated: true, completion: nil)
	}

	func bambuserError(_ code: BambuserError, message: String) {
		switch (code) {
			case kBambuserErrorServerFull,
			kBambuserErrorIncorrectCredentials,
			kBambuserErrorConnectionLost,
			kBambuserErrorUnableToConnect:
				// Enable broadcastbutton on connection error
				DispatchQueue.main.async {
					self.broadcastButtonBroadcast()
				}
			break
		case kBambuserErrorServerDisconnected, kBambuserErrorLocationDisabled, kBambuserErrorNoCamera:
			break;
		default:
			break
		}
		DispatchQueue.main.async {
			self.showError(message as String)
		}
	}

	func chatMessageReceived(_ message : String) {
		bambuserView.displayMessage(String(message))
	}

	func talkbackRequest(_ request : String, caller : String, talkbackID : Int32) {
		let talkbackRequest = UIAlertController(title: caller, message: request, preferredStyle: .alert)
		let acceptAction = UIAlertAction(title: "Accept", style: .default) { (action:UIAlertAction) in
			self.bambuserView.acceptTalkbackRequest(talkbackID)
		}
		let declineAction = UIAlertAction(title: "Decline", style: .destructive) { (action:UIAlertAction) in
			self.bambuserView.declineTalkbackRequest(talkbackID)
		}
		talkbackRequest.addAction(acceptAction)
		talkbackRequest.addAction(declineAction)
		self.present(talkbackRequest, animated: true, completion: nil)
	}

	func talkbackStateChanged(_ state: TalkbackState) {
		switch (state) {
		case kTalkbackNeedsAccept:
			talkbackStatus.text = "Talkback pending";
			break;
		case kTalkbackAccepted:
			talkbackStatus.text = "Talkback accepted";
			break;
		case kTalkbackPlaying:
			talkbackStatus.text = "Talkback playing";
			break;
		default:
			talkbackStatus.text = "";
		}

		// Add or remove button for ending talkback
		if (state == kTalkbackPlaying) {
			endTalkbackButton = UIButton(type: UIButtonType.system)
			endTalkbackButton.addTarget(bambuserView, action: #selector(BambuserView.endTalkback), for: UIControlEvents.touchUpInside)
			let statusBarOffset = self.topLayoutGuide.length;
			endTalkbackButton.frame = CGRect(x: 0.0, y: 150.0 + statusBarOffset, width: 100.0, height: 50.0);
			endTalkbackButton.setTitle("End talkback", for: UIControlState())
			self.view.addSubview(endTalkbackButton)
		} else {
			endTalkbackButton.removeFromSuperview()
		}
	}

	func currentViewerCountUpdated(_ viewers: Int32) {
		currentViewersLabel.text = "Viewers: \(viewers)"
	}

	func totalViewerCountUpdated(_ viewers: Int32) {
		print("Total viewers: \(viewers)")
	}

	func uploadStarted(_ async: NSNumber) {
		uploadAlertController =  UIAlertController(title: "Uploading", message: "", preferredStyle: .alert)
		if (async.boolValue) {
			let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction) in
				self.uploadEnded()
				self.fileUploader?.cancelUpload()
			}
			uploadAlertController!.addAction(cancelAction)
		}
		progressBar = UIProgressView(frame: CGRect(x: 25.0, y: 50.0, width: 230.0, height: 90.0))
		progressBar?.progressViewStyle = UIProgressViewStyle.bar
		uploadAlertController?.view.addSubview(progressBar!)
		self.present(uploadAlertController!, animated: true, completion: nil)
	}

	func uploadUpdated(_ progress: NSNumber) {
		progressBar?.setProgress(progress.floatValue, animated: true)
	}

	func uploadEnded() {
		uploadAlertController?.dismiss(animated: true, completion: nil)
		uploadAlertController = nil;
		progressBar = nil;
	}

	func uploadFailed() {
		uploadAlertController?.dismiss(animated: true, completion: nil)
		uploadAlertController = nil;
		progressBar = nil;
		DispatchQueue.main.async {
			self.showError("Upload failed")
		}
	}

	@objc func handlePinchGesture(_ sender : UIPinchGestureRecognizer) {
		if (sender.state == UIGestureRecognizerState.began) {
			initialZoom = bambuserView.zoom
		}
		bambuserView.zoom = initialZoom * Float(sender.scale)
	}
}

