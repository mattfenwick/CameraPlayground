#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@import AVFoundation;


@protocol CameraControllerDelegate <NSObject>

- (void)finishedRecordingWithURL:(NSURL *)fileURL status:(AVAssetWriterStatus)status;
- (void)finishedRecordingIPhone4WithURL:(NSURL *)fileURL error:(NSError *)error;

- (void)adjustingFocus;
- (void)adjustingExposure;

@end


@interface CameraController : NSObject

/*
 need to change:
 - focusmode
 - focus POI
 - exposuremode
 - exposure POI
 - exposure ISO
 - FPS, or sessionPreset, or format
 - front/back camera
 - zoom
 - torch
 
 methods
 - get everything ready
 - start
 - pause
 - resume
 - stop
 
 also
 - camera observer for focus and exposure
 */
- (instancetype)initWithUsingCustomPipeline:(BOOL)isUsingCustomPipeline cameraPosition:(AVCaptureDevicePosition)cameraPosition;
- (BOOL)initializeAVCaptureSession;
//- (BOOL)initializeAVAssetWriter:(NSURL *)fileURL;
- (void)startRecordingWithFileURL:(NSURL *)fileURL;
- (void)stopRecording;
- (void)pauseRecording;
- (void)resumeRecording;
- (void)cleanUp;
- (void)setActiveFormat:(AVCaptureDeviceFormat *)format;
- (void)setVideoAVCaptureOrientation:(AVCaptureVideoOrientation)orientation;
- (BOOL)setCameraWithPosition:(AVCaptureDevicePosition)position;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, weak) id<CameraControllerDelegate> delegate;
@property (nonatomic, strong) AVCaptureDevice *camera;
@property (nonatomic) BOOL recording;

@end
