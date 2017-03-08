//
//  K9PageViewController.m
//  ApusTest
//
//  Created by K999999999 on 2017/1/26.
//  Copyright © 2017年 余小擎. All rights reserved.
//

#import "K9PageViewController.h"
#import "UIViewController+K9ChildViewController.h"
#import "Masonry.h"

typedef NS_ENUM(NSInteger, K9PageScrollDirection) {
    
    K9PageScrollDirectionLeft = 0,
    K9PageScrollDirectionRight
};

@interface K9PageViewController () <NSCacheDelegate, UIScrollViewDelegate>

@property (nonatomic)           CGFloat                                     originOffset;
@property (nonatomic)           NSInteger                                   guessToIndex;
@property (nonatomic)           NSInteger                                   lastSelectedIndex;
@property (nonatomic)           BOOL                                        firstWillAppear;
@property (nonatomic)           BOOL                                        firstDidAppear;
@property (nonatomic)           BOOL                                        firstDidLayoutSubViews;
@property (nonatomic)           BOOL                                        isDecelerating;

@property (nonatomic, strong)   NSCache <NSNumber *, UIViewController *>    *memCache;
@property (nonatomic, strong)   NSMutableArray <UIViewController *>         *childsToClean;

@property (nonatomic)           NSInteger                                   currentPageIndex;
@property (nonatomic, strong)   UIScrollView                                *scrollView;

@end

@implementation K9PageViewController

#pragma mark - Life Cycle

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        _contentEdgeInsets = UIEdgeInsetsZero;
        
        _originOffset = 0.f;
        _guessToIndex = -1;
        _lastSelectedIndex = 0;
        _firstWillAppear = YES;
        _firstDidAppear = YES;
        _firstDidLayoutSubViews = YES;
        _isDecelerating = NO;
        
        _currentPageIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self configViews];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    if (self.firstWillAppear) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(k9_pageViewController:willLeaveViewController:toVC:)]) {
            
            [self.delegate k9_pageViewController:self willLeaveViewController:[self controllerAtIndex:self.lastSelectedIndex] toVC:[self controllerAtIndex:self.currentPageIndex]];
        }
        self.firstWillAppear = NO;
    }
    [[self controllerAtIndex:self.currentPageIndex] beginAppearanceTransition:YES animated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    if (self.firstDidAppear) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(k9_pageViewController:didLeaveViewController:toVC:)]) {
            
            [self.delegate k9_pageViewController:self didLeaveViewController:[self controllerAtIndex:self.lastSelectedIndex] toVC:[self controllerAtIndex:self.currentPageIndex]];
        }
        self.firstDidAppear = NO;
    }
    [[self controllerAtIndex:self.currentPageIndex] endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [[self controllerAtIndex:self.currentPageIndex] beginAppearanceTransition:NO animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    
    [super viewDidDisappear:animated];
    
    [[self controllerAtIndex:self.currentPageIndex] endAppearanceTransition];
}

- (void)viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];
    
    if (self.firstDidLayoutSubViews) {
        
        UINavigationController *navigationController = self.navigationController;
        if (navigationController && navigationController.viewControllers.count > 0 && [navigationController.viewControllers[navigationController.viewControllers.count - 1] isEqual:self]) {
            
            self.scrollView.contentOffset = CGPointZero;
            self.scrollView.contentInset = UIEdgeInsetsZero;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [self updateScrollViewLayoutIfNeeded];
            [self updateScrollViewDisplayIndexIfNeeded];
        });
        
        self.firstDidLayoutSubViews = NO;
    } else {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [self updateScrollViewLayoutIfNeeded];
        });
    }
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    
    return NO;
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
    
    [self.memCache removeAllObjects];
}

#pragma mark - Config Views

- (void)configViews {
    
    [self configScrollView];
}

- (void)configScrollView {
    
    if (self.scrollView.superview != nil) {
        return;
    }
    
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        
        make.edges.equalTo(self.view).with.insets(self.contentEdgeInsets);
    }];
}

