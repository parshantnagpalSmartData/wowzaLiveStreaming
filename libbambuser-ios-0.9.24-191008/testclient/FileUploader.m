/*
 * libbambuser - Bambuser iOS library
 * Copyright 2014 Bambuser AB
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

#import <CoreLocation/CoreLocation.h>
#import "FileUploader.h"
#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

@implementation FileUploader
@synthesize delegate;

-(id) initWithDelegate: (id) _delegate {
	if (self = [super init]) {
		delegate = _delegate;
		uploadURL = nil;
		inputFilename = nil;
	}
	return self;
}

-(NSString *)urlEncode: (NSString*) string {
	return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
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
 - excludeLocationData (NSNumber *) - optional key to disable location parameter

 NOTE: Either filename or asset/info-pair must be supplied.
 NOTE: If applicationId isn't provided, username and password can be supplied for backwards compatibility.
 */
-(void) getTicketAndUpload: (NSDictionary*) assets {
	NSObject *asset = [assets objectForKey: @"asset"];
	NSDictionary *info = [assets objectForKey: @"info"];
	NSString* uploadType = [assets objectForKey: @"fileType"];
	NSString *applicationId = [assets objectForKey: @"applicationId"];
	NSString *username = [assets objectForKey: @"username"];
	NSString *password = [assets objectForKey: @"password"];
	NSString *author = [assets objectForKey: @"author"];
	NSString *title = [assets objectForKey: @"title"];
	NSDictionary *dictionary = [assets objectForKey: @"dictionary"];
	NSDate *created = nil;
	if ([asset isKindOfClass: [ALAsset class]])
		created = [(ALAsset*)asset valueForProperty: ALAssetPropertyDate];
	else if ([asset isKindOfClass: [PHAsset class]])
		created = ((PHAsset*)asset).creationDate;
	NSString *uploadFilename = [assets objectForKey: @"filename"];
	NSString *filename;
	NSNumber *deleteAfterUpload = [assets objectForKey: @"deleteAfterUpload"];
	NSNumber *excludeLocationData = [assets objectForKey: @"excludeLocationData"];
	// Keep a reference to the asset info, if available. For assets exported
	// from UIImagePickerController, the given path might become inaccessible when
	// this is released.
	infoDictionary = info;

	if (deleteAfterUpload == nil) {
		deleteOnCompletion = NO;
	} else {
		deleteOnCompletion = [deleteAfterUpload boolValue];
	}

	if (!uploadFilename) {
		if ([info valueForKey: UIImagePickerControllerMediaURL]) {
			uploadFilename = [[info valueForKey: UIImagePickerControllerMediaURL] path];
		}
		if (created) {
			NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
			dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH.mm.ss";
			filename = [dateFormatter stringFromDate: created];
		} else {
			filename = uploadType;
		}
		filename = [filename stringByAppendingString: [uploadType isEqualToString: @"image"] ? @".jpg" : @".mp4"];
	} else {
		// This properly handles both plain file paths and file:// urls; previously
		// it only worked if it was a file:// url.
		uploadFilename = [[NSURL URLWithString: uploadFilename] path];
		filename = [uploadFilename lastPathComponent];
	}

	NSMutableDictionary* params = [NSMutableDictionary dictionary];
	[params setValue:uploadType forKey:@"type"];
	[params setValue:filename forKey:@"filename"];

	// optional: custom_data
	if (dictionary) {
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:nil];
		NSString *custom_data = [[NSString alloc] initWithData: jsonData encoding:NSUTF8StringEncoding];
		[params setValue:custom_data forKey:@"custom_data"];
	}

	// optional: created
	if (created) {
		[params setValue:[NSString stringWithFormat:@"%d", (int) [created timeIntervalSince1970]] forKey:@"created"];
	}

	// optional: author
	if (author) {
		[params setValue:author forKey:@"author"];
	}

	// optional: title
	if (title) {
		[params setValue:title forKey:@"title"];
	}

	// optional: device_model
	struct utsname u;
	uname(&u);
	NSString *device_model = [NSString stringWithFormat:@"%s", u.machine];
	[params setValue:device_model forKey:@"device_model"];

	// optional: client_version
	NSString *bundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
	NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *client_version = [NSString stringWithFormat:@"%@ %@", bundleIdentifier, bundleVersion];
	[params setValue:client_version forKey:@"client_version"];

	// optional: platform
	[params setValue:@"iOS" forKey:@"platform"];

	// optional: platform_version
	NSString *platform_version = [[UIDevice currentDevice] systemVersion];
	[params setValue:platform_version forKey:@"platform_version"];

	// optional: manufacturer
	[params setValue:@"Apple" forKey:@"manufacturer"];

	// optional: latitude, longitude
	CLLocation *coord = nil;
	if ([asset isKindOfClass: [ALAsset class]])
		coord = [(ALAsset*)asset valueForProperty: ALAssetPropertyLocation];
	else if ([asset isKindOfClass: [PHAsset class]])
		coord = ((PHAsset*)asset).location;
	if (coord && ![excludeLocationData boolValue]) {
		[params setValue:[NSString stringWithFormat:@"%f", (float) coord.coordinate.latitude] forKey:@"lat"];
		[params setValue:[NSString stringWithFormat:@"%f", (float) coord.coordinate.longitude] forKey:@"lon"];
	}

	NSData *postData;
	NSString *contentType;
	NSString *authValue = nil;
	NSURL *url;
	NSDictionary *extraHeaders = nil;
	if (applicationId) {
		url = [NSURL URLWithString:@"https://cdn.bambuser.net/uploadTickets"];
		postData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:nil];
		contentType = @"application/json";
		extraHeaders = @{
			@"X-Bambuser-ApplicationId": applicationId,
			@"Accept": @"application/vnd.bambuser.cdn.v1+json",
			@"X-Bambuser-ClientVersion": client_version,
			@"X-Bambuser-ClientPlatform": [NSString stringWithFormat:@"iOS %@", platform_version]
		};
	} else {
		url = [NSURL URLWithString:@"https://api.bambuser.com/file/ticket.json"];
		NSString *post = @"";
		for (NSString* key in params) {
			NSString* value = [params valueForKey: key];
			if (![post isEqualToString: @""])
				post = [post stringByAppendingString: @"&"];
			post = [post stringByAppendingString: [NSString stringWithFormat:@"%@=%@", key, [self urlEncode: value]]];
		}
		contentType = @"application/x-www-form-urlencoded";

		postData = [post dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];

		NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
		NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
		authValue = [authData base64EncodedStringWithOptions: 0];
	}
	NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];

	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL: url];
	[request setHTTPMethod:@"POST"];
	[request setTimeoutInterval: 10.0f];
	if (authValue)
		[request setValue: [NSString stringWithFormat: @"Basic %@",authValue] forHTTPHeaderField: @"Authorization"];
	[request setValue: postLength forHTTPHeaderField: @"Content-Length"];
	[request setValue: contentType forHTTPHeaderField: @"Content-Type"];
	if (extraHeaders) {
		for (NSString* key in extraHeaders)
			[request setValue: [extraHeaders valueForKey: key] forHTTPHeaderField: key];
	}
	[request setHTTPBody: postData];

	ticketTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error != nil) {
			if ([self->delegate respondsToSelector:@selector(showError:)]) {
				[self->delegate performSelectorOnMainThread: @selector(showError:) withObject: [error localizedDescription] waitUntilDone:NO];
			}
			NSLog(@"%@", error);
			return;
		}

		NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData: data options:0 error:&error];
		if (!parsedData) {
			if ([self->delegate respondsToSelector:@selector(showError:)]) {
				[self->delegate performSelectorOnMainThread: @selector(showError:) withObject:[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] waitUntilDone:NO];
			}
			return;
		}

		if ([parsedData valueForKey: @"error"]) {
			NSLog(@"%@", [parsedData valueForKey: @"error"]);
			if ([self->delegate respondsToSelector:@selector(showError:)]) {
				[self->delegate performSelectorOnMainThread: @selector(showError:) withObject:[NSString stringWithFormat: @"%@", [[parsedData valueForKey: @"error"] valueForKey: @"message"]] waitUntilDone:NO];
			}
			return;
		}

		self->uploadURL = [NSURL URLWithString: [parsedData valueForKey:@"upload_url"]];
		if (self->uploadURL == nil) {
			if ([self->delegate respondsToSelector:@selector(showError:)]) {
				[self->delegate performSelectorOnMainThread: @selector(showError:) withObject: @"Unexpected response from upload server, please try again." waitUntilDone:NO];
			}
			return;
		}

		NSString *localUploadFilename = uploadFilename;
		if (!localUploadFilename) {
			if ([uploadType isEqual: @"image"] && info != nil) {
				localUploadFilename = [NSTemporaryDirectory() stringByAppendingPathComponent: @"image.jpg"];
				[UIImageJPEGRepresentation([info valueForKey: UIImagePickerControllerOriginalImage], 1.0) writeToFile: localUploadFilename atomically: YES];
			}
		}

		if (localUploadFilename) {
			[self performSelectorOnMainThread: @selector(uploadFile:) withObject: localUploadFilename waitUntilDone: YES];
			return;
		}
		if ([self->delegate respondsToSelector:@selector(uploadFailed)]) {
			[self->delegate performSelectorOnMainThread:@selector(uploadFailed) withObject:nil waitUntilDone:NO];
		}
	}];
	[ticketTask resume];
}

