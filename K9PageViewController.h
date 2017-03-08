//
//  K9PageViewController.h
//  ApusTest
//
//  Created by K999999999 on 2017/1/26.
//  Copyright © 2017年 余小擎. All rights reserved.
//

#import <UIKit/UIKit.h>

@class K9PageViewController;

@protocol K9PageViewControllerDataSource <NSObject>

- (NSInteger)numberOfControllers:(K9PageViewController *)pageViewController;

- (UIViewController *)k9_pageViewController:(K9PageViewController *)pageViewController controllerAtIndex:(NSInteger)index;

@end

@protocol K9PageViewControllerDelegate <NSObject>

@optional

- (void)k9_pageViewController:(K9PageViewController *)pageViewController willTransitonFromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC;

- (void)k9_pageViewController:(K9PageViewController *)pageViewController didTransitonFromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC;

- (void)k9_pageViewController:(K9PageViewController *)pageViewController willLeaveViewController:(UIViewController *)fromVC toVC:(UIViewController *)toVC;

- (void)k9_pageViewController:(K9PageViewController *)pageViewController didLeaveViewController:(UIViewController *)fromVC toVC:(UIViewController *)toVC;

@end

@interface K9PageViewController : UIViewController

@property (nonatomic, weak)             id<K9PageViewControllerDataSource>  dataSource;
@property (nonatomic, weak)             id<K9PageViewControllerDelegate>    delegate;

@property (nonatomic)                   UIEdgeInsets                        contentEdgeInsets;
@property (nonatomic)                   NSInteger                           cacheLimit;

@property (nonatomic, readonly)         NSInteger                           pageCount;
@property (nonatomic, readonly)         NSInteger                           currentPageIndex;
@property (nonatomic, strong, readonly) UIScrollView                        *scrollView;

- (void)showPageAtIndex:(NSInteger)index animated:(BOOL)animated;

- (void)clear;

@end
