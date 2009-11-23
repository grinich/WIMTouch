/* 
 Copyright (c) 2008 AOL LLC
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
 in the documentation and/or other materials provided with the distribution.
 Neither the name of the AOL LCC nor the names of its contributors may be used to endorse or promote products derived 
 from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import <Cocoa/Cocoa.h>

#import <WIMFramework/WimSession.h>
#import <WimFramework/WimEvents.h>

@class WimSession;

@interface WimWindowController : NSWindowController <WimSessionDelegate>
{
  // a key is required to access the WIM Web API's --- get your key at http://developer.aim.com
  IBOutlet NSTextField *aimDeveloperKey;
  
  IBOutlet NSTextField *password;
  IBOutlet NSTextField *username;
  
  IBOutlet NSButton *forceCaptcha;

  IBOutlet NSTextField *to;
  IBOutlet NSTextField *message;
  
  IBOutlet NSTextView *sessionLog;

// outlets for secondary challenges  
  IBOutlet id securIdPanel;
  IBOutlet NSTextField *securId;

  IBOutlet id captchaPanel;
  IBOutlet NSTextField *captcha;
  IBOutlet NSImageView *captchaImage;
  
  IBOutlet id passwordPanel;
  IBOutlet NSTextField *challengePassword;
  
  WimSession *wimSession;

  NSString *awayMessage;
  NSString *statusMessage;
  
  NSAttributedString *profileMessage;
  
  int _status;
  BOOL _connected;
}
- (IBAction)onSignOff:(id)sender;
- (IBAction)onSignOn:(id)sender;
- (IBAction)onSend:(id)sender;
- (IBAction)onPresence:(id)sender;

- (IBAction)clearHistory:(id)sender;

- (IBAction)closeCustomSheet:(id)sender;

- (void)setAwayMessage:(NSString *)aAwayMessage;
- (NSString *)awayMessage;

- (void)setStatusMessage:(NSString *)aMessage;
- (NSString *)statusMessage;

- (void)setProfileMessage:(NSAttributedString *)aMessage;
- (NSAttributedString *)profileMessage;

- (int)status;
- (void)setStatus:(int)status;

- (BOOL)connected;
- (BOOL)online;
@end


