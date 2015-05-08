#import "CameraController.h"
#import <MobileCoreServices/UTCoreTypes.h>
@import AVFoundation;

#define MAX_ZOOM 3.5

static void *IsAdjustingFocusingContext = &IsAdjustingFocusingContext;
static void *IsAdjustingExposureContext = &IsAdjustingExposureContext;

typedef NS_ENUM(NSInteger, CameraControllerState)
{
    CameraControllerStateUninitialized,
    CameraControllerStateInitializing,
    CameraControllerStateReady,
    CameraControllerStateStartingRecording,
    CameraControllerStateRecording,
    CameraControllerStatePaused,
    CameraControllerStateStoppingRecording,
    CameraControllerStateError
};

#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface CameraController () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *audioDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *cameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic) AVCaptureVideoOrientation videoOrientation;

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;

@property (nonatomic, strong) NSURL *fileURL;

@property (nonatomic) dispatch_queue_t videoWritingQueue;
@property (nonatomic) dispatch_queue_t audioWritingQueue;

@property (nonatomic, strong) NSDate *currentRecordingStartTime;

@property (nonatomic) BOOL zoomEnabled;
@property (nonatomic) CGFloat pauseStartTime;
@property (nonatomic) CGFloat presentationTimeAdjustment;
@property (nonatomic) BOOL sourceTimeWrittenToMovie;

@property (nonatomic) NSInteger droppedFrameCount;
@property (nonatomic, strong) NSMutableArray *droppedFrameIndices;
@property (nonatomic) NSInteger frameIndex;

@property (nonatomic) CameraControllerState state;

@end


@implementation CameraController

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.state = CameraControllerStateInitializing;
        self.videoWritingQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
        self.audioWritingQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
        self.state = CameraControllerStateUninitialized;
    }
    return self;
}

- (void)dealloc
{
    DLog(@"dealloc CameraController");
    [self.previewLayer removeFromSuperlayer];
    [self.session stopRunning];
    [self.session removeInput:self.cameraInput];
    [self.session removeInput:self.audioInput];
    self.camera = nil;
}

#pragma mark - initialization

- (CameraControllerError)initializeAVCaptureSessionWithCameraPosition:(AVCaptureDevicePosition)cameraPosition
{
//    if (self.state != CameraControllerStateUninitialized) return CameraControllerErrorInvalidState;

    self.state = CameraControllerStateInitializing;
    CameraControllerError error = [self initializeAVCaptureSessionWithCameraPositionHelper:cameraPosition];
    self.state = (error != CameraControllerErrorNone) ? CameraControllerStateReady : CameraControllerStateError;
    return error;
}

- (CameraControllerError)initializeAVCaptureSessionWithCameraPositionHelper:(AVCaptureDevicePosition)cameraPosition
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if (!devices || [devices count] == 0) return CameraControllerErrorNoAudioDeviceFound;
    self.audioDevice = devices[0];
    self.camera = [self getCamera:cameraPosition];
    if (!self.camera) return CameraControllerErrorNoVideoDeviceFound;

    self.session = [[AVCaptureSession alloc] init];
    
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:nil];
    if (!self.audioInput || ![self.session canAddInput:self.audioInput]) return CameraControllerErrorUnableToAddAudioInput;
    [self.session addInput:self.audioInput];
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    if (!self.audioOutput || ![self.session canAddOutput:self.audioOutput]) return CameraControllerErrorUnableToAddAudioOutput;
    [self.session addOutput:self.audioOutput];
    self.audioConnection = [self.audioOutput connectionWithMediaType:AVMediaTypeAudio];
    
    self.cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.camera error:nil];
    if (!self.cameraInput || ![self.session canAddInput:self.cameraInput]) return CameraControllerErrorUnableToAddVideoInput;
    [self.session addInput:self.cameraInput];
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    if (![self.session canAddOutput:self.videoOutput]) return CameraControllerErrorUnableToAddVideoOutput;
    [self.session addOutput:self.videoOutput];
    
    self.videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];

    // TODO does this always succeed?
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    
    [self.session startRunning];
    
    return CameraControllerErrorNone;
}

