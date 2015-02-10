//
//  CameraPicker.m
//  CameraPlayground
//
//  Created by MattF on 2/9/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import "CameraPicker.h"
@import AVFoundation;

@interface CameraPicker ()

@property (nonatomic, strong) NSArray *devices;

@end

@implementation CameraPicker

- (instancetype)init
{
    self = [super init];
    self.devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    NSLog(@"CameraPicker init:  %@ %@ %d", self.devices[0], self.devices[1], self.devices[0] == self.devices[1]);
    return self;
}


#pragma mark - datasource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return [self.devices count];
}


#pragma mark - delegate

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 40;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    return 150;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    AVCaptureDevice *device = self.devices[row];
    NSLog(@"pickerView: %@ %@", device.localizedName, device.uniqueID);//str);
    return device.localizedName;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    if (self.selectionDidChange)
    {
        self.selectionDidChange(row);
    }
}

@end
