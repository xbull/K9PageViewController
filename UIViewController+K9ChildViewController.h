//
//  UIViewController+K9ChildViewController.h
//  ApusTest
//
//  Created by K999999999 on 2017/1/26.
//  Copyright © 2017年 余小擎. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (K9ChildViewController)

- (void)k9_addChildViewController:(UIViewController *)viewController inView:(UIView *)inView withFrame:(CGRect)withFrame;

- (void)k9_removeFromParentViewController;

@end