- (CameraControllerError)initializeAVAssetWriter:(NSURL *)fileURL
{
    DLog(@"initializeAVAssetWriter");
    // TODO is this necessary ?  maybe if we blow away the assetWriter without using it (i.e. switching cameras)
    if (self.assetWriter) [self.assetWriter cancelWriting];
    
    // files have a .mp4 container but have a .mov extension for backward compatability.
    NSError *error;
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeMPEG4 error:&error];
    if (error) return CameraControllerErrorUnableToCreateAssetWriter;
    
    // Set custom meta data marking this as an Ubersense video that is already rotated
    [self setCustomMetaDataOnAsset:self.assetWriter];
    
    NSMutableDictionary *newSettings = [[self.videoOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] mutableCopy];
    NSMutableDictionary *newProperties = [[newSettings objectForKey:AVVideoCompressionPropertiesKey] mutableCopy];
    newProperties[AVVideoMaxKeyFrameIntervalDurationKey] = @(0.25);
    [newSettings setObject:newProperties forKey:AVVideoCompressionPropertiesKey];
    
    DLog(@"%@", newSettings);
    
    self.assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:newSettings];
    self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
    
    if (![self.assetWriter canAddInput:self.assetWriterVideoInput]) return CameraControllerErrorUnableToAddAssetWriterVideoInput;
    [self.assetWriter addInput:self.assetWriterVideoInput];
    
    NSDictionary *recommendedSettings = [self.audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    self.assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:recommendedSettings];
    self.assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    if (![self.assetWriter canAddInput:self.assetWriterAudioInput]) return CameraControllerErrorUnableToAddAssetWriterAudioInput;
    [self.assetWriter addInput:self.assetWriterAudioInput];
    
    [self.videoOutput setSampleBufferDelegate:self queue:self.videoWritingQueue];
    [self.audioOutput setSampleBufferDelegate:self queue:self.audioWritingQueue];
    
    self.sourceTimeWrittenToMovie = NO;
    return [self.assetWriter startWriting] ? CameraControllerErrorNone : CameraControllerErrorUnableToStartWriting;
}


#pragma mark - configuration

- (CameraControllerError)setVideoAVCaptureOrientation:(AVCaptureVideoOrientation)orientation
{
//    if (self.state != CameraControllerStateReady) return CameraControllerErrorInvalidState;
    
    self.videoConnection.videoOrientation = orientation;
    //    self.previewLayer.connection.videoOrientation = orientation;
    self.videoOrientation = orientation;
    return CameraControllerErrorNone;
}

- (void)cleanUpCameraInputAndOutput
{
    [self.session removeInput:self.cameraInput];
    [self.session removeOutput:self.videoOutput];
}

- (CameraControllerError)setCameraWithPosition:(AVCaptureDevicePosition)position
{
//    if (self.state != CameraControllerStateReady) return CameraControllerErrorInvalidState;
    
    AVCaptureDevice *newCamera = [self getCamera:position];
    if (newCamera == nil) return CameraControllerErrorNoVideoDeviceFound;
    
    [self.session beginConfiguration];
    
    [self cleanUpCameraInputAndOutput];

    self.camera = newCamera;
    
    self.cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.camera error:nil];
    if (!self.cameraInput || ![self.session canAddInput:self.cameraInput]) return CameraControllerErrorUnableToAddVideoInput;
    [self.session addInput:self.cameraInput];
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    if (![self.session canAddOutput:self.videoOutput]) return CameraControllerErrorUnableToAddVideoOutput;
    [self.session addOutput:self.videoOutput];
    
    self.videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    // we're not *changing* the orientation, just setting the orientation of a new connection
    //   so we don't need to re-set-up the AVAssetWriter
    self.videoConnection.videoOrientation = self.videoOrientation;
    
    [self.session commitConfiguration];
    return CameraControllerErrorNone;
}