#pragma mark - NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    
    if ([obj isKindOfClass:[UIViewController class]]) {
        
        UIViewController *vc = (UIViewController *)obj;
        
        if ([self.childViewControllers containsObject:vc]) {
            
            if (self.scrollView.isDragging == NO &&
                self.scrollView.isTracking == NO &&
                self.scrollView.isDecelerating == NO) {
                
                UIViewController *lastPage = [self controllerAtIndex:self.lastSelectedIndex];
                UIViewController *currentPage = [self controllerAtIndex:self.currentPageIndex];
                
                if ([lastPage isEqual:vc] || [currentPage isEqual:vc]) {
                    
                    [self.childsToClean addObject:vc];
                }
            } else if (self.scrollView.isDragging == YES) {
                
                NSInteger midIndex = self.guessToIndex;
                NSInteger leftIndex = midIndex - 1;
                NSInteger rightIndex = midIndex + 1;
                
                if (leftIndex < 0) {
                    
                    leftIndex = midIndex;
                }
                
                if (rightIndex > (self.pageCount - 1)) {
                    
                    rightIndex = midIndex;
                }
                
                UIViewController *leftNeighbour = [self controllerAtIndex:leftIndex];
                UIViewController *midPage = [self controllerAtIndex:midIndex];
                UIViewController *rightNeighbour = [self controllerAtIndex:rightIndex];
                
                if ([leftNeighbour isEqual:vc] || [rightNeighbour isEqual:vc] || [midPage isEqual:vc]) {
                    
                    [self.childsToClean addObject:vc];
                }
            }
            
            if (self.childsToClean.count > 0) {
                
                return;
            }
            
            [vc k9_removeFromParentViewController];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView.isDragging == YES && [scrollView isEqual:self.scrollView]) {
        
        CGFloat offset = scrollView.contentOffset.x;
        CGFloat width = scrollView.frame.size.width;
        NSInteger lastGuessIndex = self.guessToIndex < 0 ? self.currentPageIndex : self.guessToIndex;
        if (self.originOffset < offset) {
            self.guessToIndex = (NSInteger)(ceil(offset/width));
        } else if (self.originOffset > offset) {
            self.guessToIndex = (NSInteger)(floor(offset/width));
        }
        
        NSInteger maxCount = self.pageCount;
        
        if ((self.guessToIndex != self.currentPageIndex &&
            self.scrollView.isDecelerating == NO) ||
            self.scrollView.isDecelerating == YES) {
            
            if (lastGuessIndex != self.guessToIndex &&
                self.guessToIndex >= 0 &&
                self.guessToIndex < maxCount) {
                    
                if (self.delegate && [self.delegate respondsToSelector:@selector(k9_pageViewController:willTransitonFromVC:toVC:)]) {
                    
                    [self.delegate k9_pageViewController:self willTransitonFromVC:[self controllerAtIndex:self.guessToIndex] toVC:[self controllerAtIndex:self.currentPageIndex]];
                }
                
                [self addVisibleViewContorllerWithIndex:self.guessToIndex];
                
                [[self controllerAtIndex:self.guessToIndex] beginAppearanceTransition:YES animated:YES];
                
                if (lastGuessIndex == self.currentPageIndex) {
                    
                    [[self controllerAtIndex:self.currentPageIndex] beginAppearanceTransition:NO animated:YES];
                }
                
                if (lastGuessIndex != self.currentPageIndex &&
                    lastGuessIndex >= 0 &&
                    lastGuessIndex < maxCount) {
                    
                    [[self controllerAtIndex:lastGuessIndex] beginAppearanceTransition:NO animated:YES];
                    [[self controllerAtIndex:lastGuessIndex] endAppearanceTransition];
                }
            }
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    if (scrollView.isDecelerating == NO) {
        
        self.originOffset = scrollView.contentOffset.x;
        self.guessToIndex = self.currentPageIndex;
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    
    if (scrollView.isDecelerating == YES) {
        
        CGFloat offset = scrollView.contentOffset.x;
        CGFloat width = scrollView.frame.size.width;
        if (velocity.x > 0.f) {
            
            self.originOffset = floor(offset/width) * width;
        } else if (velocity.x < 0.f) {
            
            self.originOffset = ceil(offset/width) * width;
        }
    }
    
    CGFloat offset = scrollView.contentOffset.x;
    CGFloat scrollViewWidth = scrollView.frame.size.width;
    
    if (((NSInteger)(offset * 100.f) % (NSInteger)(scrollViewWidth * 100.f)) == 0) {
        
        [self updatePageViewAfterTragging:scrollView];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    
    self.isDecelerating = YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    [self updatePageViewAfterTragging:scrollView];
}

#pragma mark - Public Methods

- (void)showPageAtIndex:(NSInteger)index animated:(BOOL)animated {
    
    if (index < 0 || index >= self.pageCount) {
        
        return;
    }
    
    NSInteger oldSelectedIndex = self.lastSelectedIndex;
    self.lastSelectedIndex = self.currentPageIndex;
    self.currentPageIndex = index;
    
    if (self.scrollView.frame.size.width > 0.f &&
        self.scrollView.contentSize.width > 0.f) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(k9_pageViewController:willLeaveViewController:toVC:)]) {
            
            [self.delegate k9_pageViewController:self willLeaveViewController:[self controllerAtIndex:self.lastSelectedIndex] toVC:[self controllerAtIndex:self.currentPageIndex]];
        }
        
        [self addVisibleViewContorllerWithIndex:index];
    }
    
    if (self.scrollView.frame.size.width > 0.f &&
        self.scrollView.contentSize.width > 0.f) {
        
        void (^scrollBeginAnimation)(void) = ^(void) {
            
            [[self controllerAtIndex:self.currentPageIndex] beginAppearanceTransition:YES animated:animated];
            if (self.currentPageIndex != self.lastSelectedIndex) {
                
                [[self controllerAtIndex:self.lastSelectedIndex] beginAppearanceTransition:NO animated:animated];
            }
        };
        
        void (^scrollAnimation)(void) = ^(void) {
            
            CGPoint offset = [self calcOffsetWithIndex:self.currentPageIndex width:self.scrollView.frame.size.width maxWidth:self.scrollView.contentSize.width];
            
            [self.scrollView setContentOffset:offset animated:NO];
        };
        
        void (^scrollEndAnimation)(void) = ^(void) {
            
            [[self controllerAtIndex:self.currentPageIndex] endAppearanceTransition];
            
            if (self.currentPageIndex != self.lastSelectedIndex) {
                
                [[self controllerAtIndex:self.lastSelectedIndex] endAppearanceTransition];
            }
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(k9_pageViewController:didLeaveViewController:toVC:)]) {
                
                [self.delegate k9_pageViewController:self didLeaveViewController:[self controllerAtIndex:self.lastSelectedIndex] toVC:[self controllerAtIndex:self.currentPageIndex]];
            }
            
            [self cleanCacheToClean];
        };
        
        scrollBeginAnimation();
            
        if (animated) {
            
            if (self.lastSelectedIndex != self.currentPageIndex) {
                
                CGSize pageSize = self.scrollView.frame.size;
                K9PageScrollDirection direction = (self.lastSelectedIndex < self.currentPageIndex) ? K9PageScrollDirectionRight : K9PageScrollDirectionLeft;
                UIView *lastView = [self controllerAtIndex:self.lastSelectedIndex].view;
                UIView *currentView = [self controllerAtIndex:self.currentPageIndex].view;
                UIView *oldSelectView = [self controllerAtIndex:oldSelectedIndex].view;
                CGFloat duration = .3f;
                NSInteger backgroundIndex = [self calcIndexWithOffset:self.scrollView.contentOffset.x width:self.scrollView.frame.size.width];
                UIView *backgroundView;
                
                if (oldSelectView.layer.animationKeys.count > 0 &&
                    lastView.layer.animationKeys.count > 0) {
                    
                    UIView *tmpView = [self controllerAtIndex:backgroundIndex].view;
                    if (![tmpView isEqual:currentView] &&
                        ![tmpView isEqual:lastView]) {
                        
                        backgroundView = tmpView;
                        backgroundView.hidden = YES;
                    }
                }
                
                [self.scrollView.layer removeAllAnimations];
                [oldSelectView.layer removeAllAnimations];
                [lastView.layer removeAllAnimations];
                [currentView.layer removeAllAnimations];
                
                [self moveBackToOriginPositionIfNeeded:oldSelectView index:oldSelectedIndex];
                
                [self.scrollView bringSubviewToFront:lastView];
                [self.scrollView bringSubviewToFront:currentView];
                
                lastView.hidden = NO;
                currentView.hidden = NO;
                
                CGPoint lastView_StartOrigin = lastView.frame.origin;
                CGPoint currentView_StartOrigin = lastView.frame.origin;
                if (direction == K9PageScrollDirectionRight) {
                    
                    currentView_StartOrigin.x += self.scrollView.frame.size.width;
                } else {
                    
                    currentView_StartOrigin.x -= self.scrollView.frame.size.width;
                }
                
                CGPoint lastView_AnimateToOrigin = lastView.frame.origin;
                if (direction == K9PageScrollDirectionRight) {
                    
                    lastView_AnimateToOrigin.x -= self.scrollView.frame.size.width;
                } else {
                    
                    lastView_AnimateToOrigin.x += self.scrollView.frame.size.width;
                }
                
                CGPoint currentView_AnimateToOrigin = lastView.frame.origin;
                
                CGPoint lastView_EndOrigin = lastView.frame.origin;
                CGPoint currentView_EndOrigin = currentView.frame.origin;
                
                lastView.frame = CGRectMake(lastView_StartOrigin.x, lastView_StartOrigin.y, pageSize.width, pageSize.height);
                currentView.frame = CGRectMake(currentView_StartOrigin.x, currentView_StartOrigin.y, pageSize.width, pageSize.height);
                
                __weak typeof(self)weakSelf = self;
                [UIView animateWithDuration:duration animations:^{
                    
                    lastView.frame = CGRectMake(lastView_AnimateToOrigin.x, lastView_AnimateToOrigin.y, pageSize.width, pageSize.height);
                    currentView.frame = CGRectMake(currentView_AnimateToOrigin.x, currentView_AnimateToOrigin.y, pageSize.width, pageSize.height);
                } completion:^(BOOL finished) {
                    
                    if (finished) {
                        
                        __strong typeof(weakSelf)self = weakSelf;
                        lastView.frame = CGRectMake(lastView_EndOrigin.x, lastView_EndOrigin.y, pageSize.width, pageSize.height);
                        currentView.frame = CGRectMake(currentView_EndOrigin.x, currentView_EndOrigin.y, pageSize.width, pageSize.height);
                        backgroundView.hidden = NO;
                        [self moveBackToOriginPositionIfNeeded:currentView index:self.currentPageIndex];
                        [self moveBackToOriginPositionIfNeeded:lastView index:self.lastSelectedIndex];
                        scrollAnimation();
                        scrollEndAnimation();
                    }
                    
                }];
            } else {
                
                scrollAnimation();
                scrollEndAnimation();
            }
        } else {
            
            scrollAnimation();
            scrollEndAnimation();
        }
    }
}

