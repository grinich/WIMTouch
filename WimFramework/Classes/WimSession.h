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


// WIMSession provides an abstraction for the authentication and state housekeeping required for
// a Web AIM Session.

// Fetched Events from the Web AIM Server are parsed, and dispatched via NSNotification
// Event Notification constants are defined in WimEvents.h
// 
// http://dev.aol.com/aim/web/serverapi_reference

#import "WimPlatform.h"
#import "WimEvents.h"
#import "NSDictionary+Buddy.h"

@class WimRequest;
@class ClientLogin;
//@protocol WimSessionSecondaryChallengeDelegate;
//@protocol WimSessionEventDelegate;


typedef enum 
{
  OnlineState_online = 1,//	Online State
  OnlineState_invisible,//	Invisible - Only valid in myInfo objects
  OnlineState_notFound,//	For email lookups the address was not found
  OnlineState_idle,//	Idle State
  OnlineState_away,//	Away State
  OnlineState_mobile,//	Mobile State
  OnlineState_offline,//	Offline State
} OnlineState;

typedef enum 
{
  ConnectionState_Offline,
  ConnectionState_Authenticating,
  ConnectionState_Connecting,
  ConnectionState_Reconnecting,
  ConnectionState_Connected
} ConnectionState;

// WimSession is the client interface for the AIM WIM API, WIM is a Web API, which
// in this case uses JSON as a response format.   Authentication is handled internally
// by WimSession.   AIM Fetched Events (incoming IM, buddy list arrived, etc) 
// are broadcast as NSNotifications to registered listeners - use the constants defined in WimConstants.h


@interface WimSession : NSCoder<NSCoding> 
{
@protected
  id _delegate;
  id _eventDelegate;
  NSString *_userName;
  BOOL _forceCaptcha;
  NSMutableDictionary *_myInfo;
  NSMutableDictionary *_buddyList;
  NSString *_password;
  NSString *_sessionId;
  NSString *_authToken;
  NSString *_fetchUrl;
  NSString *_sessionKey;
  
  ConnectionState connectionState;
  BOOL _pendingEndSession;
  NSDate *_tokenExpiration;
  ClientLogin *_clientLogin;
  int _sessionAttempt;
  WimRequest *_wimFetchRequest;
  NSString *_devID;
  NSString *_clientVersion;
  NSString *_clientName;
  NSUInteger _passwordHash;
  int _WimRequestId;
  NSString *_statusMessage;
  NSString *_awayMessage;
  NSTimeInterval _clockSkew;
  NSSet *_capabilityUUIDs;
  
  id _clientOrnament; // poor app's substitute for subclassing WimSession
}

+ (WimSession*)defaultSession;

// associated delegate for Secondary Challenges
- (void)setDelegate:(id)aDelegate;
- (id)delegate;

// AIM Clients are required to use a application/developmenent ID - request yours at developer.aim.com
- (NSString *)devID;
- (void)setDevID:(NSString *)aDevID;

// AIM Clients are required to specify a client name
- (NSString *)clientName;
- (void)setClientName:(NSString *)aClientName;

// AIM Clients are required to specify a client version
- (NSString *)clientVersion;
- (void)setClientVersion:(NSString *)aClientVersion;

// AIM Clients which support dataIMs must specify which capabilities to assert
- (NSSet*)capabilityUUIDs; // NSSet of NSString
- (void)setCapabilityUUIDs:(NSSet *)aCapabilitySet;

- (BOOL)offline;

// Connect attempts to authenticate with the backend with the set username and password
// and then starts dispatching events from the WIM Backend
- (void)connect;


// Disconnect from the WIM backend
- (void)signOff;


- (void)resetSession;

// answerChallenge: is called by WimSessionSecondaryChallenge Delegates provide security answers, and proceed with authentication
- (void)answerChallenge:(NSString *)aAnswer;

// Add/Remove Buddies
- (void)addBuddy:(NSString *)aimId withFriendlyName:(NSString *)friendlyName toGroup:(NSString *)groupName;
- (void)removeBuddy:(NSString *)aimId fromGroup:(NSString *)groupName;
- (void)moveBuddy:(NSString *)aimId fromGroup:(NSString *)oldGroup toGroup:(NSString *)newGroup;

- (void)setFriendlyName:(NSString*)friendlyName toAimId:(NSString*)aimId;


- (void)moveGroup:(NSString *)groupName beforeGroup:(NSString *)beforeGroup;
- (void)removeGroup:(NSString *)groupName;

