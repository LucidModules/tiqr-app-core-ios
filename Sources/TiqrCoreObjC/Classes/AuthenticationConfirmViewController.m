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

#import "AuthenticationConfirmViewController.h"
#import "AuthenticationPINViewController.h"
#import "AuthenticationSummaryViewController.h"
#import "AuthenticationFallbackViewController.h"
#import "ServiceContainer.h"
#import "OCRAWrapper.h"
#import "OCRAWrapper_v1.h"
#import "ErrorViewController.h"
#import "OCRAProtocol.h"
#import "External/MBProgressHUD.h"
@import TiqrCore;

@interface AuthenticationConfirmViewController ()

@property (nonatomic, strong) AuthenticationChallenge *challenge;
@property (nonatomic, strong) IBOutlet UILabel *loginConfirmLabel;
@property (nonatomic, strong) IBOutlet UILabel *loggedInAsLabel;
@property (nonatomic, strong) IBOutlet UILabel *toLabel;
@property (nonatomic, strong) IBOutlet UIButton *okButton;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *okButtonBottomConstraint;
@property (nonatomic, strong) IBOutlet UIButton *usePincodeButton;
@property (nonatomic, strong) IBOutlet UILabel *accountLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountIDLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel *serviceProviderDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *serviceProviderIdentifierLabel;
@property (nonatomic, copy) NSString *response;
@property (strong, nonatomic) IBOutlet UIView *nonTouchIDViewsContainer;

@end

@implementation AuthenticationConfirmViewController

- (instancetype)initWithAuthenticationChallenge:(AuthenticationChallenge *)challenge {
    self = [super initWithNibName:@"AuthenticationConfirmView" bundle:SWIFTPM_MODULE_BUNDLE];
    if (self != nil) {
        self.challenge = challenge;
    }
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
    self.loginConfirmLabel.text = NSLocalizedStringFromTableInBundle(@"confirm_authentication", nil, SWIFTPM_MODULE_BUNDLE, @"Are you sure you want to login?");
    self.loggedInAsLabel.text = NSLocalizedStringFromTableInBundle(@"you_will_be_logged_in_as", nil, SWIFTPM_MODULE_BUNDLE, @"You will be logged in as:");
    self.toLabel.text = NSLocalizedStringFromTableInBundle(@"to_service_provider", nil, SWIFTPM_MODULE_BUNDLE, @"to:");
    self.accountLabel.text = NSLocalizedStringFromTableInBundle(@"full_name", nil, SWIFTPM_MODULE_BUNDLE, @"Account");
    self.accountIDLabel.text = NSLocalizedStringFromTableInBundle(@"id", nil, SWIFTPM_MODULE_BUNDLE, @"Tiqr account ID");
    [self.okButton setTitle:NSLocalizedStringFromTableInBundle(@"ok_button", nil, SWIFTPM_MODULE_BUNDLE, @"OK") forState:UIControlStateNormal];
    self.okButton.layer.cornerRadius = 5;
    self.okButtonBottomConstraint.constant = 41;
    
    [self.usePincodeButton setTitle:NSLocalizedStringFromTableInBundle(@"pin_fallback_button", nil, SWIFTPM_MODULE_BUNDLE, @"Use pincode") forState:UIControlStateNormal];
    self.usePincodeButton.hidden = YES;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];

	self.identityDisplayNameLabel.text = self.challenge.identity.displayName;
    self.identityIdentifierLabel.text = self.challenge.identity.identifier;
	self.serviceProviderDisplayNameLabel.text = self.challenge.serviceProviderDisplayName;
	self.serviceProviderIdentifierLabel.text = self.challenge.serviceProviderIdentifier;
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.okButton.backgroundColor = [ThemeService shared].theme.brandColor;
}

- (void)authenticateWithBiometrics {
    SecretService *secretService = ServiceContainer.sharedInstance.secretService;

    NSMutableString *touchIDPrompt = [NSLocalizedStringFromTableInBundle(@"you_will_be_logged_in_as", nil, SWIFTPM_MODULE_BUNDLE, @"You will be logged in as:") mutableCopy];
    [touchIDPrompt appendString:@" "];
    [touchIDPrompt appendString:self.challenge.identity.displayName];
    [touchIDPrompt appendString:@"\n"];
    [touchIDPrompt appendString:NSLocalizedStringFromTableInBundle(@"to_service_provider", nil, SWIFTPM_MODULE_BUNDLE, @"to:")];
    [touchIDPrompt appendString:@" "];
    [touchIDPrompt appendString:self.challenge.serviceProviderDisplayName];

    [secretService secretForIdentity:self.challenge.identity touchIDPrompt:touchIDPrompt withSuccessHandler:^(NSData *secret) {
        [self completeAuthenticationWithSecret:secret];
    } failureHandler:^(BOOL cancelled) {
        if ([self.challenge.identity.usesOldBiometricFlow boolValue]) {
            // nothing we can do for old accounts but cancel the flow
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        
        // Let the user retry or select the pin flow if desired
        [self showPinFallback];
    }];
}

- (void)completeAuthenticationWithSecret:(NSData *)secret {
    ChallengeService *challengeService = ServiceContainer.sharedInstance.challengeService;

    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    [challengeService completeAuthenticationChallenge:self.challenge withSecret:secret completionHandler:^(BOOL succes, NSString *response, NSError *error) {

        [MBProgressHUD hideHUDForView:self.view animated:YES];

        if (succes) {
            AuthenticationSummaryViewController *viewController = [[AuthenticationSummaryViewController alloc] initWithAuthenticationChallenge:self.challenge usedPIN:nil];
            [self.navigationController pushViewController:viewController animated:YES];
        } else  {
            switch ([error code]) {
                case TIQRACRConnectionError: {
                    AuthenticationFallbackViewController *viewController = [[AuthenticationFallbackViewController alloc] initWithAuthenticationChallenge:self.challenge response:response];
                    [self.navigationController pushViewController:viewController animated:YES];
                    break;
                }

                case TIQRACRAccountBlockedError: {
                    self.challenge.identity.blocked = @YES;
                    [ServiceContainer.sharedInstance.identityService saveIdentities];

                    [self presentErrorViewControllerWithError:error];
                    break;
                }
                case TIQRACRInvalidResponseError: {
                    NSNumber *attemptsLeft = [error userInfo][TIQRACRAttemptsLeftErrorKey];
                    if (attemptsLeft != nil && [attemptsLeft intValue] == 0) {
                        [ServiceContainer.sharedInstance.identityService blockAllIdentities];
                        [ServiceContainer.sharedInstance.identityService saveIdentities];
                    }

                    [self presentErrorViewControllerWithError:error];
                    break;
                }

                default: {
                    [self presentErrorViewControllerWithError:error];
                    break;
                }
            }
        }
    }];
}

- (void)presentErrorViewControllerWithError:(NSError *)error {
    UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)ok {
    if (self.challenge.identity.usesBiometrics && [self.challenge.identity.biometricIDEnabled boolValue]) {
        [self authenticateWithBiometrics];
    } else {
        [self usePinFallback];
    }
}

- (void)showPinFallback {
    self.okButtonBottomConstraint.constant = 100;
    self.usePincodeButton.hidden = NO;
}

- (IBAction)usePinFallback {
    [self presentPincodeViewController];
}

- (void)presentPincodeViewController {
    AuthenticationPINViewController *viewController = [[AuthenticationPINViewController alloc] initWithAuthenticationChallenge:self.challenge];
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
