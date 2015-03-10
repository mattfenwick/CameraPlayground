//
//  ViewController.m
//  CameraPlayground
//
//  Created by Matthew Fenwick on 2/6/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//
@import AVFoundation;
#import "ViewController.h"
#import "CameraController.h"
#import "MWFActionSheet.h"


@interface ViewController () <CameraControllerDelegate>

@property (nonatomic, strong) IBOutlet UIButton *recordButton;
@property (nonatomic, strong) IBOutlet UIButton *focusButton;
@property (nonatomic, strong) IBOutlet UIButton *exposureButton;
@property (nonatomic, strong) IBOutlet UIButton *formatButton;
@property (nonatomic, strong) IBOutlet UIButton *cameraButton;
@property (nonatomic, strong) IBOutlet UIButton *fpsMultiplierButton;
@property (nonatomic, strong) IBOutlet UIButton *whiteBalanceButton;

@property (nonatomic, strong) IBOutlet UISlider *zoomSlider;
@property (nonatomic, strong) IBOutlet UISlider *exposureSlider;

@property (nonatomic, strong) IBOutlet UIView *previewView;
@property (nonatomic, strong) CameraController *cameraController;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic) NSInteger fileCount;

@end


static void *IsAdjustingFocusingContext = &IsAdjustingFocusingContext;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.cameraController = [[CameraController alloc] initWithUsingCustomPipeline:YES];
    CameraControllerError deviceError = [self.cameraController initializeDevicesWithCameraPosition:AVCaptureDevicePositionBack];
    if (deviceError != CameraControllerErrorNone)
    {
        [self reportError:deviceError];
        return;
    }
    CameraControllerError avSessionError = [self.cameraController initializeAVCaptureSession];
    if (avSessionError != CameraControllerErrorNone)
    {
        [self reportError:avSessionError];
        return;
    }
    self.cameraController.delegate = self;
    [self.cameraController setVideoAVCaptureOrientation:[self getVideoOrientation]];
    [self addVideoPreviewLayer];
    self.fileCount = 1;
}

- (void)reportError:(CameraControllerError)error
{
    NSString *str;
    if (error == CameraControllerErrorNone) str = @"none";
    else if (error == CameraControllerErrorInvalidFormat) str = @"invalid format";
    else if (error == CameraControllerErrorNoAudioDeviceFound) str = @"no audio device found";
    else if (error == CameraControllerErrorNoVideoDeviceFound) str = @"no video device found";
    else if (error == CameraControllerErrorUnableToAddAssetWriterAudioInput) str = @"unable to add asset writer audio input";
    else if (error == CameraControllerErrorUnableToAddAssetWriterVideoInput) str = @"unable to add asset writer video input";
    else if (error == CameraControllerErrorUnableToAddAudioInput) str = @"unable to add audio input";
    else if (error == CameraControllerErrorUnableToAddAudioOutput) str = @"unable to add audio output";
    else if (error == CameraControllerErrorUnableToAddFileOutput) str = @"unable to add file output";
    else if (error == CameraControllerErrorUnableToAddVideoInput) str = @"unable to add video input";
    else if (error == CameraControllerErrorUnableToAddVideoOutput) str = @"unable to add video output";
    else if (error == CameraControllerErrorUnableToCreateAssetWriter) str = @"unable to create asset writer";
    else if (error == CameraControllerErrorUnableToLockForConfig) str = @"unable to lock for config";
    else if (error == CameraControllerErrorUnableToStartWriting) str = @"unable to start writing";
    else str = @"unknown error";
    NSLog(@"error -- %@", str);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)addVideoPreviewLayer
{
    self.previewLayer = self.cameraController.previewLayer;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.previewLayer.frame = CGRectMake(0, 0, 400, 400);
//    self.previewLayer.frame = [UIApplication sharedApplication].keyWindow.frame;
    self.previewLayer.connection.videoOrientation = [self getVideoOrientation];
    NSLog(@"previewLayer frame: %@", NSStringFromCGRect(self.previewLayer.frame));
    CALayer *viewLayer = [self.previewView layer];
    [viewLayer setMasksToBounds:YES];
/*    dispatch_async(dispatch_get_main_queue(), ^{
        [viewLayer addSublayer:self.previewLayer];
    });*/
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewLayer insertSublayer:self.previewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
    });
}

#pragma mark - record

