//
//  ViewController.m
//  CameraPlayground
//
//  Created by Matthew Fenwick on 2/6/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//
@import AVFoundation;
#import "ViewController.h"


@interface ViewController ()

@property (nonatomic, strong) IBOutlet UIButton *record;
@property (nonatomic, strong) IBOutlet UIView *previewLayer;

@end


static void *IsAdjustingFocusingContext = &IsAdjustingFocusingContext;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordTapped:(id)sender
{
    NSLog(@"record");
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    NSArray *audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
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
    // TODO previewLayer framesize and orientation?
    CALayer *viewLayer = [self.previewLayer layer];
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
    
    NSMutableDictionary *newSettings =  [[cameraOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] mutableCopy];
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

@end
