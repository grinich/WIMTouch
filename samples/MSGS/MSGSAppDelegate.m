//
//  MSGSAppDelegate.m
//  MSGS
//
//  Created by Michael Grinich on 4/21/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import "MSGSAppDelegate.h"
#import "ComposeViewController.h"



// Our MSGS dev api key
NSString *kTestHarnessDevId = @"tb17-IMEDLqnPUbO";

NSString *kClientName = @"WIMTestHarness";
NSString *kClientVersion = @"0.1";


NSString *kScreenNamePref = @"screenName";
NSString *kPasswordPref = @"password";
NSString *kDevIdPref = @"developerKey";


@implementation MSGSAppDelegate

@synthesize window;
@synthesize tabBarController;
@synthesize latestBuddyList, tableBuddyList;
@synthesize allMessages;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
    
    // Add the tab bar controller's current view as a subview of the window
    [window addSubview:tabBarController.view];
	
	kAPIBaseURL = kProdAPIBaseURL;
	kAuthBaseURL = kProdAuthBaseURL;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys: 
								 @"" , kScreenNamePref ,
								 @"" , kPasswordPref ,
								 kTestHarnessDevId, kDevIdPref,
								 nil ];
	
	[defaults registerDefaults:appDefaults];
	
	
	wimSession = [[WimSession alloc] init];
    [wimSession setClientName:kClientName];
    [wimSession setClientVersion:kClientVersion];
	
	
	// WimSession will post notifications as the session goes online and offline
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWimSessionConnectionStateChange:) 
												 name:kWimClientConnectionStateChange object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWimSessionEnded:) 
												 name:kWimSessionSessionEndedEvent object:nil];
	
	
	// http://dev.aol.com/aim/web/serverapi_reference
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onIMSentEvent:) name:kWimClientIMSent object:nil];
	
	
	[defaults setValue:kScreenNamePref forKey:kScreenNamePref];
	[defaults setValue:kPasswordPref forKey:kPasswordPref];
	[defaults setValue:kTestHarnessDevId forKey:kDevIdPref];
	
	
	
	// load our default values
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[username setText:[defaults valueForKey:kScreenNamePref]];
	[password setText:[defaults valueForKey:kPasswordPref]];
	[aimDeveloperKey setText:[defaults valueForKey:kDevIdPref]];
	
	allMessages = [NSMutableArray new];
	
	
}


/*
// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
}
*/

/*
// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
}
*/


- (void)dealloc {
    [tabBarController release];
    [window release];
	[wimSession release];
	[[NSNotificationCenter defaultCenter] removeObject:self];
    [super dealloc];
}



#pragma mark Compose Button

- (IBAction)compose:(id)sender {
	NSLog(@"Hit compose Button!");
	
	ComposeViewController *compose = [[ComposeViewController alloc] initWithNibName:@"ComposeView" bundle:nil];
	[messagesNavigationController pushViewController:compose animated:YES];
	
	// [messagesNavigationController presentModalViewController:compose animated:YES];
	
}


#pragma mark WIMFramework Stuff


- (void)appendLog:(NSString *)aMessage
{
	NSString *log = [[[NSMutableString alloc] initWithString:aMessage] autorelease];
	
	
	NSMutableString* mutableString = [[sessionLog text] mutableCopy];
	[mutableString appendString:log];
	[sessionLog setText:mutableString];
	[mutableString release];
	
	NSRange range;
	range = NSMakeRange ([[sessionLog text] length], 0);
	[sessionLog scrollRangeToVisible: range];
}