- (IBAction)recordTapped:(id)sender
{
    NSLog(@"record");
    
    if (self.cameraController.recording)
    {
        [self.cameraController stopRecording];
    }
    else
    {
        NSURL *url = [self getFileURL];
        if (!url)
        {
            NSLog(@"failed to obtain URL, :(");
            return;
        }
        [self.cameraController setVideoAVCaptureOrientation:[self getVideoOrientation]];
        CameraControllerError error = [self.cameraController startRecordingWithFileURL:url];
        if (error != CameraControllerErrorNone)
        {
            [self reportError:error];
            return;
        }
    }
}

- (NSURL *)getFileURL
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] == 0)
    {
        return nil;
    }
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"myvideo%ld.mov", (long)self.fileCount]];
    self.fileCount++;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath])
    {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    return [NSURL fileURLWithPath:filePath];
}

#pragma mark - focus

- (IBAction)focusTapped:(id)sender
{
    MWFActionSheet *sheet = [[MWFActionSheet alloc] initWithTitle:@"Set focus mode" message:nil];
    [sheet addButtonWithTitle:@"Locked" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setFocusMode:AVCaptureFocusModeLocked];
    }];
    [sheet addButtonWithTitle:@"Autofocus" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setFocusMode:AVCaptureFocusModeAutoFocus];
    }];
    [sheet addButtonWithTitle:@"Continuous autofocus" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }];
    [sheet addButtonWithTitle:@"Cancel" style:MWFActionSheetActionStyleCancel handler:^(){}];
    // TODO frame, or bounds?
    [sheet showFromRect:self.focusButton.bounds inView:self.focusButton animated:YES viewController:self];
}

// TODO this could be a cameraController method
- (void)setFocusMode:(AVCaptureFocusMode)mode
{
    AVCaptureDevice *camera = self.cameraController.camera;
    if ([camera lockForConfiguration:nil])
    {
        if ([camera isFocusModeSupported:mode])
        {
            camera.focusMode = mode;
        }
        [camera unlockForConfiguration];
    }
}


#pragma mark - exposure

- (IBAction)exposureTapped
{
    MWFActionSheet *sheet = [[MWFActionSheet alloc] initWithTitle:@"Set exposure mode" message:nil];
    [sheet addButtonWithTitle:@"Locked" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setExposureMode:AVCaptureExposureModeLocked];
    }];
    [sheet addButtonWithTitle:@"Autoexpose" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setExposureMode:AVCaptureExposureModeAutoExpose];
    }];
    [sheet addButtonWithTitle:@"Continuous autoexpose" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }];
    [sheet addButtonWithTitle:@"Cancel" style:MWFActionSheetActionStyleCancel handler:^(){}];
    [sheet showFromRect:self.exposureButton.bounds inView:self.exposureButton animated:YES viewController:self];
}

- (void)setExposureMode:(AVCaptureExposureMode)mode
{
    AVCaptureDevice *camera = self.cameraController.camera;
    if ([camera lockForConfiguration:nil])
    {
        if ([camera isExposureModeSupported:mode])
        {
            camera.exposureMode = mode;
        }
        [camera unlockForConfiguration];
    }
}

#pragma mark - format

- (IBAction)formatTapped:(id)sender
{
    AVCaptureDevice *camera = self.cameraController.camera;
    MWFActionSheet *sheet = [[MWFActionSheet alloc] initWithTitle:@"Select format" message:nil];
    for (AVCaptureDeviceFormat *format in [camera formats])
    {
        CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions([format formatDescription]);
        AVFrameRateRange *range = format.videoSupportedFrameRateRanges[0];
        NSString *title = [NSString stringWithFormat:@"%d x %d @ %.2f FPS", dims.width, dims.height, range.maxFrameRate];
        [sheet addButtonWithTitle:title style:MWFActionSheetActionStyleDefault handler:^() {
            CameraControllerError error = [self.cameraController setActiveFormat:format];
            if (error != CameraControllerErrorNone)
            {
                [self reportError:error];
            }
        }];
    }
    [sheet addButtonWithTitle:@"Cancel" style:MWFActionSheetActionStyleCancel handler:^(){}];
    [sheet showFromRect:self.formatButton.bounds inView:self.formatButton animated:YES viewController:self];
}

#pragma mark - front/back camera

- (IBAction)cameraTapped:(id)sender
{
    AVCaptureDevicePosition position = [self.cameraController.camera position] == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    CameraControllerError error = [self.cameraController setCameraWithPosition:position];
    if (error != CameraControllerErrorNone)
    {
        [self reportError:error];
    }
    else
    {
        [self logCameraCapabilities:self.cameraController.camera];
    }
}