- (void)clear {
    
    [self.memCache removeAllObjects];
}

#pragma mark - Private Methods

- (CGRect)calcVisibleViewControllerFrameWith:(NSInteger)index {
    
    CGFloat offsetX = (CGFloat)index * self.scrollView.frame.size.width;
    return CGRectMake(offsetX, 0.f, self.scrollView.frame.size.width, self.scrollView.frame.size.height);
}

- (CGPoint)calcOffsetWithIndex:(NSInteger)index width:(CGFloat)width maxWidth:(CGFloat)maxWidth {
    
    CGFloat offsetX = (CGFloat)index * width;
    if (offsetX < 0) {
        
        offsetX = 0;
    }
    
    if (maxWidth > 0.f && offsetX > (maxWidth - width)) {
        
        offsetX = maxWidth - width;
    }
    
    return CGPointMake(offsetX, 0.f);
}

- (NSInteger)calcIndexWithOffset:(CGFloat)offset width:(CGFloat)width {
    
    NSInteger startIndex = (NSInteger)(offset / width);
    
    if (startIndex < 0) {
        
        startIndex = 0;
    }
    
    return (NSInteger)startIndex;
}

- (void)cleanCacheToClean {
    
    UIViewController *currentPage = [self controllerAtIndex:self.currentPageIndex];
    
    if ([self.childsToClean containsObject:currentPage]) {
        
        [self.childsToClean removeObject:currentPage];
        [self.memCache setObject:currentPage forKey:@(self.currentPageIndex)];
    }
    
    for (UIViewController *vc in self.childsToClean) {
        
        [vc k9_removeFromParentViewController];
    }
    
    [self.childsToClean removeAllObjects];
}

