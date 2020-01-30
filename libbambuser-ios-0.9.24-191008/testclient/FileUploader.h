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

#import <Foundation/Foundation.h>

@protocol FileUploaderDelegate <NSObject>
@optional
-(void) uploadStarted: (NSNumber*) async;
-(void) uploadUpdated: (NSNumber*) progress;
-(void) uploadEnded;
-(void) showError: (NSString*) errorMessage;
-(void) uploadFailed;
@end

@interface FileUploader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate> {
	NSURL *uploadURL;
	NSURLSessionDataTask *ticketTask;
	NSURLSessionUploadTask *uploadTask;
	uint64_t filesize;
	NSString *inputFilename;
	BOOL deleteOnCompletion;
	int responseStatus;
	NSDictionary *infoDictionary;
}

@property (nonatomic, weak) NSObject <FileUploaderDelegate> *delegate;
-(id) initWithDelegate: (id) _delegate;
-(void) getTicketAndUpload: (NSDictionary*) assets;
-(void) uploadFile:(NSString *)filename toUploadURL:(NSURL *)ticketUploadURL;
-(void) cancelUpload;
@end