#pragma mark - FPS multiplier

- (IBAction)fpsMultiplierTapped:(id)sender
{
    MWFActionSheet *sheet = [[MWFActionSheet alloc] initWithTitle:@"Double or halve framerate" message:nil];
    [sheet addButtonWithTitle:@"Double" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setFPSMultiplier:YES];
    }];
    [sheet addButtonWithTitle:@"Halve" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setFPSMultiplier:NO];
    }];
    [sheet addButtonWithTitle:@"Cancel" style:MWFActionSheetActionStyleCancel handler:^(){}];
    [sheet showFromRect:self.fpsMultiplierButton.bounds inView:self.fpsMultiplierButton animated:YES viewController:self];
}

- (void)setFPSMultiplier:(BOOL)doubleFPS
{
    AVCaptureDevice *camera = self.cameraController.camera;
    if ([camera lockForConfiguration:nil])
    {
        CMTime oldFrameDuration = camera.activeVideoMinFrameDuration;
        CMTime newFrameDuration;
        if (doubleFPS)
        {
            newFrameDuration = CMTimeMake(oldFrameDuration.value, oldFrameDuration.timescale * 2);
        }
        else
        {
            newFrameDuration = CMTimeMake(oldFrameDuration.value * 2, oldFrameDuration.timescale);
        }
        camera.activeVideoMaxFrameDuration = newFrameDuration;
        camera.activeVideoMinFrameDuration = newFrameDuration;
        [camera unlockForConfiguration];
    }
}

#pragma mark - white balance

- (IBAction)whiteBalanceTapped:(id)sender
{
    MWFActionSheet *sheet = [[MWFActionSheet alloc] initWithTitle:@"Set white balance mode" message:nil];
    [sheet addButtonWithTitle:@"Locked" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
    }];
    [sheet addButtonWithTitle:@"Autobalance" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
    }];
    [sheet addButtonWithTitle:@"Continuous autobalance" style:MWFActionSheetActionStyleDefault handler:^() {
        [self setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    }];
    [sheet addButtonWithTitle:@"Cancel" style:MWFActionSheetActionStyleCancel handler:^(){}];
    [sheet showFromRect:self.whiteBalanceButton.bounds inView:self.whiteBalanceButton animated:YES viewController:self];
    NSLog(@"white balance");
}

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)mode
{
    AVCaptureDevice *camera = self.cameraController.camera;
    if ([camera lockForConfiguration:nil])
    {
        if ([camera isWhiteBalanceModeSupported:mode])
        {
            camera.whiteBalanceMode = mode;
        }
        [camera unlockForConfiguration];
    }
}

#pragma mark - zoom

- (IBAction)zoomSliderDidChange
{
    AVCaptureDevice *camera = self.cameraController.camera;
    CGFloat maxZoom = camera.activeFormat.videoMaxZoomFactor;
    CGFloat newZoomFactor = (maxZoom - 1) * self.zoomSlider.value + 1;
    if ([camera lockForConfiguration:nil])
    {
        camera.videoZoomFactor = newZoomFactor;
        [camera unlockForConfiguration];
    }
}

#pragma mark - exposure

- (IBAction)exposureSliderDidChange
{
    //    DLog(@"%@", self.exposureSlider);
    AVCaptureDevice *camera = self.cameraController.camera;
    AVCaptureDeviceFormat *format = camera.activeFormat;
    float diff = format.maxISO - format.minISO;
    float iso = diff * self.exposureSlider.value + format.minISO;
    if ([camera lockForConfiguration:nil])
    {
        //        DLog(@"exposure -- %d", _camera.exposureMode);
        [camera setExposureModeCustomWithDuration:camera.exposureDuration ISO:iso completionHandler:^(CMTime syncTime) {
            //            DLog(@"exposure -- %d", strongSelf->_camera.exposureMode);
            [camera unlockForConfiguration];
        }];
    }
}

#pragma mark - orientation

- (AVCaptureVideoOrientation)getVideoOrientation
{
    UIInterfaceOrientation toInterfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft)
    {
        return AVCaptureVideoOrientationLandscapeLeft;
    }
    else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        return AVCaptureVideoOrientationLandscapeRight;
    }
    else if (toInterfaceOrientation == UIInterfaceOrientationPortrait)
    {
        return AVCaptureVideoOrientationPortrait;
    }
    else if (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        return AVCaptureVideoOrientationPortraitUpsideDown;
    }
    else
    {
        NSLog(@"ooh, something weird happened");
        return AVCaptureVideoOrientationPortrait;
    }
}

