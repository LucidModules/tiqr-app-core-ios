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

#import "AuthenticationFallbackViewController.h"
#import "TiqrCoreManager.h"
#import "ServiceContainer.h"
#import <UIKit/UIKit.h>

@interface AuthenticationFallbackViewController ()

@property (nonatomic, strong) AuthenticationChallenge *challenge;
@property (nonatomic, copy) NSString *response;
@property (nonatomic, strong) IBOutlet UILabel *errorTitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *errorInstructionLabel;
@property (nonatomic, strong) IBOutlet UILabel *yourIdLabel;
@property (nonatomic, strong) IBOutlet UILabel *oneTimeLoginCodeLabel;
@property (nonatomic, strong) IBOutlet UILabel *unverifiedPinLabel;
@property (nonatomic, strong) IBOutlet UILabel *retryLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel *oneTimePasswordLabel;

@end

@implementation AuthenticationFallbackViewController

- (instancetype)initWithAuthenticationChallenge:(AuthenticationChallenge *)challenge response:(NSString *)response {
    self = [super initWithNibName:@"AuthenticationFallbackView" bundle:SWIFTPM_MODULE_BUNDLE];
    if (self != nil) {
        self.challenge = challenge;
        self.response = response;
    }
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
    self.errorTitleLabel.text = NSLocalizedStringFromTableInBundle(@"authentication_fallback_title", nil, SWIFTPM_MODULE_BUNDLE, @"You appear to be offline");
    self.errorInstructionLabel.text = NSLocalizedStringFromTableInBundle(@"authentication_fallback_description", nil, SWIFTPM_MODULE_BUNDLE, @"Don\'t worry! Click the QR tag on the\nwebsite. You will be asked to enter the\nfollowing one-time credentials:");
    self.yourIdLabel.text = NSLocalizedStringFromTableInBundle(@"fallback_identifier_label", nil, SWIFTPM_MODULE_BUNDLE, @"Your ID is:");
    self.oneTimeLoginCodeLabel.text = NSLocalizedStringFromTableInBundle(@"otp_label", nil, SWIFTPM_MODULE_BUNDLE, @"One time password:");
    self.unverifiedPinLabel.text = NSLocalizedStringFromTableInBundle(@"note_pin_not_verified_title", nil, SWIFTPM_MODULE_BUNDLE, @"Note: your PIN has not been verified yet.");
    self.retryLabel.text = NSLocalizedStringFromTableInBundle(@"note_pin_not_verified", nil, SWIFTPM_MODULE_BUNDLE, @"If you can\'t login with the credentials above, scan\nagain and enter the correct PIN code.");
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];        
	
	self.identityIdentifierLabel.text = self.challenge.identity.identifier;
    self.oneTimePasswordLabel.text = self.response;
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (void)done {
    [TiqrCoreManager.sharedInstance popToStartViewControllerAnimated:YES];
}

@end
