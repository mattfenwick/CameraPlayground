//
//  VideoWriter.m
//  CameraPlayground
//
//  Created by MattF on 2/10/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import "VideoWriter.h"


@interface VideoWriter ()

@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic) BOOL sourceTimeWrittenToMovie;

@end


@implementation VideoWriter

- (instancetype)initWithURL:(NSURL *)url audioOutput:(AVCaptureAudioDataOutput *)audioOutput videoOutput:(AVCaptureVideoDataOutput *)videoOutput
{
    self = [super init];
    if (self)
    {
        NSError *error;
        self.writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        if (error) return nil;
        
        NSMutableDictionary *videoSettings = [[videoOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] mutableCopy];
        NSMutableDictionary *audioSettings = [[audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] mutableCopy];
        
        self.audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        self.audioInput.expectsMediaDataInRealTime = YES;
        if (![self.writer canAddInput:self.audioInput])
        {
            return nil;
        }
        [self.writer addInput:self.audioInput];
        
        NSMutableDictionary *newVideoSettings = [videoSettings mutableCopy];
        NSMutableDictionary *newVideoProperties = [newVideoSettings[AVVideoCompressionPropertiesKey] mutableCopy];
        newVideoProperties[AVVideoMaxKeyFrameIntervalDurationKey] = @(0.25);
        newVideoSettings[AVVideoCompressionPropertiesKey] = newVideoProperties;
        // does this work with the videoSettings stuff?  there was a lot of mumbo-jumbo about this in UBCameraViewController
/*        videoSettings[AVVideoCompressionPropertiesKey][AVVideoMaxKeyFrameIntervalDurationKey] = @(0.25); */
        self.videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:newVideoSettings];
        self.videoInput.expectsMediaDataInRealTime = YES;
        if (![self.writer canAddInput:self.videoInput])
        {
            return nil;
        }
        [self.writer addInput:self.videoInput];
        // some more fields
        self.sourceTimeWrittenToMovie = NO;
        self.frameCount = 0;
        self.droppedFrameIndices = [NSMutableArray array];
        self.audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
        self.videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    }
    return self;
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"recording: %d", self.recording);
    if (!self.recording) return;
    
    CFRetain(sampleBuffer);
    if (connection == self.videoConnection)
    {
        if (!self.sourceTimeWrittenToMovie)
        {
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
        self.frameCount++;
    }
    else if (connection == self.audioConnection)
    {
        if (self.audioInput.readyForMoreMediaData)
        {
            if (![self.audioInput appendSampleBuffer:sampleBuffer])
            {
                // DLog(@"%@", [self.writer error]);
            }
        }
        // else -- ???
    }
    else
    {
        // ?? shouldn't have happened
    }
    CFRelease(sampleBuffer);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    self.frameCount++;
    [self.droppedFrameIndices addObject:[NSNumber numberWithInteger:self.frameCount]];
//    CFShow(sampleBuffer);
}


#pragma mark - AVCaptureFileOutputRecordingDelegate -- this is only if you're using an AVCaptureMovieFileOutput

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
