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

import Foundation
import AssetsLibrary
import CoreLocation
import Photos

@objc protocol FileUploaderDelegate
{
	@objc optional func uploadStarted(_ async : NSNumber)
	@objc optional func uploadUpdated(_ progress : NSNumber)
	@objc optional func uploadEnded()
	@objc optional func showError(_ errorMessage : String)
	@objc optional func uploadFailed()
}

class FileUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
	weak var delegate: AnyObject?
	var uploadURL: URL?
	var inputFilename: String?
	var ticketTask: URLSessionDataTask?
	var uploadTask: URLSessionUploadTask?
	var deleteOnCompletion: Bool
	var filesize: Int64?
	var responseStatus: Int?
	var infoDictionary: Dictionary<String, AnyObject>?
	init(_delegate: AnyObject) {
		delegate = _delegate
		uploadURL = nil
		inputFilename = nil
		deleteOnCompletion = false
	}

	func urlEncode(_ string: String) -> String {
		let escapedString = string.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
		return escapedString!
	}

	/*
	Keys passed to getTicketAndUpload:
	required:
 - fileType (NSString*) - @"image" or @"video"
 - applicationId (NSString*)
 optional:
 - filename (NSString*) - path to file for upload
 - dictionary (NSDictionary*) - custom dictionary to be associated with the upload
 - info (NSDictionary*) - info dictionary for asset
 - asset (ALAsset*) or (PHAsset*) - asset with metadata and reference to image/video.
 - library (ALAssetsLibrary*)
 - excludeLocationData (Bool) - optional key to disable location parameter

 NOTE: Either filename or asset/info-pair must be supplied.
 NOTE: If applicationId isn't provided, username and password can be supplied for backwards compatibility.
 */
	func getTicketAndUpload(_ assets: Dictionary <String, AnyObject>) {
		let asset = assets["asset"]
		let info = assets["info"] as? Dictionary <String, AnyObject>
		let uploadType = assets["fileType"] as! String
		let applicationId = assets["applicationId"] as? String
		let username = assets["username"] as? String
		let password = assets["password"] as? String
		let author = assets["author"] as? String
		let title = assets["title"] as? String
		let dictionary = assets["dictionary"] as? Dictionary <String, AnyObject>
		var created:Date?
		if (asset is ALAsset) {
			created = asset!.value(forProperty: ALAssetPropertyDate) as? Date
		} else if (asset is PHAsset) {
			created = (asset as! PHAsset).creationDate
		}
		var uploadFilename = assets["filename"] as? String
		var filename: String
		let deleteAfterUpload = assets["deleteAfterUpload"] as? Bool
		if (deleteAfterUpload == nil) {
			deleteOnCompletion = false
		} else {
			deleteOnCompletion = deleteAfterUpload!
		}
		var excludeLocationData = assets["excludeLocationData"] as? Bool
		if (excludeLocationData == nil) {
			excludeLocationData = false
		}
		// Keep a reference to the asset info, if available. For assets exported
		// from UIImagePickerController, the given path might become inaccessible when
		// this is released.
		infoDictionary = info

		if (uploadFilename == nil) {
			if let mediaurl = info?[UIImagePickerControllerMediaURL] as? URL {
				uploadFilename = mediaurl.path
			}
			if (created != nil) {
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd'T'HH.mm.ss"
				filename = dateFormatter.string(from: created!)
			} else {
				filename = uploadType
			}
			filename = filename + (uploadType == "image" ? ".jpg" : ".mp4")
		} else {
			// This properly handles both plain file paths and file:// urls; previously
			// it only worked if it was a file:// url.
			uploadFilename = URL(string: uploadFilename!)!.path
			filename = (uploadFilename! as NSString).lastPathComponent
		}

		var params:[String:String] = [String:String]()
		params["type"] = uploadType
		params["filename"] = filename

		// optional: custom_data
		if (dictionary != nil) {
			let jsonData = try? JSONSerialization.data(withJSONObject: dictionary!, options: JSONSerialization.WritingOptions.prettyPrinted)
			let custom_data = NSString(data: jsonData!, encoding: String.Encoding.utf8.rawValue)! as String
			params["custom_data"] = custom_data
		}

		// optional: created
		if (created != nil) {
			params["created"] = String(Int(created!.timeIntervalSince1970))
		}

		// optional: author
		if (author != nil) {
			params["author"] = author!
		}

		// optional: title
		if (title != nil) {
			params["title"] = title!
		}

		// optional: device_model
		var name: [Int32] = [CTL_HW, HW_MACHINE]
		var size: Int = 2
		sysctl(&name, 2, nil, &size, nil, 0)
		var hw_machine = [CChar](repeating: 0, count: Int(size))
		sysctl(&name, 2, &hw_machine, &size, nil, 0)
		let hardware: String = String(cString: hw_machine)
		params["device_model"] = hardware

		// optional: client_version
		let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String
		let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
		params["client_version"] = bundleIdentifier + " " + bundleVersion

		// optional: platform
		params["platform"] = "iOS"

		// optional: platform_version
		params["platform_version"] = UIDevice.current.systemVersion

		// optional: manufacturer
		params["manufacturer"] = "Apple"

		//optional: latitude, longitude
		if (asset != nil) {
			var coord: CLLocation?
			if (asset is ALAsset) {
				coord = asset!.value(forProperty: ALAssetPropertyLocation) as? CLLocation
			} else if (asset is PHAsset) {
				coord = (asset as! PHAsset).location
			}

			if (coord != nil && !excludeLocationData!) {
				params["lat"] = coord!.coordinate.latitude.description
				params["lon"] = coord!.coordinate.longitude.description
			}
		}

		let postData:Data?
		let url:URL?
		let contentType:String
		var authValue:String?
		var extraHeaders:[String:String]?
		if (!(applicationId ?? "").isEmpty) {
			url = URL(string: "https://cdn.bambuser.net/uploadTickets")
			postData = try? JSONSerialization.data(withJSONObject: params, options: JSONSerialization.WritingOptions.prettyPrinted)
			contentType = "application/json"

			extraHeaders = [
				"X-Bambuser-ApplicationId": applicationId!,
				"Accept": "application/vnd.bambuser.cdn.v1+json",
				"X-Bambuser-ClientVersion": bundleIdentifier + " " + bundleVersion,
				"X-Bambuser-ClientPlatform": "iOS " + UIDevice.current.systemVersion
			]
		} else {
			url = URL(string: "https://api.bambuser.com/file/ticket.json")
			var post:String = ""
			for (key, value) in params {
				if (post != "") {
					post = post + "&"
				}
				post = post + key + "=" + self.urlEncode(value)
			}
			contentType = "application/x-www-form-urlencoded"

			postData = post.data(using: String.Encoding.utf8, allowLossyConversion: true)

			let authStr = username! + ":" + password!
			let authData = authStr.data(using: String.Encoding.utf8, allowLossyConversion: true)
			authValue = authData?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
		}

		let postLength = postData?.count.description

		let request = NSMutableURLRequest()
		request.url = url
		request.httpMethod = "POST"
		request.timeoutInterval = 10.0
		if (authValue != nil) {
			request.setValue("Basic " + authValue!, forHTTPHeaderField: "Authorization")
		}
		request.setValue(postLength, forHTTPHeaderField: "Content-Length")
		request.setValue(contentType, forHTTPHeaderField: "Content-Type")
		if (extraHeaders != nil) {
			for (key, value) in extraHeaders! {
				request.setValue(value, forHTTPHeaderField: key)
			}
		}
		request.httpBody = postData

		ticketTask = Foundation.URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in

			if (error != nil) {
				DispatchQueue.main.async(execute: {
					self.delegate?.showError?(error!.localizedDescription)
				})
				return
			}

			do {
				try JSONSerialization.jsonObject(with: data!, options: .mutableContainers)
			} catch {
				let responseString = NSString(data: data!, encoding:String.Encoding.utf8.rawValue)
				DispatchQueue.main.async(execute: {
					self.delegate?.showError?(responseString! as String)
				})
				return
			}

			let parsedData = (try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions())) as! NSDictionary
			if (parsedData["error"] != nil) {
				let responseError = parsedData["error"] as! NSDictionary
				print(responseError)
				let message = responseError["message"]! as! String
				DispatchQueue.main.async(execute: {
					self.delegate?.showError?(message)
				})
				return
			}

			self.uploadURL = URL(string: (parsedData["upload_url"] as? String)!)
			if (self.uploadURL == nil) {
				DispatchQueue.main.async(execute: {
					self.delegate?.showError?("Unexpected response from upload server, please try again.")
				})
				return
			}

			if (uploadFilename == nil) {
				if (uploadType=="image" && info != nil) {
					uploadFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent("image.jpg")

					let image = UIImageJPEGRepresentation(info![UIImagePickerControllerOriginalImage] as! UIImage, 1.0)
					try? image?.write(to: URL(fileURLWithPath: uploadFilename!), options: [.atomic])
				}
			}
			if (uploadFilename != nil) {
				DispatchQueue.main.async(execute: {
					self.uploadFile(uploadFilename!)
				})
				return
			}
			DispatchQueue.main.async(execute: {
				self.delegate?.uploadFailed?()
			})

		})
		ticketTask?.resume()

	}

	/*
	Alternative upload entrypoint, for when you have an upload ticket instead of an applicationId

	Example scenario: Your own server holds the Bambuser credentials and hands out upload tickets
	on demand to your iOS app.
	*/
	func uploadFile(_ filename: String, toUploadURL ticketUploadURL: URL) {
		uploadURL = ticketUploadURL
		uploadFile(filename)
	}

	func uploadFile(_ filename: String) {
		inputFilename = filename
		let request = NSMutableURLRequest()
		request.url = uploadURL!
		request.httpMethod = "PUT"
		let man = FileManager.default
		let attr = (try? man.attributesOfItem(atPath: inputFilename!)) as [FileAttributeKey : AnyObject]?
		filesize = attr?[FileAttributeKey.size]?.int64Value
		responseStatus = 0

		request.addValue(filesize!.description, forHTTPHeaderField: "Content-Length")

		let inputStream = InputStream(fileAtPath: inputFilename!)

		request.httpBodyStream = inputStream
		request.timeoutInterval = 60.0

		let sessionConfig:URLSessionConfiguration = URLSessionConfiguration.default
		let queue = OperationQueue()
		let session:Foundation.URLSession = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: queue)
		uploadTask = session.uploadTask(withStreamedRequest: request as URLRequest)
		uploadTask?.resume()
		DispatchQueue.main.async(execute: {
			self.delegate?.uploadStarted?(true)
		})
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
		let inputStream = InputStream(fileAtPath: inputFilename!)
		completionHandler(inputStream)
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		let progress = Float(totalBytesSent) / Float(filesize!)
		DispatchQueue.main.async(execute: {
			self.delegate?.uploadUpdated?(NSNumber(value: progress))
		})
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		DispatchQueue.main.async(execute: {
			if (error != nil) {
				if (error!._code != NSURLErrorCancelled) {
					self.delegate?.uploadFailed?()
				}
			} else {
				if (self.responseStatus! == 200) {
					self.delegate?.uploadEnded?()
				} else {
					self.delegate?.uploadFailed?()
				}
			}
		})
		self.cancelAndFinalizeUploadTask()
	}

	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		if (error != nil) {
			DispatchQueue.main.async(execute: {
				self.delegate?.uploadFailed?()
			})
		}
		self.cancelAndFinalizeUploadTask()
	}

	func urlSession(_ session: Foundation.URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		print(NSString(data: data, encoding: String.Encoding.utf8.rawValue)!)
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

		if let httpResponse = response as? HTTPURLResponse {
			responseStatus = httpResponse.statusCode

			if (responseStatus == 200) {
			} else if (responseStatus! >= 400 && responseStatus! < 500) {
				// Client error
				print("Upload was not accepted");
			} else if (responseStatus! >= 500 && responseStatus! < 600) {
				// Server error
				print("Upload was not accepted");
			} else {
				print("Unexpected status code:", responseStatus!);
			}
		}
		completionHandler(Foundation.URLSession.ResponseDisposition.allow)
	}

	func cancelUpload() {
		self.cancelAndFinalizeUploadTask()
	}

	fileprivate func cancelAndFinalizeUploadTask() {
		ticketTask?.cancel()
		uploadTask?.cancel()

		ticketTask = nil
		uploadTask = nil
		infoDictionary = nil

		if (deleteOnCompletion) {
			do {
				try FileManager.default.removeItem(atPath: inputFilename!)
			} catch _ {
			}
		}
	}
}
