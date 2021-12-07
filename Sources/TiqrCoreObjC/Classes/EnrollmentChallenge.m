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

#import "EnrollmentChallenge.h"
#import "NSString+DecodeURL.h"
#import "ServiceContainer.h"
#import "TiqrConfig.h"

NSString *const TIQRECErrorDomain = @"org.tiqr.ec";

@interface EnrollmentChallenge ()

@property (nonatomic, copy) NSString *identityProviderIdentifier;
@property (nonatomic, copy) NSString *identityProviderDisplayName;
@property (nonatomic, copy) NSString *identityProviderAuthenticationUrl;
@property (nonatomic, copy) NSString *identityProviderInfoUrl;
@property (nonatomic, copy) NSString *identityProviderOcraSuite;
@property (nonatomic, copy) NSData *identityProviderLogo;

@property (nonatomic, copy) NSString *identityIdentifier;
@property (nonatomic, copy) NSString *identityDisplayName;

@property (nonatomic, copy) NSString *enrollmentUrl;
@property (nonatomic, copy) NSString *returnUrl;

@end

@implementation EnrollmentChallenge

+ (BOOL)applyError:(NSError *)error toError:(NSError **)otherError {
    if (otherError != NULL) {
        *otherError = error;
    }
    
    return YES;
}

+ (EnrollmentChallenge *)challengeWithChallengeString:(NSString *)challengeString allowFiles:(BOOL)allowFiles error:(NSError **)error {
    NSURL *fullURL = [NSURL URLWithString:challengeString];
    
    EnrollmentChallenge *challenge = [[EnrollmentChallenge alloc] init];
    
    if (fullURL == nil || ![TiqrConfig isValidEnrollmentScheme:fullURL.scheme]) {
        NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_qr_code", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_response", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [self applyError:[NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details] toError:error];
        return nil;
    }
    
    NSURL *url = [NSURL URLWithString:[challengeString substringFromIndex:13]];
    if (url == nil) {
        NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_qr_code", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_response", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [self applyError:[NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details] toError:error];
        return nil;
    }
    
    if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"] && ![url.scheme isEqualToString:@"file"]) {
        NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_qr_code", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_response", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [self applyError:[NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details] toError:error];
        return nil;
    } else if ([url.scheme isEqualToString:@"file"] && !allowFiles) {
        NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_qr_code", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_response", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [self applyError:[NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidQRTagError userInfo:details] toError:error];
        return nil;
    }
    
    NSError *downloadError = nil;
    NSData *data = [challenge downloadSynchronously:url error:&downloadError];
    if (downloadError != nil) {
        NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"no_connection", nil, SWIFTPM_MODULE_BUNDLE, @"No connection title");
        NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"internet_connection_required", nil, SWIFTPM_MODULE_BUNDLE, @"You need an Internet connection to activate your account. Please try again later.");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage, NSUnderlyingErrorKey: downloadError};
        [self applyError:[NSError errorWithDomain:TIQRECErrorDomain code:TIQRECConnectionError userInfo:details] toError:error];
        return nil;
    }
    
    NSDictionary *metadata = nil;
    
    @try {
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([object isKindOfClass:[NSDictionary class]]) {
            metadata = object;
        }
    } @catch (NSException *exception) {
        metadata = nil;
    }
    
    if (metadata == nil || ![challenge isValidMetadata:metadata]) {
        NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_response_title", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid response title");
        NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"error_enroll_invalid_response", nil, SWIFTPM_MODULE_BUNDLE, @"Invalid response message");
        NSDictionary *details;
        details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [self applyError:[NSError errorWithDomain:TIQRECErrorDomain code:TIQRECInvalidResponseError userInfo:details] toError:error];
        return nil;
    }
    
    NSMutableDictionary *identityProviderMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata[@"service"]];
    
    [self applyError:[challenge assignIdentityProviderMetadata:identityProviderMetadata] toError:error];
    if (*error) {
        return nil;
    }
    
    NSDictionary *identityMetadata = metadata[@"identity"];
    NSError *assignError = [challenge assignIdentityMetadata:identityMetadata];
    if (assignError) {
       [self applyError:assignError toError:error];
        return nil;
    }
    
    NSString *regex = @"^http(s)?://.*";
    NSPredicate *protocolPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    if (url.query != nil && [url.query length] > 0 && [protocolPredicate evaluateWithObject:url.query] == YES) {
        challenge.returnUrl = url.query.decodedURL;
    } else {
        challenge.returnUrl = nil;
    }
    
    challenge.returnUrl = nil; // TODO: support return URL url.query == nil || [url.query length] == 0 ? nil : url.query;
    challenge.enrollmentUrl = [identityProviderMetadata[@"enrollmentUrl"] description];
    
    return challenge;
    
}

