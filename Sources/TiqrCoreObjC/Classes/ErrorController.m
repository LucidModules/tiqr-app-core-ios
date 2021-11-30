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

#import "ErrorController.h"
#import <UIKit/UIKit.h>
@import TiqrCore;

@interface ErrorController ()

@property (nonatomic, strong) IBOutlet UIView *view;
@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *messageLabel;

@end


@implementation ErrorController

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        UINib *nib = [UINib nibWithNibName:@"ErrorView" bundle:SWIFTPM_MODULE_BUNDLE];
        [nib instantiateWithOwner:self options:nil];
        
        self.view.translatesAutoresizingMaskIntoConstraints = NO;
    }
    
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];

    self.titleLabel.font = [ThemeService shared].theme.headerFont;
    self.messageLabel.font = [ThemeService shared].theme.bodyFont;
}

- (void)addToView:(UIView *)view {
    [self.view removeFromSuperview];
    [view addSubview:self.view];
    
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[errorView]|" options:0 metrics:nil views:@{@"errorView" : self.view}]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[errorView]|" options:0 metrics:nil views:@{@"errorView" : self.view}]];
}

- (NSString *)title {
    return self.titleLabel.text;
}

- (void)setTitle:(NSString *)title {
    self.titleLabel.text = title;
}

- (NSString *)message {
    return self.messageLabel.text;
}

- (void)setMessage:(NSString *)message {
    self.messageLabel.text = message;
}


@end