- (CameraControllerError)setActiveFormat:(AVCaptureDeviceFormat *)format
{
//    if (self.state != CameraControllerStateReady) return CameraControllerErrorInvalidState;

    if ([[self.camera formats] containsObject:format])
    {
        if ([self.camera lockForConfiguration:nil])
        {
            self.camera.activeFormat = format;
            [self.camera unlockForConfiguration];
            return CameraControllerErrorNone;
        }
        else
        {
            return CameraControllerErrorUnableToLockForConfig;
        }
    }
    else
    {
        return CameraControllerErrorInvalidFormat;
    }
}


#pragma mark - start/pause/resume/stop recording

- (CameraControllerError)startRecordingWithFileURL:(NSURL *)fileURL
{
//    if (self.state != CameraControllerStateReady) return CameraControllerErrorInvalidState;
    
    self.fileURL = fileURL;
    CameraControllerError error = [self initializeAVAssetWriter:self.fileURL];
    if (error != CameraControllerErrorNone) return error;
    
    self.droppedFrameIndices = [NSMutableArray array];
    self.frameIndex = 1;

    self.currentRecordingStartTime = [NSDate date];
    
    self.recording = YES;
    return CameraControllerErrorNone;
}

- (CameraControllerError)pauseRecording
{
//    if (self.state != CameraControllerStateRecording) return CameraControllerErrorInvalidState;

    self.recording = NO;
    self.pauseStartTime = CACurrentMediaTime();
    return CameraControllerErrorNone;
}

- (CameraControllerError)resumeRecording
{
//    if (self.state != CameraControllerStatePaused) return CameraControllerErrorInvalidState;
    
    self.recording = YES;
    self.presentationTimeAdjustment += CACurrentMediaTime() - self.pauseStartTime;
    return CameraControllerErrorNone;
}

- (CameraControllerError)stopRecording
{
//    if (self.state != CameraControllerStateRecording) return CameraControllerErrorInvalidState;
    
    self.state = CameraControllerStateStoppingRecording;
    self.recording = NO;

    [self.videoOutput setSampleBufferDelegate:nil queue:NULL];
    [self.audioOutput setSampleBufferDelegate:nil queue:NULL];
    DLog(@"stop recording -- %ld %@", self.assetWriter.status, self.assetWriter.error);
    dispatch_async(self.videoWritingQueue, ^{
        [self.assetWriter finishWritingWithCompletionHandler:^{
            [self.delegate finishedRecordingWithURL:self.assetWriter.outputURL status:self.assetWriter.status];
            self.state = CameraControllerStateReady;
        }];
    });
    DLog(@"number of dropped frames - %li, %@", (long)self.droppedFrameCount, self.droppedFrameIndices);
    return CameraControllerErrorNone;
}

#pragma mark - zoom

- (void)decideIfZoomIsAvailable
{
    CGFloat maxZoom = MIN( self.camera.activeFormat.videoMaxZoomFactor, MAX_ZOOM );
    self.zoomEnabled = maxZoom != 1;
}

- (void)setZoomFactor:(CGFloat)zoomFactor
{
    if ([self.camera lockForConfiguration:nil])
    {
        self.camera.videoZoomFactor = zoomFactor;
        [self.camera unlockForConfiguration];
    }
}


#pragma mark - get camera