- (BOOL)isValidMetadata:(NSDictionary *)metadata {
    // TODO: service => identityProvider 
	if ([metadata valueForKey:@"service"] == nil ||
		[metadata valueForKey:@"identity"] == nil) {
		return NO;
	}

	// TODO: improve validation
    
	return YES;
}

- (NSData *)downloadSynchronously:(NSURL *)url error:(NSError **)error {
	NSURLResponse *response = nil;
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
	return data;
}

- (NSError *)assignIdentityProviderMetadata:(NSDictionary *)metadata {
	self.identityProviderIdentifier = [metadata[@"identifier"] description];
	self.identityProvider = [ServiceContainer.sharedInstance.identityService findIdentityProviderWithIdentifier:self.identityProviderIdentifier];

	if (self.identityProvider != nil) {
		self.identityProviderDisplayName = self.identityProvider.displayName;
		self.identityProviderAuthenticationUrl = self.identityProvider.authenticationUrl;	
        self.identityProviderOcraSuite = self.identityProvider.ocraSuite;
		self.identityProviderLogo = self.identityProvider.logo;
	} else {
		NSURL *logoUrl = [NSURL URLWithString:[metadata[@"logoUrl"] description]];		
		NSError *error = nil;		
		NSData *logo = [self downloadSynchronously:logoUrl error:&error];
		if (error != nil) {
            NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_logo_error_title", nil, SWIFTPM_MODULE_BUNDLE, @"No identity provider logo");
            NSString *errorMessage = NSLocalizedStringFromTableInBundle(@"error_enroll_logo_error", nil, SWIFTPM_MODULE_BUNDLE, @"No identity provider logo message");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage, NSUnderlyingErrorKey: error};
            return [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECIdentityProviderLogoError userInfo:details];
		}
		
		self.identityProviderDisplayName =  [metadata[@"displayName"] description];
		self.identityProviderAuthenticationUrl = [metadata[@"authenticationUrl"] description];	
		self.identityProviderInfoUrl = [metadata[@"infoUrl"] description];        
        self.identityProviderOcraSuite = [metadata[@"ocraSuite"] description];
		self.identityProviderLogo = logo;
	}	
	
	return nil;
}

- (NSError *)assignIdentityMetadata:(NSDictionary *)metadata {
	self.identityIdentifier = [metadata[@"identifier"] description];
	self.identityDisplayName = [metadata[@"displayName"] description];
	self.identitySecret = nil;
	
	if (self.identityProvider != nil) {
        Identity *identity = [ServiceContainer.sharedInstance.identityService findIdentityWithIdentifier:self.identityIdentifier forIdentityProvider:self.identityProvider];
		if (identity != nil && [identity.blocked boolValue]) {
            self.identity = identity;
        } else if (identity != nil) {
            NSString *errorTitle = NSLocalizedStringFromTableInBundle(@"error_enroll_already_enrolled_title", nil, SWIFTPM_MODULE_BUNDLE, @"Account already activated");
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"error_enroll_already_enrolled", nil, SWIFTPM_MODULE_BUNDLE, @"Account already activated message"), self.identityDisplayName, self.identityProviderDisplayName];
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            return [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECAccountAlreadyExistsError userInfo:details];
		}
	}
								 
	return nil;
}


@end
