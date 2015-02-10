//
//  ViewController.m
//  CameraPlayground
//
//  Created by Matthew Fenwick on 2/6/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//
@import AVFoundation;
#import "ViewController.h"
#import "CameraPicker.h"


@interface ViewController ()

@property (nonatomic, strong) IBOutlet UIButton *record;
@property (nonatomic, strong) IBOutlet UIView *previewView;
@property (nonatomic, strong) IBOutlet UIPickerView *camerasPicker;
@property (nonatomic, strong) CameraPicker *camerasController;

@property (nonatomic, strong) AVCaptureDevice *camera;

@end


static void *IsAdjustingFocusingContext = &IsAdjustingFocusingContext;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.camerasController = [[CameraPicker alloc] init];
    self.camerasController.selectionDidChange = ^(NSInteger row)
    {
        NSLog(@"hopefully, eventually, this sets the camera");
    };
    self.camerasPicker.delegate = self.camerasController;
    self.camerasPicker.dataSource = self.camerasController;
    [self inspectDevices];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)focusExposureTapped:(id)sender
{
    NSError *error;
    if ([self.camera lockForConfiguration:&error])
    {
        CGRect screen = [UIApplication sharedApplication].keyWindow.bounds;
        NSLog(@"screen: %@", NSStringFromCGRect(screen));
        CGPoint middle = CGPointMake(screen.size.width / 2.0, screen.size.height / 2.0);
        [self.camera setFocusPointOfInterest:middle];
        [self.camera setFocusMode:AVCaptureFocusModeAutoFocus];
        [self.camera setExposurePointOfInterest:middle];
        [self.camera setExposureMode:AVCaptureExposureModeAutoExpose];
        [self.camera unlockForConfiguration];
    }
}

- (IBAction)recordTapped:(id)sender
{
    NSLog(@"record");
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    NSArray *audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    NSLog(@"audo devices: %lu  %@", (unsigned long)[audioDevices count], audioDevices);
    if ([audioDevices count] > 0)
    {
        AVCaptureDevice *audioDevice = audioDevices[0];
        AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
        if (!audioInput || ![session canAddInput:audioInput])
        {
            return;
        }
        [session addInput:audioInput];
    }
/*
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
//    dispatch_release(audioCaptureQueue);
    if (![session canAddOutput:audioOutput])
    {
        return;
    }
    [session addOutput:audioOutput];
    AVCaptureConnection *audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
 */
    AVCaptureDevicePosition position = AVCaptureDevicePositionBack;
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *camera = nil;
    for (AVCaptureDevice *device in videoDevices)
    {
        if ([device position] == position)
        {
            camera = device;
            break;
        }
    }
    if (!camera) return;
    [camera lockForConfiguration:nil];
    if ([camera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) camera.focusMode = AVCaptureFocusModeAutoFocus;
    if ([camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) camera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    if ([camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) camera.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
    if ([camera isLowLightBoostSupported]) camera.automaticallyEnablesLowLightBoostWhenAvailable = YES;
    [camera unlockForConfiguration];
    [camera addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:IsAdjustingFocusingContext];
    AVCaptureDeviceInput *cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:nil];
    if (!cameraInput || ![session canAddInput:cameraInput]) return;
    [session addInput:cameraInput];
    self.camera = camera;
    // TODO set the FPS
/*
    AVCaptureVideoDataOutput *cameraOutput = [[AVCaptureVideoDataOutput alloc] init];
    [cameraOutput setAlwaysDiscardsLateVideoFrames:NO];
    if (![session canAddOutput:cameraOutput]) return;
    [session addOutput:cameraOutput];
    AVCaptureConnection *videoConnection = [cameraOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([videoConnection isVideoStabilizationSupported])
    {
        [videoConnection setEnablesVideoStabilizationWhenAvailable:YES];
    }
    dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [cameraOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
//    dispatch_release(videoCaptureQueue);
*/
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//    previewLayer.frame = CGRectMake(0, 0, 200, 200);
    previewLayer.frame = [UIApplication sharedApplication].keyWindow.frame;
    NSLog(@"%@", NSStringFromCGRect(previewLayer.frame));
    CALayer *viewLayer = [self.previewView layer];
    [viewLayer setMasksToBounds:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewLayer addSublayer:previewLayer];
    });
    
    [session startRunning];
    /*
    NSError *error;
    NSURL *url = [[NSURL alloc] initFileURLWithPath:@"myvideo.mp4"];
    AVAssetWriter *assetWriter = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    if (error) return;
    
    NSMutableDictionary *newSettings = [[cameraOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] mutableCopy];
    NSMutableDictionary *newProperties = [[newSettings objectForKey:AVVideoCompressionPropertiesKey] mutableCopy];
    newProperties[AVVideoMaxKeyFrameIntervalDurationKey] = @(0.25);
    [newSettings setObject:newProperties forKey:AVVideoCompressionPropertiesKey];
    
    NSLog(@"%@", newSettings);
    
    AVAssetWriterInput *assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:newSettings];
    assetWriterVideoIn.expectsMediaDataInRealTime = YES;
    
    if (![assetWriter canAddInput:assetWriterVideoIn]) return;
    
    NSDictionary *recommendedSettings = [audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    AVAssetWriterInput *assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:recommendedSettings];
    assetWriterAudioIn.expectsMediaDataInRealTime = YES;
    if (![assetWriter canAddInput:assetWriterAudioIn]) return;
    
    _sourceTimeWrittenToMovie = NO;
    if (![assetWriter startWriting]) return;
    */
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"keyPath: %@  obj: %@  change: %@", keyPath, object, change);
}

- (void)inspectDevices
{
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        NSLog(@"device: %@", device);
        [self checkOutCameraSettings:device];
    }
}

- (void)checkOutCameraSettings:(AVCaptureDevice *)device
{
    for (AVCaptureDeviceFormat *format in [device formats])
    {
        CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions([format formatDescription]);
        NSLog(@"resolution: width %d  height %d  %f  %f  %f  %d  %d  %f  %d  %f",//  %f  %f  %f  %d  %@  %f  %@  %f",
                dims.width, dims.height,
//              format.formatDescription,
              format.videoFieldOfView,
              format.videoMaxZoomFactor,
              format.videoZoomFactorUpscaleThreshold,
              format.videoHDRSupported,
              format.maxExposureDuration,
              format.maxISO,
              format.minExposureDuration,
              format.minISO);
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges)
        {
            NSLog(@"min: %f    max: %f", range.minFrameRate, range.maxFrameRate);
        }
        NSLog(@"");
    }
    NSLog(@"done checking out camera settings");
}

@end
