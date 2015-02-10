//
//  CameraPicker.h
//  CameraPlayground
//
//  Created by MattF on 2/9/15.
//  Copyright (c) 2015 Matthew Fenwick. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CameraPicker : NSObject <UIPickerViewDataSource, UIPickerViewDelegate>

- (instancetype)init;

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;

@property (nonatomic, strong) void (^selectionDidChange)(NSInteger row);

@end
