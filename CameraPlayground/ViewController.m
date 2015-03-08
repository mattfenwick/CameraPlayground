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

@property (nonatomic, strong) IBOutlet UIButton *record;
@property (nonatomic, strong) IBOutlet UIButton *focus;
@property (nonatomic, strong) IBOutlet UIButton *exposure;
@property (nonatomic, strong) IBOutlet UIButton *format;
@property (nonatomic, strong) IBOutlet UIButton *camera;

@property (nonatomic, strong) IBOutlet UIView *previewView;
@property (nonatomic, strong) CameraController *cameraController;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic) NSInteger fileCount;

@end


static void *IsAdjustingFocusingContext = &IsAdjustingFocusingContext;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.cameraController = [[CameraController alloc] initWithUsingCustomPipeline:YES cameraPosition:AVCaptureDevicePositionBack];
    [self.cameraController initializeAVCaptureSession];
    self.cameraController.delegate = self;
    [self.cameraController setVideoAVCaptureOrientation:[self getVideoOrientation]];
    [self addVideoPreviewLayer];
    self.fileCount = 1;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
        [self.cameraController startRecordingWithFileURL:url];
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
    [sheet showFromRect:self.focus.bounds inView:self.focus animated:YES viewController:self];
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
    [sheet showFromRect:self.exposure.bounds inView:self.exposure animated:YES viewController:self];
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
            [self.cameraController setActiveFormat:format];
        }];
    }
    [sheet addButtonWithTitle:@"Cancel" style:MWFActionSheetActionStyleCancel handler:^(){}];
    [sheet showFromRect:self.format.bounds inView:self.format animated:YES viewController:self];
}

#pragma mark - front/back camera

- (IBAction)cameraTapped:(id)sender
{
    AVCaptureDevicePosition position = [self.cameraController.camera position] == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    [self.cameraController setCameraWithPosition:position];
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

@end
