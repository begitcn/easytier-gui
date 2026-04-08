#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrivilegedExecutor : NSObject

+ (BOOL)ensureAuthorized:(NSError * _Nullable * _Nullable)error;
+ (nullable NSString *)runCommand:(NSString *)command error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