// Send a instant message to aAimId
- (void)sendInstantMessage:(NSString*)message toAimId:(NSString*)aimId;
- (void)sendInstantMessage:(NSString*)message toAimId:(NSString*)aimId isAutoResponse:(BOOL)isAutoResponse sendOfflineIfNeeded:(BOOL)sendOfflineIfNeeded;
- (void)requestPresenceForAimId:(NSString*)aAimId;

// Send a response to another user's proposal that we exchange dataIMs
- (void)acceptProposal:(NSDictionary*)invitation; // isAutoResponse:(BOOL)isAutoResponse;
- (void)denyProposal:(NSDictionary*)invitation;   // isAutoResponse:(BOOL)isAutoResponse; // a.k.a. reject

// Result returned via Notification kWimSessionHostBuddyInfoEvent, userInfo = {kWimSessionHostBuddyInfoAimId, kWimSessionHostBuddyInfoHtml}
- (void)requestBuddyInfoForAimId:(NSString*)aimId;
- (void)setState:(OnlineState)aState withMessage:(NSString *)aMessage;
- (void)setStatus:(NSString *)aMessage;
- (void)setProfile:(NSString *)aProfile;
- (void)setLargeBuddyIcon:(NSData*)iconData;

- (void)setUserName:(NSString*)username;
- (NSString *)userName;

- (void)setPassword:(NSString*)password;
- (NSString *)password;

// for testing of authentication piece only
- (void)setForceCaptcha:(BOOL)aForceCaptcha;


// returns the current presence information for this user
- (NSDictionary *)myInfo;

// returns the current identity of the user's aimID, which usually is the same as username
- (NSString *)aimId;

// Returns the most recent copy of the complete buddy list
- (NSDictionary *)buddyList;

// enumerate the buddylist - return the groups that contain this buddy id
// note a buddy can be in more than one group
- (NSArray *)groupsForBuddy:(NSDictionary *)buddy;

// return the array of host based groups
- (NSArray *)groups;

- (NSString*) sha256:(NSString*)queryString withPath:(NSString*)path;

- (void) buddyListArrived;

@property (nonatomic, retain) NSString *statusMessage;
@property (nonatomic, retain) NSString *awayMessage;
@property (nonatomic, retain) id clientOrnament;
@property (readonly, nonatomic, getter=offline) BOOL offline;
@property (readonly, nonatomic, getter=online) BOOL online;
@property (readonly, nonatomic, getter=connectionState) ConnectionState connectionState;
@property (readonly, nonatomic, getter=connected) BOOL connected;
@property (readonly, nonatomic, getter=reconnecting) BOOL reconnecting;

@end


@protocol WimSessionDelegate <NSObject>

// required to support secondary password
// challenges, such as Wrong Password, SecurID, or Captcha
// the delegate should implement a UI to prompt for requested information, and provide the answer
// to [WimSession answerChallenge:]
- (void) wimSessionRequiresCaptcha:(WimSession *)aWimSession url:(NSURL *)captchaURL;
- (void) wimSessionRequiresPassword:(WimSession *)aWimSession;
- (void) wimSessionRequiresChallenge:(WimSession *)aWimSession;

// Called when account specific logins are blocked
- (void) wimSessionRateLimited:(WimSession *)aWimSession;

// Server error handler - a server on the backend is not responding properly
- (void) wimSessionServerError:(WimSession *)aWimSession;

// WimSession Delegate objects receives notifications as they are received from the AIM host
- (void) wimSession:(WimSession *)aWimSession receivedBuddyList:(NSDictionary *)aBuddyList;
- (void) wimSession:(WimSession *)aWimSession receivedPresenceEvent:(NSDictionary *)aPresenceEvent;
- (void) wimSession:(WimSession *)aWimSession receivedMyInfoEvent:(NSDictionary *)aMyInfoEvent;
- (void) wimSession:(WimSession *)aWimSession receivedTypingEvent:(NSDictionary *)aTypingEvent;
- (void) wimSession:(WimSession *)aWimSession receivedIMEvent:(NSDictionary *)aIMEvent;
- (void) wimSession:(WimSession *)aWimSession receivedDataIMEvent:(NSDictionary *)aDataIMEvent;
- (void) wimSession:(WimSession *)aWimSession receivedSessionEndedEvent:(NSDictionary *)aSessionEndedEvent;
- (void) wimSession:(WimSession *)aWimSession receivedOfflineIMEvent:(NSDictionary *)aOfflineIMEvent;
- (void) wimSession:(WimSession *)aWimSession receivedHostBuddyInfoEvent:(NSDictionary *)aHostBuddyInfoEvent;
@end

@interface NSString (WimURLEncoding) 
- (NSString *)stringByAddingPercentEscapes;
- (NSString *)stringByReplacingPercentEscapes; 
@end 

