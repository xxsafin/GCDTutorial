//  PhotoManager.m
//  PhotoFilter
//
//  Created by A Magical Unicorn on A Sunday Night.
//  Copyright (c) 2014 Derek Selander. All rights reserved.
//

@import CoreImage;
@import AssetsLibrary;
#import "PhotoManager.h"

@interface PhotoManager ()
@property (nonatomic, strong, readonly) NSMutableArray *photosArray;

@property (nonatomic, strong) dispatch_queue_t concurrentPhotoQueue;
@end

@implementation PhotoManager

+ (instancetype)sharedManager
{
    static PhotoManager *sharedPhotoManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPhotoManager = [[PhotoManager alloc] init];
        NSLog(@"Singleton has memory address at : %@", sharedPhotoManager);
        sharedPhotoManager->_photosArray = [NSMutableArray array];
        sharedPhotoManager->_concurrentPhotoQueue = dispatch_queue_create("com.otakugame.googlypuff.concurrentPhotoQueue", DISPATCH_QUEUE_CONCURRENT);
    });

    return sharedPhotoManager;
}

//*****************************************************************************/
#pragma mark - Unsafe Setter/Getters
//*****************************************************************************/

- (NSArray *)photos
{
    __block NSArray *array;
    dispatch_sync(self.concurrentPhotoQueue, ^{
        array = [NSArray arrayWithArray:_photosArray];
    });
    
    return array;
}

- (void)addPhoto:(Photo *)photo
{
    if (photo) {
        dispatch_barrier_async(self.concurrentPhotoQueue, ^{
            [_photosArray addObject:photo];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self postContentAddedNotification];
            });
        });
        
    }
}

//*****************************************************************************/
#pragma mark - Public Methods
//*****************************************************************************/

- (void)downloadPhotosWithCompletionBlock:(BatchPhotoDownloadingCompletionBlock)completionBlock
{
    __block NSError *error;
    dispatch_group_t downloadGroup = dispatch_group_create();
    
    dispatch_apply(3, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
        
        NSLog(@"%zu",i);
        
        NSURL *url;
        switch (i) {
            case 0:
                url = [NSURL URLWithString:kOverlyAttachedGirlfriendURLString];
                break;
            case 1:
                url = [NSURL URLWithString:kSuccessKidURLString];
                break;
            case 2:
                url = [NSURL URLWithString:kLotsOfFacesURLString];
                break;
            default:
                break;
        }
        dispatch_group_enter(downloadGroup);
        
        
        Photo *photo = [[Photo alloc] initwithURL:url
                              withCompletionBlock:^(UIImage *image, NSError *_error) {
                                  if (_error) {
                                      error = _error;
                                  }
                                  dispatch_group_leave(downloadGroup);
                              }];
        [[PhotoManager sharedManager] addPhoto:photo];
    });
    
    
    dispatch_group_notify(downloadGroup, dispatch_get_main_queue(), ^{
        
        if (completionBlock) {
            completionBlock(error);
        }
    });
}

//*****************************************************************************/
#pragma mark - Private Methods
//*****************************************************************************/

- (void)postContentAddedNotification
{
    static NSNotification *notification = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notification = [NSNotification notificationWithName:kPhotoManagerAddedContentNotification object:nil];
    });
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:nil];
}

@end