- (void)onWimSessionConnectionStateChange:(NSNotification *)notification {
	
	WimSession *session = [notification object];
	ConnectionState state = [session connectionState];
    
	[self willChangeValueForKey:@"connected"];
	[self willChangeValueForKey:@"online"];
	
	[self appendLog:[NSString stringWithFormat:@"%@:%d\n", [notification name], state]];
	
	switch (state) {
		case ConnectionState_Offline:
			_connected = NO;
			break;
		case ConnectionState_Authenticating:
			_connected = NO;
			break;
		case ConnectionState_Connecting:
			_connected = NO;
			break;
		case ConnectionState_Reconnecting:
			_connected = NO;
			break;
		case ConnectionState_Connected:
			_connected = YES;
			break;
		default:
			break;
	}
	
	[self didChangeValueForKey:@"online"];
	[self didChangeValueForKey:@"connected"];
	
}

- (void)onWimSessionEnded:(NSNotification *)notification {
	// This function is called when we receive an "endSession" event.
	// including being remotely signed out via "AOL System Message"
}


-(void)onIMSentEvent:(NSNotification *)notification
{
	[message setText:@""];
}

-(void)onWatchNotification:(NSNotification*)notification
{
	[self appendLog:[NSString stringWithFormat:@"onWatchNotification %@", [notification name]]];
}

- (IBAction)onSignOff:(id)sender
{
	[wimSession signOff];
}

- (IBAction)onSignOn:(id)sender
{
	// register a delegate to handle UI for secondary challenges (wrong password, captcha, alternate security question)
	[wimSession setDelegate:self];
	
	// set your application's developer key
	[wimSession setDevID:[aimDeveloperKey text]];
	
	// set the username and password on the wimSession
	[wimSession setUserName:[username text]];
	[wimSession setPassword:[password text]];
	
	/*
	// Not yet
	
	// only used for testing of the captcha secondary challenge
	[wimSession setForceCaptcha:[forceCaptcha state]==NSOnState];
	
	 */
	 
	// update preferences
	[[NSUserDefaults standardUserDefaults] setObject:[username text]
											  forKey:kScreenNamePref];
	
	[[NSUserDefaults standardUserDefaults] setObject:[password text]
											  forKey:kPasswordPref];
	
	[[NSUserDefaults standardUserDefaults] setObject:[aimDeveloperKey text]
											  forKey:kDevIdPref];
	
	
	// start an online session
	[wimSession connect];
}


/// This is for my custom sending window

- (void)onSendWithMessage:(NSString *)m recipient:(NSString *)r {
	NSLog(@"message sending %@:%@", m, r);
	
	NSString *log = [NSString stringWithFormat:@"%@->%@: %@\n", [wimSession aimId], r, m];
	[self appendLog:log];
	
	[wimSession sendInstantMessage:m toAimId:r];
	
}




- (IBAction)onSend:(id)sender
{
	NSLog(@"message sending %@:%@", [to text], [message text]);
	
	NSString *log = [NSString stringWithFormat:@"%@->%@: %@\n", [wimSession aimId], [to text], [message text]];
	[self appendLog:log];
	
	[wimSession sendInstantMessage:[message text] toAimId:[to text]];
}

- (IBAction)onPresence:(id)sender
{
	NSLog(@"request presence %@", [to text]);
	[wimSession requestPresenceForAimId:[to text]];
}

/*
 
- (IBAction)closeCustomSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}
*/
 
 
- (IBAction)clearHistory:(id)sender
{
	[sessionLog setText:@""];
	//[sessionLog setNeedsDisplay:YES];
}

- (void)setAwayMessage:(NSString *)aAwayMessage
{
	aAwayMessage = [aAwayMessage copy];
	[awayMessage autorelease];
	awayMessage = aAwayMessage;
	
	[wimSession setState:_status withMessage:aAwayMessage];
}

- (NSString *)awayMessage
{
	return awayMessage;
}

- (void)setStatusMessage:(NSString *)aMessage
{
	aMessage = [aMessage copy];
	[statusMessage autorelease];
	statusMessage = aMessage;
	
	[wimSession setStatus:aMessage];
}

- (NSString *)statusMessage
{
	return statusMessage;
}

- (int)status
{
	return _status;
}

- (void)setStatus:(int)aStatus
{
	_status = aStatus;
	[wimSession setState:_status withMessage:awayMessage];
}

