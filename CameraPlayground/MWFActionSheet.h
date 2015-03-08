#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, MWFActionSheetActionStyle)
{
    MWFActionSheetActionStyleDefault,
    MWFActionSheetActionStyleCancel,
    MWFActionSheetActionStyleDestructive
};


@interface MWFActionSheet : NSObject

@property (nonatomic, strong) UIActionSheet *actionSheet;
@property (nonatomic, strong) UIAlertController *alertController;
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message;
- (void)addButtonWithTitle:(NSString *)title style:(MWFActionSheetActionStyle)style handler:(void(^)())handler;
- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated viewController:(UIViewController *)viewController;
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated viewController:(UIViewController *)viewController;

@end
