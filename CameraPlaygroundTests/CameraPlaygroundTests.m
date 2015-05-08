//
//  CameraPlaygroundTests.m
//  CameraPlaygroundTests
//
//  Created by Matthew Fenwick on 2/6/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "CameraController.h"


@interface CameraPlaygroundTests : XCTestCase

@property (nonatomic) NSInteger fileCount;

@end


@implementation CameraPlaygroundTests

- (NSURL *)getFileURL
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] == 0)
    {
        return nil;
    }
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"test_%ld.mov", (long)self.fileCount]];
    self.fileCount++;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath])
    {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    return [NSURL fileURLWithPath:filePath];
}

#pragma mark - scaffolding

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - tests

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testFormats
{
    CameraController *controller = [[CameraController alloc] init];
    [controller initializeAVCaptureSessionWithCameraPosition:AVCaptureDevicePositionBack];
    [controller setVideoAVCaptureOrientation:AVCaptureVideoOrientationPortrait];
    __block NSInteger count = 1;
    __block BOOL exitLoop = NO;
    for (AVCaptureDeviceFormat *format in [controller.camera formats])
    {
        if ([controller.camera lockForConfiguration:nil])
        {
            controller.camera.activeFormat = format;
            [controller.camera unlockForConfiguration];
            NSURL *url = [self getFileURL];
            CameraControllerError startErrorCode = [controller startRecordingWithFileURL:url];
            if (startErrorCode == CameraControllerErrorNone)
            {
                CameraControllerError stopErrorCode = [controller stopRecording];
                if (stopErrorCode == CameraControllerErrorNone)
                {
                    count++;
                    XCTAssert(YES, @"successfully started and stopped recording for format");
                }
                else
                {
                    XCTAssert(NO, @"failed to stop recording for format");
                    exitLoop = YES;
                }
            }
            else
            {
                NSString *errorString = [NSString stringWithFormat:@"failed to start recording for format -- %@, %ld", [format description], startErrorCode];
                NSLog(@"%@", errorString);
                XCTAssert(NO, @"oops");
                exitLoop = YES;
            }
        }
        else
        {
            NSLog(@"unable to lock for configuration");
        }
        if (exitLoop)
        {
            break;
        }
    }
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
