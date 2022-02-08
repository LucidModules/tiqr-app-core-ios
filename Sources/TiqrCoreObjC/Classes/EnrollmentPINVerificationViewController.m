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

#import "EnrollmentPINVerificationViewController.h"
#import "EnrollmentSummaryViewController.h"
#import "EnrollmentConfirmationRequest.h"
#import "IdentityProvider.h"
#import "ErrorViewController.h"
#import "External/MBProgressHUD.h"
#import "ServiceContainer.h"
#import "NSString+LocalizedBiometricString.h"
@import TiqrCore;

@interface EnrollmentPINVerificationViewController ()

@property (nonatomic, strong) EnrollmentChallenge *challenge;
@property (nonatomic, copy) NSString *PIN;
@property (nonatomic, strong) NSData *responseData;

@end

@implementation EnrollmentPINVerificationViewController

- (instancetype)initWithEnrollmentChallenge:(EnrollmentChallenge *)challenge PIN:(NSString *)PIN {
    self = [super init];
    if (self != nil) {
        self.challenge = challenge;
        self.PIN = PIN;
        self.delegate = self;
    }
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.subtitle = [Localization localize:@"login_verify_intro" comment:@"Enrollment PIN verification title"];
    self.pinDescription = [Localization localize:@"login_verify_message" comment:@"Enter your PIN code again for verification. Please note the animal icon. This will help you remember your PIN code."];
    self.pinNotes = [Localization localize:@"remember_pincode_notice" comment:@"Remember your PIN, it cannot be changed!"];
}

- (void)PINViewController:(PINViewController *)viewController didFinishWithPIN:(NSString *)PIN {
    if (![PIN isEqualToString:self.PIN]) {
        [self clear];
        NSString *errorTitle = [Localization localize:@"passwords_dont_match_title" comment:@"Error title if PIN's don't match"];
        NSString *errorMessage = [Localization localize:@"passwords_dont_match" comment:@"Error message if PINs don't match"];
        [self showErrorWithTitle:errorTitle message:errorMessage];
        [self.view endEditing:YES];
        return;
    }
    
    [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    if (ServiceContainer.sharedInstance.secretService.biometricIDAvailable) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[Localization localize:@"upgrade_to_biometric_id" comment:@"Upgrade account to TouchID alert title"]  message:LocalizedBiometricString(@"upgrade_to_touch_id_message", @"upgrade_to_face_id_message") preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:[Localization localize:@"upgrade" comment:@"Upgrade (to TouchID)"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self completeEnrollmentWith:PIN usingBiometrics:YES];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:[Localization localize:@"cancel" comment:@"Cancel"] style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self completeEnrollmentWith:PIN usingBiometrics:NO];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self completeEnrollmentWith:PIN usingBiometrics:NO];
    }
}

- (void)completeEnrollmentWith:(NSString *)PIN usingBiometrics:(BOOL)usebiometricID {
    
    [ServiceContainer.sharedInstance.challengeService completeEnrollmentChallenge:self.challenge usingBiometricID:usebiometricID withPIN:PIN completionHandler:^(BOOL succes, NSError *error) {
        
        [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
        
        if (succes) {
            EnrollmentSummaryViewController *viewController = [[EnrollmentSummaryViewController alloc] initWithEnrollmentChallenge:self.challenge];
            [self.navigationController pushViewController:viewController animated:YES];
        } else {
            UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
            [self.navigationController pushViewController:viewController animated:YES];
        }
    }];
}


@end