- (void)setProfileMessage:(NSAttributedString *)aMessage
{
	aMessage = [aMessage copy];
	[profileMessage autorelease];
	profileMessage = aMessage;
	
	[wimSession setProfile:[profileMessage string]];
}

- (NSAttributedString *)profileMessage
{
	return profileMessage;
}

- (BOOL)connected
{
	return _connected;
}

- (BOOL)online
{
	return _connected;
}

#pragma mark WimSession Delegate callbacks to handle Errors

// Called when account specific logins are blocked
- (void) wimSessionRateLimited:(WimSession *)aWimSession
{
	[self appendLog:@"***wimSessionRateLimited***\n"];
}

// Server error handler - a server on the backend is not responding properly
- (void) wimSessionServerError:(WimSession *)aWimSession
{
	[self appendLog:@"***wimSessionServerError***\n"];
}


#pragma mark WimSession Delegate callbacks to handle Host events
- (void) wimSession:(WimSession *)aWimSession receivedBuddyList:(NSDictionary *)aBuddyList
{
	// WIM Events will contain a NSDictionary containing the data returned from the WIMServer
	// you can valueForKeyPath to access these structures
	
	NSString *log = [NSString stringWithFormat:@"buddyListArrived:\n"];
	[self appendLog:log];
	
	
	
	if (latestBuddyList){
		[latestBuddyList release];
	} else {
		latestBuddyList = [NSMutableDictionary new];
	}
	
	if (tableBuddyList) {
		[tableBuddyList release];
	} else {
		tableBuddyList = [NSMutableArray new];
	}

	
	latestBuddyList = [aBuddyList copy];	// Save it as the state.
	//tableBuddyList = 
	
	// We don't want to fire presence events when we get a buddy list
	NSArray *groupsArray = [aBuddyList valueForKey:@"groups"];
	NSEnumerator* buddyListGroups = [groupsArray objectEnumerator];
	NSArray* buddyGroups;
	
	while ((buddyGroups = [buddyListGroups nextObject])) 
	{
		NSEnumerator *buddies = [[buddyGroups valueForKey:@"buddies"] objectEnumerator];
		NSMutableDictionary *buddy;
		NSString *log = [NSString stringWithFormat:@"Group: %@\n", [buddyGroups valueForKey:@"name"]];
		[self appendLog:log];
		while (buddy = [buddies nextObject])
		{
			[tableBuddyList addObject:[NSString stringWithString:[buddy objectForKey:@"displayId"]]];
			
			log = [NSString stringWithFormat:@"buddyList: %@ (%@)\n", [buddy objectForKey:@"displayId"], [buddy objectForKey:@"state"]];
			[self appendLog:log];
		}
	}
}

- (void) wimSession:(WimSession *)aWimSession receivedPresenceEvent:(NSDictionary *)buddy
{
	// WIM Events will contain a NSDictionary containing the data returned from the WIMServer
	// you can valueForKeyPath to access these structures
	NSString *log = [NSString stringWithFormat:@"presenceEvent: %@ (%@)\n", [buddy displayName], [buddy state]];
	[self appendLog:log];
	
}
- (void) wimSession:(WimSession *)aWimSession receivedMyInfoEvent:(NSDictionary *)aMyInfoEvent
{
}

- (void) wimSession:(WimSession *)aWimSession receivedTypingEvent:(NSDictionary *)aTypingEvent
{
}

