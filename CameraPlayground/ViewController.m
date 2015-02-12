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
#import "VideoWriter.h"


@interface ViewController ()

@property (nonatomic, strong) IBOutlet UIButton *record;
@property (nonatomic, strong) IBOutlet UIView *previewView;
@property (nonatomic, strong) IBOutlet UIPickerView *camerasPicker;
@property (nonatomic, strong) CameraPicker *camerasController;
@property (nonatomic, strong) VideoWriter *videoWriter;
@property (nonatomic, strong) dispatch_queue_t videoCaptureQueue;
@property (nonatomic, strong) dispatch_queue_t audioCaptureQueue;

@property (nonatomic, strong) AVCaptureDevice *camera;

@end


static void *IsAdjustingFocusingContext = &IsAdjustingFocusingContext;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.camerasController = [[CameraPicker alloc] init];
    self.camerasController.selectionDidChange = ^(NSInteger row) {
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
    
    if (self.videoWriter)
    {
        NSLog(@"going to stop recording");
        self.videoWriter.recording = NO;

        dispatch_async(self.videoCaptureQueue, ^{
            NSLog(@"going to finish writing");
            [self.videoWriter.writer finishWritingWithCompletionHandler:^{
                NSLog(@"done ... %d frames, %d dropped.  indices: %@", self.videoWriter.frameCount, [self.videoWriter.droppedFrameIndices count], self.videoWriter.droppedFrameIndices);
            }];
        });
        return;
    }
    
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
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    if (![session canAddOutput:videoOutput])
    {
        return;
    }
    [session addOutput:videoOutput];

    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    if (![session canAddOutput:audioOutput])
    {
        return;
    }
    [session addOutput:audioOutput];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] == 0)
    {
        return;
    }
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:@"myvideo.mov"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath])
    {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    NSURL *url = [NSURL fileURLWithPath:filePath];

    VideoWriter *videoWriter = [[VideoWriter alloc] initWithURL:url audioOutput:audioOutput videoOutput:videoOutput];
    videoWriter.recording = YES;
    if (![videoWriter.writer startWriting])
    {
        NSError *error = [videoWriter.writer error];
        NSLog(@"error: %@", error);
        return;
    }
    dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:videoWriter queue:videoCaptureQueue];
//    dispatch_release(videoCaptureQueue); // iOS version thing?
    dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:videoWriter queue:audioCaptureQueue];
//    dispatch_release(audioCaptureQueue);

    self.videoWriter = videoWriter;
    self.videoCaptureQueue = videoCaptureQueue;
    self.audioCaptureQueue = audioCaptureQueue;
}

- (void)cleanUpResources
{
    // TODO
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
