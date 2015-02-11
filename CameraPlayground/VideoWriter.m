//
//  VideoWriter.m
//  CameraPlayground
//
//  Created by MattF on 2/10/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import "VideoWriter.h"


@interface AudioSampleBufferDelegate : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>

- (instancetype)initWithWriterInput:(AVAssetWriterInput *)audioInput;

@property (nonatomic, strong) AVAssetWriterInput *audioInput;

@end


@implementation AudioSampleBufferDelegate

- (instancetype)initWithWriterInput:(AVAssetWriterInput *)audioInput
{
    self = [super init];
    if (self)
    {
        self.audioInput = audioInput;
    }
    return self;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    return;
    CFRetain(sampleBuffer);
    if (self.audioInput.readyForMoreMediaData)
    {
        if (![self.audioInput appendSampleBuffer:sampleBuffer])
        {
            // DLog(@"%@", [self.writer error]);
        }
    }
    // else -- ???
    CFRelease(sampleBuffer);
}

@end


@interface VideoWriter ()

@property (nonatomic) BOOL sourceTimeWrittenToMovie;
@property (nonatomic) NSInteger droppedFrameCount;

@end


@implementation VideoWriter

- (instancetype)initWithURL:(NSURL *)url audioSettings:(NSMutableDictionary *)audioSettings videoSettings:(NSMutableDictionary *)videoSettings
{
    self = [super init];
    if (self)
    {
        NSError *error;
        self.writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        if (error) return nil;
        
        self.audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        self.audioInput.expectsMediaDataInRealTime = YES;
        if (![self.writer canAddInput:self.audioInput])
        {
            return nil;
        }
        [self.writer addInput:self.audioInput];
        
        // does this work with the videoSettings stuff?  there was a lot of mumbo-jumbo about this in UBCameraViewController
        videoSettings[AVVideoCompressionPropertiesKey][AVVideoMaxKeyFrameIntervalDurationKey] = @(0.25);
        self.videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        self.videoInput.expectsMediaDataInRealTime = YES;
        if (![self.writer canAddInput:self.videoInput])
        {
            return nil;
        }
        [self.writer addInput:self.videoInput];
        // some more fields
        self.sourceTimeWrittenToMovie = NO;
        self.droppedFrameCount = 0;
        self.audioSampleBufferDelegate = [[AudioSampleBufferDelegate alloc] initWithWriterInput:self.audioInput];
    }
    return self;
}

- (BOOL)startWriting
{
    return [self.writer startWriting];
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CFRetain(sampleBuffer);
        if (!self.sourceTimeWrittenToMovie)
        {
            self.droppedFrameCount = 0;
            self.sourceTimeWrittenToMovie = YES;
            CMTime sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.writer startSessionAtSourceTime:sourceTime];
            NSLog(@"started session at source time called");
        }
        if (self.videoInput.readyForMoreMediaData)
        {
            if (![self.videoInput appendSampleBuffer:sampleBuffer])
            {
                // DLog(@"%@", [self.writer error];
            }
        }
        // else -- ???
    CFRelease(sampleBuffer);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //
}


#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    if ([error code] != noErr)
    {
        // A problem occurred: Find out if the recording was successful.
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value)
        {
            if (![value boolValue])
            {
                return; // oops
            }
        }
    }
    
    NSLog(@"do I need to do anything else here?");
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    
}

@end
