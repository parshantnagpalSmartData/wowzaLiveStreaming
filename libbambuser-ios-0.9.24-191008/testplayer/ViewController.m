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

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	bambuserPlayer = [[BambuserPlayer alloc] init];
	bambuserPlayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	bambuserPlayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	bambuserPlayer.delegate = self;
	bambuserPlayer.applicationId = @"CHANGEME";
	[self.view addSubview: bambuserPlayer];
	// This is a sample video; you can get a similarly signed resource URI for your broadcasts via the
	// Bambuser Metadata API.
	[bambuserPlayer playVideo: @"https://cdn.bambuser.net/broadcasts/ec968ec1-2fd9-f8f3-4f0a-d8e19dccd739?da_signature_method=HMAC-SHA256&da_id=432cebc3-4fde-5cbb-e82f-88b013140ebe&da_timestamp=1456740399&da_static=1&da_ttl=0&da_signature=8e0f9b98397c53e58f9d06d362e1de3cb6b69494e5d0e441307dfc9f854a2479"];

	play = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[play setFrame: CGRectMake(10, 10, 100, 50)];
	[play setTitle: @"Play" forState:UIControlStateNormal];
	[play addTarget:bambuserPlayer action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];
	play.enabled = NO;
	[self.view addSubview: play];

	pause = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[pause setFrame: CGRectMake(10, 60, 100, 50)];
	[pause setTitle: @"Pause" forState:UIControlStateNormal];
	[pause addTarget:bambuserPlayer action:@selector(pauseVideo) forControlEvents:UIControlEventTouchUpInside];
	pause.enabled = NO;
	[self.view addSubview: pause];

	stop = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[stop setFrame: CGRectMake(10, 110, 100, 50)];
	[stop setTitle: @"Stop" forState:UIControlStateNormal];
	[stop addTarget:bambuserPlayer action:@selector(stopVideo) forControlEvents:UIControlEventTouchUpInside];
	stop.enabled = NO;
	[self.view addSubview: stop];

	slider = [[UISlider alloc] initWithFrame: CGRectMake(10,200,self.view.frame.size.width - 20,10)];
	[slider addTarget: self action:@selector(seekTo:) forControlEvents:UIControlEventTouchUpInside];
	slider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
	slider.enabled = NO;
	slider.hidden = YES;
	[self.view addSubview: slider];

	currentViewersLabel = [[UILabel alloc] init];
	currentViewersLabel.textAlignment = NSTextAlignmentLeft;
	currentViewersLabel.text = @"";
	currentViewersLabel.font = [UIFont systemFontOfSize:16];
	currentViewersLabel.backgroundColor = [UIColor clearColor];
	currentViewersLabel.textColor = [UIColor blueColor];
	[self.view addSubview: currentViewersLabel];

	latencyLabel = [[UILabel alloc] init];
	latencyLabel.textAlignment = NSTextAlignmentLeft;
	latencyLabel.text = @"";
	latencyLabel.font = [UIFont systemFontOfSize:16];
	latencyLabel.backgroundColor = [UIColor clearColor];
	latencyLabel.textColor = [UIColor blueColor];
	[self.view addSubview: latencyLabel];

	// Do any additional setup after loading the view, typically from a nib.
}

- (void) viewWillLayoutSubviews {
	currentViewersLabel.frame = CGRectMake(self.view.bounds.size.width - 100, self.view.bounds.size.height - 30, 100, 30);
	latencyLabel.frame = CGRectMake(15, self.view.bounds.size.height - 30, 150, 30);
}

- (void) durationKnown:(double)duration {
	NSLog(@"Got duration: %f", duration);
	slider.minimumValue = 0;
	slider.maximumValue = duration;
	if (!bambuserPlayer.live) {
		slider.enabled = YES;
		slider.hidden = NO;
	}
}

- (void) seekTo: (id) sender {
	float time = slider.value;
	NSLog(@"Seeking to %f", time);
	[bambuserPlayer seekTo: time];
}

- (void) videoLoadFail {
	NSLog(@"videoLoadFail called");
}

- (void) playbackStatusChanged: (enum BambuserPlayerState) status {
	switch (status) {
		case kBambuserPlayerStatePlaying:
			NSLog(@"status: kBambuserPlayerStatePlaying");
			stop.enabled = YES;
			if (!bambuserPlayer.live) {
				pause.enabled = YES;
			}
			play.enabled = NO;
			seekerTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
			latencyTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateLatency) userInfo:nil repeats:YES];
			break;
		case kBambuserPlayerStatePaused:
			NSLog(@"status: kBambuserPlayerStatePaused");
			[seekerTimer invalidate];
			[latencyTimer invalidate];
			pause.enabled = NO;
			play.enabled = YES;
			currentViewersLabel.text = @"";
			latencyLabel.text = @"";
			break;
		case kBambuserPlayerStateStopped:
			NSLog(@"status: kBambuserPlayerStateStopped");
			[seekerTimer invalidate];
			[latencyTimer invalidate];
			stop.enabled = NO;
			pause.enabled = NO;
			play.enabled = NO;
			currentViewersLabel.text = @"";
			latencyLabel.text = @"";
			break;
		default:
			break;
	}
}

- (void) updateSlider {
	if (!slider.isTracking)
		slider.value = bambuserPlayer.playbackPosition;
}

- (void) updateLatency {
	LatencyMeasurement latency = bambuserPlayer.endToEndLatency;
	if (latency.uncertainty >= 0)
		latencyLabel.text = [NSString stringWithFormat: @"Latency: %.2f s", latency.latency];
	else
		latencyLabel.text = @"";
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void) currentViewerCountUpdated: (int) viewers {
	currentViewersLabel.text = [NSString stringWithFormat: @"Viewers: %d", viewers];
}

- (void) totalViewerCountUpdated: (int) viewers {
	NSLog(@"Total viewers: %d", viewers);
}

@end
