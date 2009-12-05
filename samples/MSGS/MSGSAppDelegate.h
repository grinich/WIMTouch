//
//  MSGSAppDelegate.h
//  MSGS
//
//  Created by Michael Grinich on 4/21/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WIMTouch.h"
#import "WIMConstants.h"


@interface MSGSAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate> {
    UIWindow *window;
    UITabBarController *tabBarController;
	
	
	// State
	NSDictionary *latestBuddyList;
	NSMutableArray *tableBuddyList;
	
	NSMutableArray *allMessages;
	
	IBOutlet UINavigationController *messagesNavigationController;
	
	IBOutlet UITableView *messageTableView;
	IBOutlet UITextField *aimDeveloperKey;
	
	IBOutlet UITextField *password;
	IBOutlet UITextField *username;

	IBOutlet UIButton *forceCaptcha;
	
	IBOutlet UITextField *to;
	IBOutlet UITextField *message;
	
	IBOutlet UITextView *sessionLog;

//	// outlets for secondary challenges  
	IBOutlet id securIdPanel;
	IBOutlet UITextField *securId;
	
	IBOutlet id captchaPanel;
	IBOutlet UITextField *captcha;
	IBOutlet UIImageView *captchaImage;
	
	IBOutlet id passwordPanel;
	IBOutlet UITextField *challengePassword;
	
	WimSession *wimSession;
	
	NSString *awayMessage;
	NSString *statusMessage;
	
	NSAttributedString *profileMessage;
	
	int _status;
	BOOL _connected;
	
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UITabBarController *tabBarController;
@property (nonatomic, retain) NSDictionary *latestBuddyList;
@property (nonatomic, retain) NSMutableArray *tableBuddyList;
@property (nonatomic, retain) IBOutlet UINavigationController *messagesNavigationController;
@property (nonatomic, retain) NSMutableArray *allMessages;


- (IBAction)onSignOff:(id)sender;
- (IBAction)onSignOn:(id)sender;
- (IBAction)onSend:(id)sender;

- (void)onSendWithMessage:(NSString *)m recipient:(NSString *)r;


- (IBAction)onPresence:(id)sender;

- (IBAction)compose:(id)sender;

- (IBAction)clearHistory:(id)sender;

//- (IBAction)closeCustomSheet:(id)sender;	// This is for the additional popup window

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

// Required? 
- (void)appendLog:(NSString *)aMessage ;

@end
