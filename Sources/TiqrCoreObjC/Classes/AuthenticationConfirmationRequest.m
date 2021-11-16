/*
 * Copyright (c) 2010-2011 SURFnet bv
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of SURFnet bv nor the names of its contributors 
 *    may be used to endorse or promote products derived from this 
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AuthenticationConfirmationRequest.h"
#import "NotificationRegistration.h"
#import "TiqrConfig.h"

NSString *const TIQRACRErrorDomain = @"org.tiqr.acr";
NSString *const TIQRACRAttemptsLeftErrorKey = @"AttempsLeftErrorKey";

typedef void (^CompletionBlock)(BOOL success, NSError *error);

@interface AuthenticationConfirmationRequest ()

@property (nonatomic, strong) AuthenticationChallenge *challenge;
@property (nonatomic, copy) NSString *response;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, copy) NSString *protocolVersion;
@property (nonatomic, strong) NSURLConnection *sendConnection;
@property (nonatomic, strong) CompletionBlock completionBlock;

@end

@implementation AuthenticationConfirmationRequest

- (instancetype)initWithAuthenticationChallenge:(AuthenticationChallenge *)challenge response:(NSString *)response {
    self = [super init];
    if (self != nil) {
        self.challenge = challenge;
        self.response = response;
    }
    
    return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.data setLength:0];
    
    NSDictionary* headers = [(NSHTTPURLResponse *)response allHeaderFields];
    if (headers[@"X-TIQR-Protocol-Version"]) {
        self.protocolVersion = headers[@"X-TIQR-Protocol-Version"];
    } else {
        self.protocolVersion = @"1";
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)connectionError {
    self.data = nil;
    
    NSString *title = NSLocalizedStringFromTableInBundle(@"no_connection", nil, SWIFTPM_MODULE_BUNDLE, @"No connection error title");
    NSString *message = NSLocalizedStringFromTableInBundle(@"no_active_internet_connection.", nil, SWIFTPM_MODULE_BUNDLE, @"You appear to have no active Internet connection.");
    NSMutableDictionary *details = [NSMutableDictionary dictionary];
    [details setValue:title forKey:NSLocalizedDescriptionKey];
    [details setValue:message forKey:NSLocalizedFailureReasonErrorKey];    
    [details setValue:connectionError forKey:NSUnderlyingErrorKey];
    
    NSError *error = [NSError errorWithDomain:TIQRACRErrorDomain code:TIQRACRConnectionError userInfo:details];
    self.completionBlock(false, error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {

    if (self.protocolVersion != nil && [self.protocolVersion intValue] > 1) {
        // Parse JSON result
        id result = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:nil];
        self.data = nil;
        
        NSNumber *responseCode = @([[result valueForKey:@"responseCode"] intValue]);
        if ([responseCode intValue] == AuthenticationChallengeResponseCodeSuccess) {
            self.completionBlock(true, nil);
        } else {
            NSInteger code = TIQRACRUnknownError;
            NSString *title = NSLocalizedStringFromTableInBundle(@"unknown_error", nil, SWIFTPM_MODULE_BUNDLE, @"Unknown error title");
            NSString *message = NSLocalizedStringFromTableInBundle(@"error_auth_unknown_error", nil, SWIFTPM_MODULE_BUNDLE, @"Unknown error message");
            NSNumber *attemptsLeft = nil;
            
            switch ([responseCode intValue]) {
                case AuthenticationChallengeResponseCodeAccountBlocked: {
                    if ([result valueForKey:@"duration"] != nil) {
                        NSNumber *duration = @([[result valueForKey:@"duration"] intValue]);
                        code = TIQRACRAccountBlockedErrorTemporary;
                        title = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_temporary_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (account blocked temporary)");
                        message = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_temporary_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (account blocked temporary"), duration];
                    } else {
                        code = TIQRACRAccountBlockedError;
                        title = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (0 attempts left)");
                        message = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (0 attempts left)");
                    }
                } break;
                    
                case AuthenticationChallengeResponseCodeInvalidChallenge: {
                    code = TIQRACRInvalidChallengeError;
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_challenge_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_CHALLENGE error title");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_challenge_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_CHALLENGE error message");
                } break;
                    
                case AuthenticationChallengeResponseCodeInvalidRequest: {
                    code = TIQRACRInvalidRequestError;
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_request_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_REQUEST error title");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_request_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_REQUEST error message");
                } break;
                    
                case AuthenticationChallengeResponseCodeInvalidUsernamePasswordPin: {                    code = TIQRACRInvalidResponseError;
                    if ([result valueForKey:@"attemptsLeft"] != nil) {
                        attemptsLeft = @([[result valueForKey:@"attemptsLeft"] intValue]);
                        if ([attemptsLeft intValue] > 1) {
                            title = NSLocalizedStringFromTableInBundle(@"error_auth_wrong_pin", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (> 1 attempts left)");
                            message = NSLocalizedStringFromTableInBundle(@"error_auth_x_attempts_left", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (> 1 attempts left)");
                            message = [NSString stringWithFormat:message, [attemptsLeft intValue]];
                        } else if ([attemptsLeft intValue] == 1) {
                            title = NSLocalizedStringFromTableInBundle(@"error_auth_wrong_pin", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (1 attempt left)");
                            message = NSLocalizedStringFromTableInBundle(@"error_auth_one_attempt_left", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (1 attempt left)");
                        } else {
                            title = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (0 attempts left)");
                            message = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (0 attempts left)");
                        }
                    } else {
                        title = NSLocalizedStringFromTableInBundle(@"error_auth_wrong_pin", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (infinite attempts left)");
                        message = NSLocalizedStringFromTableInBundle(@"error_auth_infinite_attempts_left", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE erorr message (infinite attempts left)");
                    }
                } break;
                
                case AuthenticationChallengeResponseCodeInvalidUser: {
                    code = TIQRACRInvalidUserError;
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_account", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_USERID error title");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_account_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_USERID error message");
                } break;
                    
                default: {
                    code = TIQRACUnknownError;
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_unknown_reponsecode", nil, SWIFTPM_MODULE_BUNDLE, @"UNKNOWN_RESPONSE_CODE error title");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_unknown_reponsecode_message", nil, SWIFTPM_MODULE_BUNDLE, @"UNKNOWN_RESPONSE_CODE error message");
                }
            }
            
            NSString *serverMessage = [result valueForKey:@"message"];
            if (serverMessage) {
                message = serverMessage;
            }
            
            NSMutableDictionary *details = [NSMutableDictionary dictionary];
            [details setValue:title forKey:NSLocalizedDescriptionKey];
            [details setValue:message forKey:NSLocalizedFailureReasonErrorKey];
            if (attemptsLeft != nil) {
                [details setValue:attemptsLeft forKey:TIQRACRAttemptsLeftErrorKey];
            }
            
            NSError *error = [NSError errorWithDomain:TIQRACRErrorDomain code:code userInfo:details];
            self.completionBlock(false, error);
        }
    } else {
        // Parse String result
        NSString *response = [[NSString alloc] initWithBytes:[self.data bytes] length:[self.data length] encoding:NSUTF8StringEncoding];
        if ([response isEqualToString:@"OK"]) {
            self.completionBlock(true, nil);
        } else {
            NSInteger code = TIQRACRUnknownError;
            NSString *title = NSLocalizedStringFromTableInBundle(@"unknown_error", nil, SWIFTPM_MODULE_BUNDLE, @"Unknown error title");
            NSString *message = NSLocalizedStringFromTableInBundle(@"error_auth_unknown_error", nil, SWIFTPM_MODULE_BUNDLE, @"Unknown error message");
            NSNumber *attemptsLeft = nil;
            if ([response isEqualToString:@"ACCOUNT_BLOCKED"]) {
                code = TIQRACRAccountBlockedError;
                title = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (0 attempts left)");
                message = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (0 attempts left)");
            } else if ([response isEqualToString:@"INVALID_CHALLENGE"]) {
                code = TIQRACRInvalidChallengeError;
                title = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_challenge_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_CHALLENGE error title");
                message = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_challenge_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_CHALLENGE error message");
            } else if ([response isEqualToString:@"INVALID_REQUEST"]) {
                code = TIQRACRInvalidRequestError;
                title = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_request_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_REQUEST error title");
                message = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_request_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_REQUEST error message");
            } else if ([response length]>=17 && [[response substringToIndex:17] isEqualToString:@"INVALID_RESPONSE:"]) {
                attemptsLeft = @([[response substringFromIndex:17] intValue]);
                code = TIQRACRInvalidResponseError;
                if ([attemptsLeft intValue] > 1) {
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_wrong_pin", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (> 1 attempts left)");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_x_attempts_left", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (> 1 attempts left)");
                    message = [NSString stringWithFormat:message, [attemptsLeft intValue]];
                } else if ([attemptsLeft intValue] == 1) {
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_wrong_pin", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (1 attempt left)");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_one_attempt_left", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (1 attempt left)");
                } else {
                    title = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_title", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error title (0 attempts left)");
                    message = NSLocalizedStringFromTableInBundle(@"error_auth_account_blocked_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_RESPONSE error message (0 attempts left)");
                }
            } else if ([response isEqualToString:@"INVALID_USERID"]) {
                code = TIQRACRInvalidUserError;
                title = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_account", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_USERID error title");
                message = NSLocalizedStringFromTableInBundle(@"error_auth_invalid_account_message", nil, SWIFTPM_MODULE_BUNDLE, @"INVALID_USERID error message");
            }
            
            NSMutableDictionary *details = [NSMutableDictionary dictionary];
            [details setValue:title forKey:NSLocalizedDescriptionKey];
            [details setValue:message forKey:NSLocalizedFailureReasonErrorKey];
            if (attemptsLeft != nil) {
                [details setValue:attemptsLeft forKey:TIQRACRAttemptsLeftErrorKey];
            }
            
            NSError *error = [NSError errorWithDomain:TIQRACRErrorDomain code:code userInfo:details];
            self.completionBlock(false, error);
        }
    }
    
}

- (void)sendWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler {
    self.completionBlock = completionHandler;
    
	NSString *escapedSessionKey = [self.challenge.sessionKey stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *escapedUserId = [self.challenge.identity.identifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *escapedResponse = [self.response stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *escapedLanguage = [NSLocale preferredLanguages][0];
	NSString *notificationToken = [NotificationRegistration sharedInstance].notificationToken;
	NSString *escapedNotificationToken = [notificationToken stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *operation = @"login";
    NSString *version = [TiqrConfig valueForString:@"TIQRProtocolVersion"];

	NSString *body = [NSString stringWithFormat:@"sessionKey=%@&userId=%@&response=%@&language=%@&notificationType=APNS&notificationAddress=%@&operation=%@&version=%@", escapedSessionKey, escapedUserId, escapedResponse, escapedLanguage, escapedNotificationToken, operation, version];
        
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.challenge.identityProvider.authenticationUrl]];
	[request setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	[request setTimeoutInterval:5.0];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:version forHTTPHeaderField:@"X-TIQR-Protocol-Version"];
    
    self.data = [NSMutableData data];
	self.sendConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}


@end
