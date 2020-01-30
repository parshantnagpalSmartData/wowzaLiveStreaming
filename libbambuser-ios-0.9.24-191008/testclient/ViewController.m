/*
 * libbambuser - Bambuser iOS library
 * Copyright 2013 Bambuser AB
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

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>

@implementation ViewController

- (id)init {
	if ((self = [super init])) {
		bambuserView = [[BambuserView alloc] initWithPreparePreset: kSessionPresetAuto];
		[bambuserView setDelegate: self];
		bambuserView.applicationId = @"CHANGEME";
		[bambuserView setBroadcastTitle:@"Test broadcast"];

		[bambuserView setTalkback: YES];

		[bambuserView setOrientation: [UIApplication sharedApplication].statusBarOrientation];

		[bambuserView startCapture];

		fileUploader = [[FileUploader alloc] initWithDelegate: self];

		broadcastButton = [UIButton buttonWithType: UIButtonTypeRoundedRect];
		[broadcastButton addTarget:self action:@selector(broadcast) forControlEvents:UIControlEventTouchUpInside];
		[broadcastButton setTitle:@"Broadcast" forState: UIControlStateNormal];

		swapButton = [UIButton buttonWithType: UIButtonTypeRoundedRect];
		[swapButton addTarget: bambuserView action:@selector(swapCamera) forControlEvents:UIControlEventTouchUpInside];
		[swapButton setTitle:@"Swap" forState: UIControlStateNormal];

		talkbackStatus = [[UILabel alloc] init];
		talkbackStatus.textAlignment = NSTextAlignmentLeft;
		talkbackStatus.text = @"";
		talkbackStatus.backgroundColor = [UIColor clearColor];
		talkbackStatus.textColor = [UIColor whiteColor];
		talkbackStatus.shadowColor = [UIColor blackColor];
		talkbackStatus.shadowOffset = CGSizeMake(1, 1);

		uploadButton = [UIButton buttonWithType: UIButtonTypeRoundedRect];
		[uploadButton addTarget:self action:@selector(showImagePicker) forControlEvents:UIControlEventTouchUpInside];
		[uploadButton setTitle:@"Upload" forState: UIControlStateNormal];

		currentViewersLabel = [[UILabel alloc] init];
		currentViewersLabel.textAlignment = NSTextAlignmentLeft;
		currentViewersLabel.text = @"";
		currentViewersLabel.font = [UIFont systemFontOfSize:16];
		currentViewersLabel.backgroundColor = [UIColor clearColor];
		currentViewersLabel.textColor = [UIColor blueColor];

		pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
		[pinchRecognizer setDelegate:self];
	}
	return self;
}


- (void) loadView {
	[super loadView];

	[self.view addSubview:bambuserView.view];

	[self.view addSubview:bambuserView.chatView];

	[self.view addSubview:broadcastButton];
	[self.view addSubview:uploadButton];
	[self.view addSubview:currentViewersLabel];
	[self.view addSubview:talkbackStatus];
	if (bambuserView.hasFrontCamera)
		[self.view addSubview:swapButton];
	[self.view addGestureRecognizer: pinchRecognizer];
}

- (void) viewWillLayoutSubviews {
	float statusBarOffset = self.topLayoutGuide.length;

	broadcastButton.frame = CGRectMake(0, 0 + statusBarOffset, 100, 50);
	uploadButton.frame = CGRectMake(self.view.bounds.size.width - 100, 0 + statusBarOffset, 100, 50);
	if (bambuserView.hasFrontCamera)
		swapButton.frame = CGRectMake(0, 50 + statusBarOffset, 100, 50);
	talkbackStatus.frame = CGRectMake(110, 100 + statusBarOffset, 180, 50);
	currentViewersLabel.frame = CGRectMake(self.view.bounds.size.width - 100 , self.view.bounds.size.height - 30, 100, 30);
	[bambuserView setPreviewFrame: CGRectMake(0, 0 + statusBarOffset, self.view.bounds.size.width, self.view.bounds.size.height - statusBarOffset)];
	[bambuserView.chatView setFrame:CGRectMake(0, self.view.bounds.size.height-self.view.bounds.size.height/3, self.view.bounds.size.width, self.view.bounds.size.height/3)];
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[bambuserView setOrientation: toInterfaceOrientation];
}

- (BOOL) shouldAutorotate {
	return broadcastButton.enabled && ![broadcastButton.currentTitle isEqualToString: @"Stop"];
}

- (BOOL) prefersStatusBarHidden {
	return NO;
}

- (void)handlePinchGesture: (UIPinchGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateBegan) {
		initialZoom = bambuserView.zoom;
	}
	bambuserView.zoom = initialZoom * sender.scale;
}

-(void) showImagePicker {
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.delegate = self;
	picker.allowsEditing = NO;
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, (NSString*) kUTTypeMovie, nil];
	picker.videoQuality = UIImagePickerControllerQualityTypeIFrame1280x720;
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		// This needs to be stored in a member, since it gets deallocated (while still visible)
		// if nothing keeps a reference to it.
		popover = [[UIPopoverController alloc] initWithContentViewController:picker];
		[popover presentPopoverFromRect:uploadButton.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {
		[self presentViewController:picker animated:YES completion:NULL];
	}
}

- (void) imagePickerController: (UIImagePickerController *) picker didFinishPickingMediaWithInfo: (NSDictionary *) info {
	NSURL *referenceURL = [info objectForKey:UIImagePickerControllerReferenceURL];

	PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[referenceURL] options:nil];
	if (fetchResult.firstObject) {
		[self uploadAsset:fetchResult.firstObject mediaInfo:info];
	} else {
		NSLog(@"Asset not found");
	}
	[picker dismissViewControllerAnimated:YES completion:NULL];
}

- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
	[picker dismissViewControllerAnimated:YES completion:NULL];
}

- (void) uploadAsset: (NSObject*) asset mediaInfo: (NSDictionary*)info {

	// Custom key-values to associate with your upload.
	NSDictionary *dictionary = @{ @"exampleKey": @"exampleValue"};

	NSMutableDictionary *ticketAssets = [NSMutableDictionary dictionary];
	[ticketAssets addEntriesFromDictionary: @{
		@"info" : info,
		@"fileType" : ([[info valueForKey: UIImagePickerControllerMediaType] isEqualToString:@"public.image"] ? @"image" : @"video"),
		@"author" : @"JOHN CHANGEME",
		@"title" : @"Test broadcast",
		@"deleteAfterUpload" : [NSNumber numberWithBool: YES],
		@"dictionary" : dictionary,
		@"asset" : asset
	}];
	if (bambuserView.applicationId)
		[ticketAssets setValue: bambuserView.applicationId forKey: @"applicationId"];
	[fileUploader performSelectorInBackground: @selector(getTicketAndUpload:) withObject: ticketAssets];
}

- (void) broadcast {
	[broadcastButton setTitle:@"Connecting" forState:UIControlStateNormal];
	[broadcastButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
	[broadcastButton addTarget:bambuserView action:@selector(stopBroadcasting) forControlEvents:UIControlEventTouchUpInside];
	[bambuserView startBroadcasting];
}

- (void) broadcastButtonStop {
	[broadcastButton setTitle:@"Stop" forState:UIControlStateNormal];
	[broadcastButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
	[broadcastButton addTarget:bambuserView action:@selector(stopBroadcasting) forControlEvents:UIControlEventTouchUpInside];
}

- (void) broadcastStarted {
	[self performSelectorOnMainThread:@selector(broadcastButtonStop) withObject:nil waitUntilDone:YES];
	NSLog(@"Received broadcastStarted signal");
}

- (void) broadcastButtonBroadcast {
	[broadcastButton setTitle:@"Broadcast" forState:UIControlStateNormal];
	[broadcastButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
	[broadcastButton addTarget:self action:@selector(broadcast) forControlEvents:UIControlEventTouchUpInside];
}

- (void) broadcastStopped {
	[self performSelectorOnMainThread:@selector(broadcastButtonBroadcast) withObject:nil waitUntilDone:YES];
	currentViewersLabel.text = @"";
	NSLog(@"Received broadcastStopped signal");
}

- (void) recordingComplete: (NSString*) filename {
	NSLog(@"Got filename: %@", filename);
	NSURL *url = [[NSURL alloc] initFileURLWithPath:filename];

	/*
	 * We need to do this check since the performChanges call returns
	 * before the user has granted access in cases it is not yet determined
	 */
	PHAuthorizationStatus authorizationStatus = [PHPhotoLibrary authorizationStatus];
	switch (authorizationStatus) {
		case PHAuthorizationStatusNotDetermined: {
			[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
				if (status == PHAuthorizationStatusAuthorized) {
					[self recordingComplete:filename];
				}
			}];

			break;
		}
		case PHAuthorizationStatusAuthorized: {
			[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^ {
				[PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
			} completionHandler:^(BOOL success, NSError *error) {
				[self saveComplete:success fileName:filename];
			}];
			break;
		}
		case PHAuthorizationStatusRestricted:
		case PHAuthorizationStatusDenied: {
			/*
			 *  This scenario is likely to happen if the user denies access to the camera roll.
			 *  If exporting to camera roll is your only option, make sure to recover or remove this video file.
			 */
			[self showError:@"Video not saved locally, access to Photos not granted"];
			break;
		}
		default:
			break;
	}
}

