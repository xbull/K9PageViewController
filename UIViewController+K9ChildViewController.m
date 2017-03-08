//
//  UIViewController+K9ChildViewController.m
//  ApusTest
//
//  Created by K999999999 on 2017/1/26.
//  Copyright © 2017年 余小擎. All rights reserved.
//

#import "UIViewController+K9ChildViewController.h"

@implementation UIViewController (K9ChildViewController)

- (void)k9_addChildViewController:(UIViewController *)viewController inView:(UIView *)inView withFrame:(CGRect)withFrame {
    
    if (![self.childViewControllers containsObject:viewController]) {
        
        [self addChildViewController:viewController];
    }
    
    viewController.view.frame = withFrame;
    
    if (![inView.subviews containsObject:viewController.view]) {
        
        [inView addSubview:viewController.view];
    }
    
    if (![self.childViewControllers containsObject:viewController]) {
        
        [viewController didMoveToParentViewController:self];
    }
}

- (void)k9_removeFromParentViewController {
    
    [self willMoveToParentViewController:nil];
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
}

@end