- (void)updatePageViewAfterTragging:(UIScrollView *)scrollView {
    
    NSInteger newIndex = [self calcIndexWithOffset:scrollView.contentOffset.x width:scrollView.frame.size.width];
    NSInteger oldIndex = self.currentPageIndex;
    self.currentPageIndex = newIndex;
    
    if (newIndex == oldIndex) {
        
        if (self.guessToIndex >= 0 && self.guessToIndex < self.pageCount) {
            
            [[self controllerAtIndex:oldIndex] beginAppearanceTransition:YES animated:YES];
            [[self controllerAtIndex:oldIndex] endAppearanceTransition];
            
            [[self controllerAtIndex:self.guessToIndex] beginAppearanceTransition:NO animated:YES];
            [[self controllerAtIndex:self.guessToIndex] endAppearanceTransition];
        }
    } else {
        
        [[self controllerAtIndex:newIndex] endAppearanceTransition];
        [[self controllerAtIndex:oldIndex] endAppearanceTransition];
    }
    
    self.originOffset = scrollView.contentOffset.x;
    self.guessToIndex = self.currentPageIndex;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(k9_pageViewController:didTransitonFromVC:toVC:)]) {
        
        [self.delegate k9_pageViewController:self didTransitonFromVC:[self controllerAtIndex:self.guessToIndex] toVC:[self controllerAtIndex:self.currentPageIndex]];
    }
    
    self.isDecelerating = NO;
    
    [self cleanCacheToClean];
}