- (void) saveComplete: (BOOL)success fileName:(NSString*) filename {
	if (success) {
		NSLog(@"Exported recording from %@ to camera roll", filename);
		NSFileManager* fileManager = [NSFileManager defaultManager];
		if ([fileManager removeItemAtPath:filename error:nil]) {
			NSLog(@"Removing file from %@", filename);
		}
	} else {
		/*
		 *  This scenario is likely to happen if the user denies access to the camera roll.
		 *  If exporting to camera roll is your only option, make sure to recover or remove this video file.
		 */
		NSLog(@"Failed to export recording from %@", filename);
	}
}

- (void) showError: (NSString*) errorMessage {
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle: @"Error" message: errorMessage preferredStyle: UIAlertControllerStyleAlert];
	UIAlertAction *okAction = [UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleDefault handler: nil];
	[alertController addAction: okAction];
	[self presentViewController: alertController animated: YES completion: nil];
}

- (void) bambuserError: (enum BambuserError)errorCode message:(NSString*)errorMessage {
	switch (errorCode) {
		case kBambuserErrorServerFull:
		case kBambuserErrorIncorrectCredentials:
		case kBambuserErrorConnectionLost:
		case kBambuserErrorUnableToConnect:
		case kBambuserErrorBroadcastTicketFailed:
			// Enable broadcastbutton on connection error
			[self performSelectorOnMainThread:@selector(broadcastButtonBroadcast) withObject:nil waitUntilDone:YES];
			break;
		case kBambuserErrorServerDisconnected:
		case kBambuserErrorLocationDisabled:
		case kBambuserErrorNoCamera:
		default:
			break;
	}
	[self performSelectorOnMainThread:@selector(showError:) withObject:errorMessage waitUntilDone:NO];
}

