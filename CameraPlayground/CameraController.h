#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@import AVFoundation;


typedef NS_ENUM(NSInteger, CameraControllerError)
{
    CameraControllerErrorNone,
    CameraControllerErrorNoAudioDeviceFound,
    CameraControllerErrorNoVideoDeviceFound,
    CameraControllerErrorUnableToAddAudioInput,
    CameraControllerErrorUnableToAddAudioOutput,
    CameraControllerErrorUnableToAddVideoInput,
    CameraControllerErrorUnableToAddVideoOutput,
    CameraControllerErrorUnableToAddFileOutput,
    CameraControllerErrorUnableToCreateAssetWriter,
    CameraControllerErrorUnableToAddAssetWriterVideoInput,
    CameraControllerErrorUnableToAddAssetWriterAudioInput,
    CameraControllerErrorUnableToStartWriting,
    CameraControllerErrorInvalidFormat,
    CameraControllerErrorUnableToLockForConfig
};

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
- (instancetype)initWithUsingCustomPipeline:(BOOL)isUsingCustomPipeline;

- (CameraControllerError)initializeDevicesWithCameraPosition:(AVCaptureDevicePosition)cameraPosition;
- (CameraControllerError)initializeAVCaptureSession;
//- (CameraControllerError)initializeAVAssetWriter:(NSURL *)fileURL;
- (CameraControllerError)startRecordingWithFileURL:(NSURL *)fileURL;
- (void)stopRecording;
- (void)pauseRecording;
- (void)resumeRecording;
- (void)cleanUp;
- (CameraControllerError)setActiveFormat:(AVCaptureDeviceFormat *)format;
- (void)setVideoAVCaptureOrientation:(AVCaptureVideoOrientation)orientation;
- (CameraControllerError)setCameraWithPosition:(AVCaptureDevicePosition)position;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, weak) id<CameraControllerDelegate> delegate;
@property (nonatomic, strong) AVCaptureDevice *camera;
@property (nonatomic) BOOL recording;

@end
