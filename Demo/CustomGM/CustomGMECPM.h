#import <Foundation/Foundation.h>
#import <BUAdSDK/BUAdSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomGMECPM : NSObject

+ (nullable NSString *)getECPMWithMediation:(id )mediation;
+ (nullable NSString *)getECPMWithFullscreenVideoAdMediation:(BUNativeExpressFullscreenVideoAdMediation *)mediation;
@end

NS_ASSUME_NONNULL_END
