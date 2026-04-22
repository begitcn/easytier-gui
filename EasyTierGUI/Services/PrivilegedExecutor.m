#import "PrivilegedExecutor.h"

#import <Security/Security.h>

@implementation PrivilegedExecutor

static AuthorizationRef sAuthorizationRef = NULL;
static BOOL sIsAuthorized = NO;  // 缓存授权状态，避免重复弹出密码对话框

+ (BOOL)ensureAuthorized:(NSError * _Nullable __autoreleasing *)error {
    // 如果已经是 root 用户，直接返回成功
    if (geteuid() == 0) {
        sIsAuthorized = YES;
        return YES;
    }

    // 如果已经授权成功，直接返回，不再触发交互
    if (sIsAuthorized && sAuthorizationRef != NULL) {
        return YES;
    }

    // 创建授权引用
    if (sAuthorizationRef == NULL) {
        OSStatus createStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &sAuthorizationRef);
        if (createStatus != errAuthorizationSuccess) {
            if (error) {
                *error = [NSError errorWithDomain:@"EasyTierGUI"
                                             code:createStatus
                                         userInfo:@{NSLocalizedDescriptionKey: @"无法创建管理员授权会话"}];
            }
            return NO;
        }
    }

    // 请求授权权限（只在第一次时弹出密码对话框）
    AuthorizationItem authItem = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &authItem };
    AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize;
    OSStatus status = AuthorizationCopyRights(sAuthorizationRef, &rights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:@"EasyTierGUI"
                                         code:status
                                     userInfo:@{NSLocalizedDescriptionKey: @"管理员授权失败"}];
        }
        return NO;
    }

    // 授权成功，缓存状态
    sIsAuthorized = YES;
    return YES;
}

+ (NSString *)runCommand:(NSString *)command error:(NSError * _Nullable __autoreleasing *)error {
    // 如果已经授权，跳过 ensureAuthorized 的调用，直接使用缓存的授权引用
    // 这样避免每次执行命令时都触发 AuthorizationCopyRights
    if (!sIsAuthorized && ![self ensureAuthorized:error]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    const char *tool = "/bin/sh";
    char *args[] = { "-c", (char *)command.UTF8String, NULL };
    FILE *pipe = NULL;
    OSStatus status = AuthorizationExecuteWithPrivileges(sAuthorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);
#pragma clang diagnostic pop

    if (status != errAuthorizationSuccess || pipe == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:@"EasyTierGUI"
                                         code:status
                                     userInfo:@{NSLocalizedDescriptionKey: @"提权命令执行失败"}];
        }
        return nil;
    }

    NSMutableData *data = [NSMutableData data];
    char buffer[4096];
    size_t bytesRead = 0;
    while ((bytesRead = fread(buffer, 1, sizeof(buffer), pipe)) > 0) {
        [data appendBytes:buffer length:bytesRead];
    }
    fclose(pipe);

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

+ (BOOL)isAuthorizedCached {
    if (geteuid() == 0) {
        return YES;
    }
    return sIsAuthorized && sAuthorizationRef != NULL;
}

@end
