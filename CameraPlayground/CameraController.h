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
    CameraControllerErrorUnableToLockForConfig,
    CameraControllerErrorInvalidState
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
 - focus POI
 - exposure POI
 - FPS, or sessionPreset, or format
 - torch
 
 methods
 - pause
 - resume
 */
- (instancetype)initWithUsingCustomPipeline:(BOOL)isUsingCustomPipeline;

- (CameraControllerError)initializeAVCaptureSessionWithCameraPosition:(AVCaptureDevicePosition)cameraPosition;
//- (CameraControllerError)initializeAVAssetWriter:(NSURL *)fileURL;
- (CameraControllerError)startRecordingWithFileURL:(NSURL *)fileURL;
- (CameraControllerError)stopRecording;
- (CameraControllerError)pauseRecording;
- (CameraControllerError)resumeRecording;
- (CameraControllerError)setActiveFormat:(AVCaptureDeviceFormat *)format;
- (CameraControllerError)setVideoAVCaptureOrientation:(AVCaptureVideoOrientation)orientation;
- (CameraControllerError)setCameraWithPosition:(AVCaptureDevicePosition)position;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, weak) id<CameraControllerDelegate> delegate;
@property (nonatomic, strong) AVCaptureDevice *camera;
@property (nonatomic) BOOL recording;

@end