- (BOOL)shouldAutorotate
{
    return !self.cameraController.recording;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - CameraControllerDelegate

- (void)adjustingExposure
{
    NSLog(@"adjusting exposure");
}

- (void)adjustingFocus
{
    NSLog(@"adjusting focus");
}

- (void)finishedRecordingIPhone4WithURL:(NSURL *)fileURL error:(NSError *)error
{
    
}

- (void)finishedRecordingWithURL:(NSURL *)fileURL status:(AVAssetWriterStatus)status
{
    NSLog(@"finished -- %@, %ld", fileURL, status);
}

#pragma mark - device capabilities

- (void)logCameraCapabilities:(AVCaptureDevice *)camera
{
    NSLog(@"focus:");
    NSLog(@"  locked: %d", [camera isFocusModeSupported:AVCaptureFocusModeLocked]);
    NSLog(@"  autofocus: %d", [camera isFocusModeSupported:AVCaptureFocusModeAutoFocus]);
    NSLog(@"  continuous autofocus: %d", [camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]);
    NSLog(@"  focus point of interest: %d", [camera isFocusPointOfInterestSupported]);
    NSLog(@"exposure:");
    NSLog(@"  locked: %d", [camera isExposureModeSupported:AVCaptureExposureModeLocked]);
    NSLog(@"  autoexpose: %d", [camera isExposureModeSupported:AVCaptureExposureModeAutoExpose]);
    NSLog(@"  continuous autoexpose: %d", [camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]);
    NSLog(@"  custom: %d", [camera isExposureModeSupported:AVCaptureExposureModeCustom]);
    NSLog(@"  exposure point of interest: %d", [camera isExposurePointOfInterestSupported]);
    NSLog(@"format:");
    for (AVCaptureDeviceFormat *format in [camera formats])
    {
        CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions([format formatDescription]);
        AVFrameRateRange *range = format.videoSupportedFrameRateRanges[0];
        NSString *title = [NSString stringWithFormat:@"%d x %d @ %.2f FPS", dims.width, dims.height, range.maxFrameRate];
        NSLog(@"  %@, %.2f", title, format.videoMaxZoomFactor);
    }
    NSLog(@"zoom:");
//    NSLog(@"  min zoom: %f", camera)
    NSLog(@"white balance");
    NSLog(@"  locked: %d", [camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]);
    NSLog(@"  auto whitebalance: %d", [camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]);
    NSLog(@"  continuous auto whitebalance: %d", [camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]);
    NSLog(@"torch:");
    NSLog(@"  off: %d", [camera isTorchModeSupported:AVCaptureTorchModeOff]);
    NSLog(@"  on: %d", [camera isTorchModeSupported:AVCaptureTorchModeOn]);
/*    if ([camera isTorchModeSupported:AVCaptureTorchModeAuto])
    {
        if ([camera lockForConfiguration:nil])
        {
            camera.torchMode = AVCaptureTorchModeAuto;
            [camera unlockForConfiguration];
        }
    }*/
    NSLog(@"  auto: %d", [camera isTorchModeSupported:AVCaptureTorchModeAuto]);
    NSLog(@"flash:");
    NSLog(@"  off: %d", [camera isFlashModeSupported:AVCaptureFlashModeOff]);
    NSLog(@"  on: %d", [camera isFlashModeSupported:AVCaptureFlashModeOn]);
    NSLog(@"  auto: %d", [camera isFlashModeSupported:AVCaptureFlashModeAuto]);
    NSLog(@"presets: ");
    for (NSString *preset in @[AVCaptureSessionPreset1280x720, AVCaptureSessionPreset1920x1080, AVCaptureSessionPreset352x288, AVCaptureSessionPreset640x480, AVCaptureSessionPresetHigh, AVCaptureSessionPresetiFrame1280x720, AVCaptureSessionPresetiFrame960x540, AVCaptureSessionPresetInputPriority, AVCaptureSessionPresetLow, AVCaptureSessionPresetMedium, AVCaptureSessionPresetPhoto])
    {
        NSLog(@"  %@: %d", preset, [camera supportsAVCaptureSessionPreset:preset]);
    }
}

#pragma mark - state


@end