- (void) wimSession:(WimSession *)aWimSession receivedIMEvent:(NSDictionary *)aIMEvent
{
	// WIM Events will contain a NSDictionary containing the data returned from the WIMServer
	// you can valueForKeyPath to access these structures
	
	
	NSLog(@"AIM EVENT: %@", aIMEvent);
	// Add the message to all messages
	[allMessages addObject:aIMEvent];
	NSLog(@"All msgs: %@", allMessages);
	
	// send specific event to context	
	NSString *fromAimId = [aIMEvent valueForKeyPath:@"eventData.source.aimId"];
	NSString *messageText = [aIMEvent valueForKeyPath:@"eventData.message"];
	
	NSString *log = [NSString stringWithFormat:@"%@->%@: %@\n", fromAimId, [aWimSession aimId], messageText];
	[self appendLog:log];
	[message setText:@""];
}
- (void) wimSession:(WimSession *)aWimSession receivedDataIMEvent:(NSDictionary *)aDataIMEvent
{
}
- (void) wimSession:(WimSession *)aWimSession receivedSessionEndedEvent:(NSDictionary *)aSessionEndedEvent
{
}
- (void) wimSession:(WimSession *)aWimSession receivedOfflineIMEvent:(NSDictionary *)aOfflineIMEvent
{
}
- (void) wimSession:(WimSession *)aWimSession receivedHostBuddyInfoEvent:(NSDictionary *)aHostBuddyInfoEvent
{
}


#pragma mark WimSession Delegate callbacks to handle special authentication events

// These are secondary challenges sometimes required by the login server.  In the event of 
// a secondary challenge - the application is required to present UI in order to collect 
// answers to login challenges.  Currently three challenges are supported here
// SecurID (RSA tokens - typically used by AOL employees)
// Password -- in the event that the password entered is wrong or has changed
// Captcha -- an image/text challenge - typically used to verify the user is a person and not an automated script

- (void) wimSessionRequiresCaptcha:(WimSession *)aWimSession url:(NSURL *)url
{
	NSLog(@"CAPTCHA is full of fail!");
	
	/*
	
	// called when WIM authentication needs user needs to validate himself with a captcha image
	NSImage *image = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
	[captchaImage setImage:image];
	[captcha setStringValue:@""];
	
	[wimSession setForceCaptcha:NO];
	
	[NSApp beginSheet:captchaPanel
	   modalForWindow:[self window]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
	
	int code = [NSApp runModalForWindow:captchaPanel];
	[forceCaptcha setState:NSOffState];
	
	NSString *answer = nil;
	
	if (code > 0)
	{
		answer = [captcha stringValue];
	}
	
	[NSApp endSheet:captchaPanel];
	
	[captchaPanel orderOut:self];
	
	if (answer)
	{
		[aWimSession answerChallenge:answer];
	}
	else
	{
		[aWimSession signOff];
	}
	
	*/ 
	
	[captcha setText:@""];
}


- (void) wimSessionRequiresPassword:(WimSession *)aWimSession
{
	NSLog(@"Wim Session Requires Password. (need to implement");
	/*

	
	
	// called when WIM authentication needs a different password
	[challengePassword setStringValue:@""];
	
	[NSApp beginSheet:passwordPanel
	   modalForWindow:[self window]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
	
	int code = [NSApp runModalForWindow:passwordPanel];
	
	[NSApp endSheet:passwordPanel];
	
	[passwordPanel orderOut:self];
	
	if (code > 0)
	{
		[aWimSession answerChallenge:[challengePassword stringValue]];
	}
	else
	{
		[aWimSession signOff];
	}
	
	[challengePassword setStringValue:@""];
	 
	*/
}

- (void) wimSessionRequiresChallenge:(WimSession *)aWimSession
{
	NSLog(@"Requires Challenge (need to implement)");

	/*
	
	// called when WIM authentication needs an answer to a secondary challenge (SecureID)
	[securId setStringValue:@""];
	
	[NSApp beginSheet:securIdPanel
	   modalForWindow:[self window]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
	
	int code = [NSApp runModalForWindow:securIdPanel];
	
	NSString *answer = nil;
	
	if (code > 0)
	{
		answer = [securId stringValue];
	}
	
	[NSApp endSheet:securIdPanel];
	
	[securIdPanel orderOut:self];
	
	if (answer)
	{
		[aWimSession answerChallenge:answer];
	}
	else
	{
		[aWimSession signOff];
	}
	
	[securId setStringValue:@""];
	 
	 */
}


@end

