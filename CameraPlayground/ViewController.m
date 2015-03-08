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


@interface ViewController () <CameraControllerDelegate>

@property (nonatomic, strong) IBOutlet UIButton *record;
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

- (IBAction)focusExposureTapped:(id)sender
{
    NSError *error;
    AVCaptureDevice *camera = self.cameraController.camera;
    if ([camera lockForConfiguration:&error])
    {
        CGRect screen = [UIApplication sharedApplication].keyWindow.bounds;
        NSLog(@"screen: %@", NSStringFromCGRect(screen));
        CGPoint middle = CGPointMake(screen.size.width / 2.0, screen.size.height / 2.0);
        [camera setFocusPointOfInterest:middle];
        [camera setFocusMode:AVCaptureFocusModeAutoFocus];
        [camera setExposurePointOfInterest:middle];
        [camera setExposureMode:AVCaptureExposureModeAutoExpose];
        [camera unlockForConfiguration];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"keyPath: %@  obj: %@  change: %@", keyPath, object, change);
}

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