- (void) chatMessageReceived:(NSString *)message {
	[bambuserView displayMessage: message];
}

- (void) talkbackRequest: (NSString*) request caller: (NSString*) caller talkbackID: (int) talkbackID {
	UIAlertController *talkbackRequest = [UIAlertController alertControllerWithTitle: caller message: request preferredStyle :UIAlertControllerStyleAlert];
	UIAlertAction *acceptAlert = [UIAlertAction actionWithTitle: @"Accept" style: UIAlertActionStyleDefault handler: ^(UIAlertAction * _Nonnull action) {
		[self->bambuserView acceptTalkbackRequest: (int) talkbackID];
	}];
	UIAlertAction *declineAlert = [UIAlertAction actionWithTitle: @"Decline" style: UIAlertActionStyleDestructive handler: ^(UIAlertAction * _Nonnull action) {
		[self->bambuserView declineTalkbackRequest: (int) talkbackID];
	}];
	[talkbackRequest addAction: acceptAlert];
	[talkbackRequest addAction: declineAlert];

	[self presentViewController: talkbackRequest animated: YES completion: nil];
}

- (void) talkbackStateChanged: (enum TalkbackState)state {
	// Update label showing talkback state
	switch (state) {
		case kTalkbackNeedsAccept:
			talkbackStatus.text = @"Talkback pending";
			break;
		case kTalkbackAccepted:
			talkbackStatus.text = @"Talkback accepted";
			break;
		case kTalkbackPlaying:
			talkbackStatus.text = @"Talkback playing";
			break;
		default:
			talkbackStatus.text = @"";
	}

	// Add or remove button for ending talkback
	if (state == kTalkbackPlaying) {
		endTalkbackButton = [UIButton buttonWithType: UIButtonTypeRoundedRect];
		[endTalkbackButton addTarget: bambuserView action:@selector(endTalkback) forControlEvents:UIControlEventTouchUpInside];
		float statusBarOffset = self.topLayoutGuide.length;
		endTalkbackButton.frame = CGRectMake(0, 150 + statusBarOffset, 100, 50);
		[endTalkbackButton setTitle:@"End talkback" forState: UIControlStateNormal];
		[self.view addSubview:endTalkbackButton];
	} else if (endTalkbackButton != nil) {
		[endTalkbackButton removeFromSuperview];
		endTalkbackButton = nil;
	}
}

- (void) currentViewerCountUpdated: (int) viewers {
	currentViewersLabel.text = [NSString stringWithFormat: @"Viewers: %d", viewers];
}

- (void) totalViewerCountUpdated: (int) viewers {
	NSLog(@"Total viewers: %d", viewers);
}

-(void) uploadStarted: (NSNumber*) async {
	uploadAlertController = [UIAlertController alertControllerWithTitle: @"Uploading" message: @"" preferredStyle:UIAlertControllerStyleAlert];

	if ([async boolValue]) {
		UIAlertAction *cancel = [UIAlertAction actionWithTitle: @"Cancel" style: UIAlertActionStyleCancel handler: ^(UIAlertAction * _Nonnull action) {
			[self uploadEnded];
			[self->fileUploader cancelUpload];
		}];
		[uploadAlertController addAction: cancel];
	}
	progressBar = [[UIProgressView alloc] initWithFrame:CGRectMake(25.0f, 60.0f, 230.0f, 90.0f)];
	[progressBar setProgressViewStyle: UIProgressViewStyleBar];
	[uploadAlertController.view addSubview: progressBar];
	[self presentViewController: uploadAlertController animated:YES completion: nil];
}

-(void) uploadUpdated: (NSNumber*) progress {
	[progressBar setProgress: [progress floatValue]];
}

-(void) uploadEnded {
	[uploadAlertController dismissViewControllerAnimated: YES completion: nil];
	uploadAlertController = nil;
	progressBar = nil;
}

-(void) uploadFailed {
	[uploadAlertController dismissViewControllerAnimated: YES completion: nil];
	uploadAlertController = nil;
	progressBar = nil;
	[self performSelectorOnMainThread:@selector(showError:) withObject:@"Upload failed" waitUntilDone:NO];
}

@end