- (AVCaptureDevice *)getCamera:(AVCaptureDevicePosition)position
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *camera = nil;
    for (camera in cameras)
    {
        if ([camera position] == position) break;
    }
    
    if (!camera) return nil;
    
    [camera lockForConfiguration:nil];
    
    if (camera.focusPointOfInterestSupported)
    {
        camera.focusPointOfInterest = CGPointMake(0.5, 0.5);
    }
    if (camera.exposurePointOfInterestSupported)
    {
        camera.exposurePointOfInterest = CGPointMake(0.5, 0.5);
    }
    if ([camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
    {
        camera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    if ([camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
    {
        camera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    }
    if ([camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance])
    {
        camera.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
    }
    if ([camera isLowLightBoostSupported])
    {
        camera.automaticallyEnablesLowLightBoostWhenAvailable = YES;
    }
    [camera unlockForConfiguration];
    
    return camera;
}


#pragma mark - helpers and miscellaneous

- (void)setCustomMetaDataOnAsset:(AVAssetWriter *)writer
{
    NSMutableArray *newMetadataArray = writer.metadata ? [writer.metadata mutableCopy] : [[NSMutableArray alloc] init];
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.keySpace = AVMetadataKeySpaceCommon;
    item.key = AVMetadataCommonKeyAuthor;
    item.value = @"Ubersense";
    [newMetadataArray addObject:item];
    writer.metadata = newMetadataArray;
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.recording) return;
    
    if (connection == self.videoConnection)
    {
        self.frameIndex++;
    }
    
    CFRetain(sampleBuffer);
    
    if (self.presentationTimeAdjustment > 0)
    {
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp( sampleBuffer );
        // Adjust the presentation time for the frame
        CMTime adjustmentTime = CMTimeMake(ceil(_presentationTimeAdjustment * presentationTime.timescale), presentationTime.timescale);
        CFRelease(sampleBuffer);
        sampleBuffer = [self adjustTime:sampleBuffer by:adjustmentTime];
    }
    
//    DLog(@"self.videoConnection, connection and sourceTimeWritten: %@ %@ %d", self.videoConnection, connection, self.sourceTimeWrittenToMovie);
    
    // Double check if recording before sending sample buffer for writing
    if (self.recording)
    {
        // Start writing on asset writer only if this sample buffer is a video buffer. Otherwise
        // output video starts with a blank frame corresponding to the audio buffer written first.
        if (connection == self.videoConnection && !self.sourceTimeWrittenToMovie)
        {
            self.droppedFrameCount = 0;
            self.sourceTimeWrittenToMovie = YES;
            
            CMTime sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.assetWriter startSessionAtSourceTime:sourceTime];
            DLog(@"started session");
        }
        
        if (self.assetWriter.status == AVAssetWriterStatusWriting)
        {
            if (connection == self.videoConnection && self.assetWriterVideoInput.readyForMoreMediaData && ![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer])
            {
                DLog(@"%@", [self.assetWriter error]);
            }
            else if (connection == self.audioConnection && self.assetWriterAudioInput.readyForMoreMediaData && ![self.assetWriterAudioInput appendSampleBuffer:sampleBuffer])
            {
                DLog(@"%@", [self.assetWriter error]);
            }
        } // TODO when would this be false?
    }
    CFRelease(sampleBuffer);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    self.droppedFrameCount++;
    [self.droppedFrameIndices addObject:[NSNumber numberWithInteger:self.frameIndex]];
    self.frameIndex++;
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef)sample by:(CMTime)offset
{
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++)
    {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}


#pragma mark - debug aids

- (void)setSourceTimeWrittenToMovie:(BOOL)sourceTimeWrittenToMovie
{
    DLog(@"sourceTime... new value: %d", sourceTimeWrittenToMovie);
    _sourceTimeWrittenToMovie = sourceTimeWrittenToMovie;
}

#pragma mark - setters

- (void)setCamera:(AVCaptureDevice *)camera
{
    [_camera removeObserver:self forKeyPath:@"adjustingFocus"];
    [_camera removeObserver:self forKeyPath:@"adjustingExposure"];
    
    _camera = camera;
    
    [_camera addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:IsAdjustingFocusingContext];
    [_camera addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:IsAdjustingExposureContext];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == IsAdjustingFocusingContext)
    {
        BOOL isAdjusting = [change[NSKeyValueChangeNewKey] boolValue];
        if (isAdjusting && self.camera.focusMode != AVCaptureFocusModeLocked)
        {
            [self.delegate adjustingFocus];
        }
    }
    else if (context == IsAdjustingExposureContext)
    {
        [self.delegate adjustingExposure];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


@end
