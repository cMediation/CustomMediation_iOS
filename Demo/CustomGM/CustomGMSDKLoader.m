#import "CustomGMSDKLoader.h"
#import <TradPlusAds/MSLogging.h>
#import <TradPlusAds/TradPlus.h>
#import <TradPlusAds/MSConsentManager.h>
#import <BUAdSDK/BUAdSDK.h>
#import <TradPlusAds/MsEvent.h>
#import <TradPlusAds/MsCommon.h>
#import <BUAdSDK/BUAdSDK.h>

#ifndef customGM_dispatch_main_async_safe
#define customGM_dispatch_main_async_safe(block)\
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }
#endif

@interface CustomGMSDKLoader()
{
    NSRecursiveLock *tableLock;
}

@property (nonatomic,assign)BOOL isIniting;
@property (nonatomic,strong)NSMutableArray *delegateArray;
@property (nonatomic, assign) BOOL openPersonalizedAd;
@end

@implementation CustomGMSDKLoader

+ (CustomGMSDKLoader *)sharedInstance
{
    static CustomGMSDKLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[CustomGMSDKLoader alloc] init];
    });
    return loader;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.openPersonalizedAd = YES;
        self.delegateArray = [[NSMutableArray alloc] init];
        tableLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

+ (NSString *)getSDKVersion
{
    NSMutableString *versionStr = [[NSMutableString alloc] initWithString:@""];
    [versionStr appendFormat:@"%@",[BUAdSDKManager SDKVersion]];
    return versionStr;
}

- (void)initWithAppID:(NSString *)appID
             delegate:(id <CustomGMLoaderDelegate>)delegate
{
    if(delegate != nil)
    {
        [tableLock lock];
        [self.delegateArray addObject:delegate];
        [tableLock unlock];
    }
    
    if(self.didInit)
    {
        [self initFinish];
        return;
    }
    if(self.isIniting)
    {
        return;
    }
    self.isIniting = YES;
    BUAdSDKConfiguration *configuration = [BUAdSDKConfiguration configuration];
    configuration.appID = appID;
    configuration.useMediation = YES;
    
//    configuration.debugLog = @(1);
    
    __weak typeof(self) weakSelf = self;
    [BUAdSDKManager startWithAsyncCompletionHandler:^(BOOL success, NSError *error) {
        weakSelf.isIniting = NO;
        if (success)
        {
            weakSelf.didInit = YES;
            customGM_dispatch_main_async_safe(^{
                [weakSelf initFinish];
            });
        }
        else
        {
            customGM_dispatch_main_async_safe(^{
                [weakSelf initFailWithError:error];
            });
        }
    }];
}

- (void)initFinish
{
    [tableLock lock];
    NSArray *array = [self.delegateArray copy];
    [self.delegateArray removeAllObjects];
    [tableLock unlock];
    for(id delegate in array)
    {
        [self finishWithDelegate:delegate];
    }
}

- (void)initFailWithError:(NSError *)error
{
    [tableLock lock];
    NSArray *array = [self.delegateArray copy];
    [self.delegateArray removeAllObjects];
    [tableLock unlock];
    for(id delegate in array)
    {
        [self failWithDelegate:delegate error:error];
    }
}

- (void)finishWithDelegate:(id <CustomGMLoaderDelegate>)delegate
{
    if(delegate && [delegate respondsToSelector:@selector(initFinish)])
    {
        [delegate initFinish];
    }
}

- (void)failWithDelegate:(id <CustomGMLoaderDelegate>)delegate error:(NSError *)error
{
    if(delegate && [delegate respondsToSelector:@selector(initFailWithError:)])
    {
        [delegate initFailWithError:error];
    }
}
- (void)setPersonalizedAd
{
    if(self.openPersonalizedAd != gTPOpenPersonalizedAd)
    {
        self.openPersonalizedAd = gTPOpenPersonalizedAd;
        NSString *isOpen = @"1";
        if(self.openPersonalizedAd)
        {
            [BUAdSDKConfiguration configuration].mediation.limitPersonalAds = @(0);
        }
        else
        {
            [BUAdSDKConfiguration configuration].mediation.limitPersonalAds = @(1);
            isOpen = @"0";
        }
        NSString *userExtData = [NSString stringWithFormat:@"[{\"name\":\"personal_ads_type\",\"value\":\"%@\"}]",isOpen];
        [BUAdSDKManager setUserExtData:userExtData];
    }
}
@end