- (void)moveBackToOriginPositionIfNeeded:(UIView *)view index:(NSInteger)index {
    
    if (view == nil || index < 0 || index >= self.pageCount) {
        
        return;
    }
    
    UIView *destView = view;
    
    CGPoint originPosition = [self calcOffsetWithIndex:index width:self.scrollView.frame.size.width maxWidth:self.scrollView.contentSize.width];
    
    if (destView.frame.origin.x != originPosition.x) {
        
        CGRect newFrame = destView.frame;
        newFrame.origin = originPosition;
        destView.frame = newFrame;
    }
}

- (void)addVisibleViewContorllerWithIndex:(NSInteger)index {
    
    if (index < 0 || index > self.pageCount) {
        
        return;
    }
    
    UIViewController *vc = [self.memCache objectForKey:@(index)];
    if (vc == nil) {
        
        vc = [self controllerAtIndex:index];
    }
    
    if (vc != nil) {
        
        CGRect childViewFrame = [self calcVisibleViewControllerFrameWith:index];
        [self k9_addChildViewController:vc inView:self.scrollView withFrame:childViewFrame];
        [self.memCache setObject:vc forKey:@(index)];
    }
}

- (void)updateScrollViewLayoutIfNeeded {
    
    if (self.scrollView.frame.size.width > 0.f) {
        
        CGFloat width = (CGFloat)self.pageCount * self.scrollView.frame.size.width;
        CGFloat height = self.scrollView.frame.size.height;
        CGSize oldContentSize = self.scrollView.contentSize;
        if (width != oldContentSize.width || height != oldContentSize.height) {
            
            self.scrollView.contentSize = CGSizeMake(width, height);
        }
    }
}

- (void)updateScrollViewDisplayIndexIfNeeded {
    
    if (self.scrollView.frame.size.width > 0.f) {
        
        [self addVisibleViewContorllerWithIndex:self.currentPageIndex];
        
        CGPoint newOffset = [self calcOffsetWithIndex:self.currentPageIndex width:self.scrollView.frame.size.width maxWidth:self.scrollView.contentSize.width];
        
        if (newOffset.x != self.scrollView.contentOffset.x || newOffset.y != self.scrollView.contentOffset.y) {
            
            self.scrollView.contentOffset = newOffset;
        }
        
        [self controllerAtIndex:self.currentPageIndex].view.frame = [self calcVisibleViewControllerFrameWith:self.currentPageIndex];
    }
}

#pragma mark - Setters

- (void)setCacheLimit:(NSInteger)cacheLimit {
    
    self.memCache.countLimit = cacheLimit;
}

#pragma mark - Getters

- (NSInteger)pageCount {
    
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(numberOfControllers:)]) {
        
        return [self.dataSource numberOfControllers:self];
    }
    return 0;
}

- (NSInteger)cacheLimit {
    
    return self.memCache.countLimit;
}

- (NSCache <NSNumber *, UIViewController *> *)memCache {
    
    if (!_memCache) {
        
        _memCache = [[NSCache alloc] init];
        _memCache.countLimit = 3;
        _memCache.delegate = self;
    }
    return _memCache;
}

- (NSMutableArray <UIViewController *> *)childsToClean {
    
    if (!_childsToClean) {
        
        _childsToClean = [NSMutableArray array];
    }
    return _childsToClean;
}

- (UIScrollView *)scrollView {
    
    if (!_scrollView) {
        
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.delegate = self;
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.pagingEnabled = YES;
        _scrollView.scrollsToTop = NO;
    }
    return _scrollView;
}

- (UIViewController *)controllerAtIndex:(NSInteger)index {
    
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(k9_pageViewController:controllerAtIndex:)]) {
        
        return [self.dataSource k9_pageViewController:self controllerAtIndex:index];
    }
    return nil;
}

@end
