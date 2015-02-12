//
//  VideoWriter.h
//  CameraPlayground
//
//  Created by MattF on 2/10/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;


// argh, I hate that the audio and video delegates have the same methods names
@interface VideoWriter : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

- (instancetype)initWithURL:(NSURL *)url audioOutput:(AVCaptureAudioDataOutput *)audioSettings videoOutput:(AVCaptureVideoDataOutput *)videoOutput;

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic) NSInteger frameCount;
@property (nonatomic, strong) NSMutableArray *droppedFrameIndices;
@property (nonatomic) BOOL recording;

@end
