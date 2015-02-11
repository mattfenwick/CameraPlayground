//
//  VideoWriter.h
//  CameraPlayground
//
//  Created by MattF on 2/10/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;


// argh, I hate that the audio and video delegates have the same names
@interface VideoWriter : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate>

- (instancetype)initWithURL:(NSURL *)url audioSettings:(NSMutableDictionary *)audioSettings videoSettings:(NSMutableDictionary *)videoSettings;

- (BOOL)startWriting;

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, strong) id<AVCaptureAudioDataOutputSampleBufferDelegate> audioSampleBufferDelegate;

@end