/*
Alternative upload entrypoint, for when you have an upload ticket instead of an applicationId

Example scenario: Your own server holds the Bambuser credentials and hands out upload tickets
on demand to your iOS app.
*/
- (void) uploadFile:(NSString *) filename toUploadURL:(NSURL *)ticketUploadURL {
	uploadURL = [ticketUploadURL copy];
	[self uploadFile:filename];
}

- (void) uploadFile: (NSString*) filename {
	inputFilename = [filename copy];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL: uploadURL];
	[request setHTTPMethod: @"PUT"];

	NSFileManager *man = [NSFileManager defaultManager];
	filesize = [[man attributesOfItemAtPath: filename error: NULL] fileSize];
	responseStatus = 0;

	[request addValue: [NSString stringWithFormat: @"%"PRId64"", filesize] forHTTPHeaderField: @"Content-Length"];

	[request setHTTPBodyStream: [[NSInputStream alloc] initWithFileAtPath: filename]];
	[request setTimeoutInterval: 60.0f];

	NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:queue];
	uploadTask = [session uploadTaskWithStreamedRequest:request];
	[uploadTask resume];
	if ([delegate respondsToSelector:@selector(uploadStarted:)]) {
		[delegate performSelectorOnMainThread:@selector(uploadStarted:) withObject:[NSNumber numberWithBool: YES] waitUntilDone:NO];
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
	NSInputStream* inputStream = [[NSInputStream alloc] initWithFileAtPath: inputFilename];
	completionHandler(inputStream);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
	float progress = ((float)totalBytesSent) / ((float)filesize);
	if ([delegate respondsToSelector:@selector(uploadUpdated:)]) {
		[delegate performSelectorOnMainThread:@selector(uploadUpdated:) withObject: [NSNumber numberWithFloat: progress] waitUntilDone:NO];
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
	if (error != nil) {
		if (error.code != NSURLErrorCancelled) {
			if ([delegate respondsToSelector:@selector(uploadFailed)])
				[delegate performSelectorOnMainThread:@selector(uploadFailed) withObject:nil waitUntilDone:NO];
		}
	} else {
		if (responseStatus == 200) {
			if ([delegate respondsToSelector:@selector(uploadEnded)]) {
				[delegate performSelectorOnMainThread:@selector(uploadEnded) withObject:nil waitUntilDone:NO];
			}
		} else {
			if ([delegate respondsToSelector:@selector(uploadFailed)]) {
				[delegate performSelectorOnMainThread:@selector(uploadFailed) withObject:nil waitUntilDone:NO];
			}
		}
	}
	[self cancelAndFinalizeUploadTask];
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
	if (error != nil) {
		if ([delegate respondsToSelector:@selector(uploadFailed)]) {
			[delegate performSelectorOnMainThread:@selector(uploadFailed) withObject:nil waitUntilDone:NO];
		}
	}
	[self cancelAndFinalizeUploadTask];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
	NSLog(@"%@", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
	NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
	responseStatus = (int)[httpResponse statusCode];
	if (responseStatus == 200) {
	} else if (responseStatus >= 400 && responseStatus < 500) {
		// Client error
		NSLog(@"Upload was not accepted");
	} else if (responseStatus >= 500 && responseStatus < 600) {
		// Server error
		NSLog(@"Upload was not accepted");
	} else {
		NSLog(@"Unexpected status code: %d", responseStatus);
	}
	completionHandler(NSURLSessionResponseAllow);
}

- (void) cancelUpload {
	[self cancelAndFinalizeUploadTask];
}

- (void) cancelAndFinalizeUploadTask {
	[uploadTask cancel];
	uploadTask = nil;
	[ticketTask cancel];
	ticketTask = nil;
	infoDictionary = nil;
	if (deleteOnCompletion) {
		[[NSFileManager defaultManager] removeItemAtPath: inputFilename error: NULL];
	}
}


@end
