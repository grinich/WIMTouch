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


#import "WimSession.h"
#import "WimRequest.h"
#import "ClientLogin.h"
#import "ClientLogin+Private.h"
#import "NSDataAdditions.h"
#import "WimConstants.h"
#import "JSON.h"
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
#import <CommonCrypto/CommonHMAC.h>
#else
#import "CommonHMAC.h"
#endif

#import "MLog.h"


//#define kUrlFetchTimeout = @"14000"; //14 seconds
//#define kUrlFetchTimeout = @"28000"; //28 seconds
//#define kUrlFetchTimeout = @"480000"; //8 minutes
#define kUrlFetchTimeout 180000 // 3 minutes
const int kHttpFetchTimeout = kUrlFetchTimeout / 1000 + 5;
const int kSessionTimeout = 480; // 8 minutes

WimSession* gDefaultSession = nil;

@interface WimSession (PRIVATEAPI)
- (void)setConnectionState:(ConnectionState)newConnectionState;
- (void)connectionAuthenticate;
- (void)requestTokenForName:(NSString*)screenName withPassword:(NSString*)password;
- (void)startSession;
- (void)endSession;
- (void)onAimPresenceResponse:(NSNotification *)notification;
- (void)setBuddyList:(NSDictionary *)buddyList;
- (void)fetchEvents;
- (BOOL)validateBuddyList;
- (void)onWimEventFetchEvents:(WimRequest *)wimRequest withError:(NSError *)error;
- (void)replyToProposal:(NSDictionary*)invitation withResponse:(NSString*)response; // isAutoResponse:(BOOL)isAutoResponse
@end

NSDictionary *WimSession_OnlineStateInts;
NSDictionary *WimSession_OnlineStateStrings;



@implementation WimSession

@synthesize statusMessage = _statusMessage;
@synthesize awayMessage = _awayMessage;
@synthesize clientOrnament = _clientOrnament;

- (int)nextRequestId
{
  return _WimRequestId++;
}

+ (WimSession*)defaultSession
{
  if (gDefaultSession == nil)
  {
    MLog(@"Initializing a new global WimSession");
    gDefaultSession = [[WimSession alloc] init];
  }
  return gDefaultSession;
}


extern void IMLog(NSString *,...);

+ (void)initialize
{
  WimSession_OnlineStateInts = [[NSDictionary dictionaryWithObjectsAndKeys:
    @"1"  , @"online", 
    @"2",  @"invisible",
    @"3",  @"notFound",
    @"4",  @"idle", 
    @"5"  , @"away", 
    @"6",  @"mobile",
    @"7",  @"offline",
    nil ] retain];

  WimSession_OnlineStateStrings = [[NSDictionary dictionaryWithObjectsAndKeys:
    @"online",  @"1",
    @"invisible", @"2",
    @"notFound", @"3",
    @"idle", @"4", 
    @"away", @"5", 
    @"mobile", @"6",  
    @"offline", @"7", 
    nil ] retain];
}

- (id)init
{
  if (self = [super init])
  {
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
  self = [super init];
  _userName = [[coder decodeObjectForKey:@"userName"] retain];
  _sessionKey = [[coder decodeObjectForKey:@"sessionKey"] retain];
  _sessionId = [[coder decodeObjectForKey:@"sessionId"] retain];
  _authToken = [[coder decodeObjectForKey:@"authToken"] retain];
  _tokenExpiration = [[coder decodeObjectForKey:@"tokenExpiration"] retain];
	_buddyList = [[coder decodeObjectForKey:@"buddyList"] retain];
  _passwordHash = [[coder decodeObjectForKey:@"passwordHash"] intValue];
  _fetchUrl = [[coder decodeObjectForKey:@"reconnectUrl"] retain];
  _WimRequestId = [[coder decodeObjectForKey:@"wimRequestId"] intValue];
  _myInfo = [[coder decodeObjectForKey:@"myInfo"] retain];
  _statusMessage = [[coder decodeObjectForKey:@"lastStatusMessage"] retain];
  _awayMessage = [[coder decodeObjectForKey:@"lastAwayMessage"] retain];
  _clockSkew = [[coder decodeObjectForKey:@"clockSkew"] doubleValue];

  if ([self validateBuddyList] == NO)
  {
    [_buddyList release];
    _buddyList = nil;
    
    [_sessionKey release];
    _sessionKey = nil;
    
    [_fetchUrl release];
    _fetchUrl = nil;
  }

  // this seems wrong - perhaps defaultSession should be a property allowing the caller to specify which object is the defaultSession?
  if (gDefaultSession != self)
  {
    //[self retain];
    [gDefaultSession autorelease];
    MLog(@"WimSession - old gDefaultSession: %d", [gDefaultSession retainCount]);
    MLog(@"WimSession - new gDefaultSession: %d", [self retainCount]);
    MLog(@"WimSession - replacing global with new WimSession object");
    gDefaultSession = self;
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_userName forKey:@"userName"];
  [coder encodeObject:_sessionKey forKey:@"sessionKey"];
  [coder encodeObject:_sessionId forKey:@"sessionId"];
  [coder encodeObject:_authToken forKey:@"authToken"];
  [coder encodeObject:_tokenExpiration forKey:@"tokenExpiration"];
	[coder encodeObject:_buddyList forKey:@"buddyList"];
  [coder encodeObject:[NSNumber numberWithInt:_passwordHash] forKey:@"passwordHash"];
  [coder encodeObject:_fetchUrl forKey:@"reconnectUrl"];
  [coder encodeObject:[NSNumber numberWithInt:_WimRequestId] forKey:@"wimRequestId"];
  [coder encodeObject:_myInfo forKey:@"myInfo"];
  [coder encodeObject:_statusMessage forKey:@"lastStatusMessage"];
  [coder encodeObject:_awayMessage forKey:@"lastAwayMessage"];
  [coder encodeObject:[NSNumber numberWithDouble:_clockSkew] forKey:@"clockSkew"];
}

- (void)dealloc 
{
  MLog(@"WimSession deallocing...");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_wimFetchRequest setDelegate:nil];
  [_fetchUrl release];
  [_userName release];
  [_password release];
  [_sessionId release];
  [_authToken release];
  [_tokenExpiration release];
  [_clientLogin release];
  [_devID release];
  [_clientVersion release];
  [_clientName release];
  [_capabilityUUIDs release];
  [_clientOrnament release];
  
  if (self == gDefaultSession)
    gDefaultSession = nil;
  
  [super dealloc];
}


#pragma mark WimSession core methods

// AIM Clients are required to use a application/developmenent ID - request yours at developer.aim.com
- (NSString *)devID
{
  return _devID;
}

- (void)setDevID:(NSString *)aDevID
{
  aDevID = [aDevID copy];
  [_devID release];
  _devID = aDevID;
}


- (NSString *)clientName
{
  return _clientName;
}

- (void)setClientName:(NSString *)aClientName
{
  aClientName = [aClientName copy];
  [_clientName release];
  _clientName = aClientName;
}

- (NSString *)clientVersion
{
  return _clientVersion;
}

- (void)setClientVersion:(NSString *)aClientVersion
{
  aClientVersion = [aClientVersion copy];
  [_clientVersion release];
  _clientVersion = aClientVersion;
}

- (NSSet*)capabilityUUIDs
{
  return _capabilityUUIDs;
}

- (void)setCapabilityUUIDs:(NSSet *)aCapabilitySet
{
  // ++++ validate input in debug builds
  [aCapabilitySet retain];
  [_capabilityUUIDs release];
  _capabilityUUIDs = aCapabilitySet;
}

- (BOOL)online
{
  // if internal state is reconnecting or connected
  return ![self offline];
}

- (BOOL)offline
{
  // if internal state is logged out, authenticating or connecting
  switch (connectionState) {
    case ConnectionState_Offline:
      return YES;
    case ConnectionState_Authenticating:
      return YES;
    case ConnectionState_Connecting:
      return YES;
    case ConnectionState_Reconnecting:
      return NO;
    case ConnectionState_Connected:
      return NO;
    default:
      MLog(@"Connection reached unknown state");
      return NO;
  }
}

- (ConnectionState)connectionState
{
  return connectionState;
}

- (BOOL)connected
{
  return self.connectionState > ConnectionState_Reconnecting;
}

- (BOOL)reconnecting
{
  return self.connectionState == ConnectionState_Reconnecting;
}

- (void)connect
{
  if (self.connectionState == ConnectionState_Offline)
    [self setConnectionState:ConnectionState_Authenticating];
}

- (void)signOff
{
  // reset the connection such that we'll restart the ConnectionState state machine
  [self resetSession];
  [self endSession];
}



- (void)setConnectionState:(ConnectionState)aConnectionState
{
  ConnectionState previousState = connectionState;
  connectionState = aConnectionState;
  
  switch (connectionState) {
    case ConnectionState_Offline:
      _sessionAttempt = 0;
      [[NSNotificationCenter defaultCenter] postNotificationName:kWimClientConnectionStateChange object:self];
      break;
    case ConnectionState_Authenticating:
      // Signing on...
      _sessionAttempt = 0;
      [self connectionAuthenticate];
      break;
    case ConnectionState_Connecting:
    case ConnectionState_Reconnecting:
      if (_fetchUrl==nil)
      {
        connectionState = ConnectionState_Connecting;
        [[NSNotificationCenter defaultCenter] postNotificationName:kWimClientConnectionStateChange object:self];
        // Connecting...
        _sessionAttempt = 0;
        [self startSession];
      }
      else
      {
        // Reconnecting...
        connectionState = ConnectionState_Reconnecting;
        [[NSNotificationCenter defaultCenter] postNotificationName:kWimClientConnectionStateChange object:self];
        [self fetchEvents];
      }
      break;
    case ConnectionState_Connected:
      if (previousState != ConnectionState_Connected)
        [[NSNotificationCenter defaultCenter] postNotificationName:kWimClientConnectionStateChange object:self];
      break;
    default:
      MLog(@"continueConnection reached unknown state");
      break;
  }
  
}

- (void)connectionAuthenticate
{
  NSString *user = [[self userName] lowercaseString];
  NSString *aimId = [[[self myInfo] aimId] lowercaseString];
  
  BOOL validAimId = NO;
  BOOL validPassword = NO;
  BOOL validToken = NO;

  if ([user isEqualToString:aimId] == YES)
  {
    validAimId = YES;
  }
  
  if ([[self password] hash] == _passwordHash)
  {
    validPassword = YES ;
  }
  
  if (_tokenExpiration && [[NSDate date] earlierDate:_tokenExpiration] && _authToken && _sessionKey)
  {
    validToken = YES;
  }
  
  if (validAimId && validPassword && validToken)
  {
    [self setConnectionState:ConnectionState_Connecting];
  }
  else
  {
    [_clientLogin release];
    _clientLogin = [[ClientLogin alloc] init];
    [_clientLogin setDelegate:self];
    

    if ([_userName length])
    {

      if ([_password length])
      {
        [[NSNotificationCenter defaultCenter] postNotificationName:kWimClientConnectionStateChange object:self];
        [self requestTokenForName:_userName withPassword:_password];
      }
      else
      {
        if ([_delegate respondsToSelector:@selector(wimSessionRequiresPassword:)])
          [_delegate performSelector:@selector(wimSessionRequiresPassword:) withObject:self];
      }
    }
    else
    {
      [self setConnectionState:ConnectionState_Offline];
    }
  }
}

- (void)answerChallenge:(NSString *)challengeAnswer
{
  
  if ( [_userName isEqualToString:[_clientLogin screenName]] == NO || [_password length] == 0)
  {
    [_password autorelease];
    _password = [challengeAnswer copy];
    [self setConnectionState:ConnectionState_Authenticating];
  }
  else
  {
    [_clientLogin answerChallenge:challengeAnswer];
  }
} 

- (void)requestPresenceForAimId:(NSString*)aimId 
{
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventPresenceResponse:withError:)];
  
  NSString* urlString = [NSString stringWithFormat:kUrlPresenceRequest, kAPIBaseURL, [[self devID] urlencode], [aimId urlencode]];
  NSURL *url = [NSURL URLWithString:urlString];

  [wimRequest setUserData:self];
  [wimRequest requestURL:url];
}

- (void)requestBuddyInfoForAimId:(NSString*)aimId
{
  NSString *kUrlGetBuddyInfo = @"%@aim/getHostBuddyInfo?f=html&t=%@&aimsid=%@"; // requires: kAPIBaseURL, aimId, aimSid
  NSString* urlString = [NSString stringWithFormat: kUrlGetBuddyInfo, kAPIBaseURL, [aimId urlencode], _sessionId];
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventGetHostBuddyInfoResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  
  NSArray *userData = [NSArray arrayWithObjects:aimId, nil];
  [wimRequest setUserData:userData];
  [wimRequest requestURL:url];
}


- (void)addBuddy:(NSString *)aimId toGroup:(NSString *)groupName thenInvoke:(NSInvocation *)aInvocation
{
  // looks like we need to do some additional encoding to handle SMS based aimId's
  //NSString *encodedAimId =  [aimId urlencode];
  
  NSString *kUrlAddBuddy = @"%@buddylist/addBuddy?f=json&k=%@&a=%@&aimsid=%@&r=%d&buddy=%@&group=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, newBuddy, groupName
  
  NSString* urlString = [NSString stringWithFormat: kUrlAddBuddy, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                         [aimId urlencode], [groupName urlencode]];
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventAddBuddyResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  if (aInvocation)
  {
    NSDictionary *userDictionary = [NSDictionary dictionaryWithObject:aInvocation forKey:@"delayedInvocation"];
    [wimRequest setUserData:userDictionary];
  }
  [wimRequest requestURL:url];
}

// Add/Remove Buddies
- (void)addBuddy:(NSString *)aimId withFriendlyName:(NSString *)friendlyName toGroup:(NSString *)groupName
{
  NSInvocation *anInvocation = nil;

  if (friendlyName)
  {
    SEL selector = @selector(setFriendlyName:toAimId:);
    anInvocation = [NSInvocation invocationWithMethodSignature:[WimSession instanceMethodSignatureForSelector:selector]];
    [anInvocation setSelector:selector];
    [anInvocation retainArguments];
    [anInvocation setTarget:self];
    [anInvocation setArgument:&friendlyName atIndex:2];
    [anInvocation setArgument:&aimId atIndex:3];
  }
  
  [self addBuddy:aimId toGroup:groupName thenInvoke:anInvocation];
}

- (void)removeBuddy:(NSString *)aimId fromGroup:(NSString *)groupName
{
  // looks like we need to do some additional encoding to handle SMS based aimId's
  //NSString *encodedAimId =  [aimId urlencode];
  
  NSString *kUrlRemoveBuddy = @"%@buddylist/removeBuddy?f=json&k=%@&a=%@&aimsid=%@&r=%d&buddy=%@&group=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, newBuddy, groupName
  
  NSString* urlString = [NSString stringWithFormat: kUrlRemoveBuddy, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                         [aimId urlencode], [groupName urlencode]];
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventRemoveBuddyResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  
 
  [wimRequest requestURL:url];
}

- (void)moveBuddy:(NSString *)aimId fromGroup:(NSString *)oldGroup toGroup:(NSString *)newGroup
{
  if (oldGroup && newGroup)
  {
    SEL selector = @selector(removeBuddy:fromGroup:);
    NSInvocation *anInvocation;
    anInvocation = [NSInvocation invocationWithMethodSignature:[WimSession instanceMethodSignatureForSelector:selector]];
    [anInvocation setSelector:selector];
    [anInvocation retainArguments];
    [anInvocation setTarget:self];
    [anInvocation setArgument:&aimId atIndex:2];
    [anInvocation setArgument:&oldGroup atIndex:3];

    [self addBuddy:aimId toGroup:newGroup thenInvoke:anInvocation];
  }
}



- (void)setFriendlyName:(NSString*)friendlyName toAimId:(NSString*)aimId
{
  NSString* urlString = [NSString stringWithFormat: kUrlSetBuddyAttribute, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                         [aimId urlencode], [friendlyName urlencode]];
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventSetBuddyAttributeResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  [wimRequest setUserData:aimId];
  [wimRequest requestURL:url];
  
}

- (void)moveGroup:(NSString *)groupName beforeGroup:(NSString *)beforeGroup
{
  NSString* urlString;
  if (beforeGroup)
  {
    NSString *kUrlMoveGroup = @"%@buddylist/moveGroup?f=json&k=%@&a=%@&aimsid=%@&r=%d&group=%@&beforeGroup=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, groupName, beforeGroup
  
    urlString = [NSString stringWithFormat: kUrlMoveGroup, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                         [groupName urlencode], [beforeGroup urlencode]];
  }
  else
  {
    NSString *kUrlMoveGroup = @"%@buddylist/moveGroup?f=json&k=%@&a=%@&aimsid=%@&r=%d&group=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, groupName, beforeGroup
    urlString = [NSString stringWithFormat: kUrlMoveGroup, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                           [groupName urlencode]];
  }
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventMoveGroupResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  
  [wimRequest requestURL:url];
}

- (void)removeGroup:(NSString *)group
{
  NSString* urlString = [NSString stringWithFormat: kUrlRemoveGroup, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                         [group urlencode]];
  NSURL *url = [NSURL URLWithString:urlString];


  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventRemoveGroupResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  [wimRequest setUserData:group];
  [wimRequest requestURL:url];
}

- (void)sendInstantMessage:(NSString*)message toAimId:(NSString*)aimId
{
  [self sendInstantMessage:message toAimId:aimId isAutoResponse:NO sendOfflineIfNeeded:NO];
}

- (void)sendInstantMessage:(NSString*)message toAimId:(NSString*)aimId isAutoResponse:(BOOL)isAutoResponse sendOfflineIfNeeded:(BOOL)sendOfflineIfNeeded
{
  // looks like we need to do some additional encoding to handle SMS based aimId's
  //NSString *encodedAimId =  [aimId urlencode];

  // looks like we need to do some additional encoding to handle +
  NSString* urlString = [NSString stringWithFormat: kUrlSendIMRequest, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
												 [[NSString stringWithFormat:@"<div>%@</div>", [NSString encodeHTMLEntities:message]] urlencode], [aimId urlencode], (isAutoResponse ? @"1" : @"0"),(sendOfflineIfNeeded ? @"1" : @"0")];
  
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) { MLog(@"sendInstantMessage created invalid URL"); return;}
  
  //http://api.oscar.aol.com/im/sendIM?f=json&k=MYKEY&c=callback&aimsid=AIMSID&msg=Hi&t=ChattingChuck
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventIMSentResponse:withError:)];
  
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                              message, @"message", 
                              aimId, @"aimId", 
                              [NSNumber numberWithBool:isAutoResponse], @"autoresponse", 
                              [NSNumber numberWithBool:sendOfflineIfNeeded], @"sendOffline", nil];
  
  MLog (@"fetching %@", urlString);
  [wimRequest setUserData:dictionary];
  [wimRequest requestURL:url];
}
- (void)acceptProposal:(NSDictionary*)invitation // isAutoResponse:(BOOL)isAutoResponse
{
  [self replyToProposal:invitation withResponse:@"accept"];
}

- (void)denyProposal:(NSDictionary*)invitation // isAutoResponse:(BOOL)isAutoResponse
{
  [self replyToProposal:invitation withResponse:@"deny"];
}

- (void)replyToProposal:(NSDictionary*)invitation withResponse:(NSString*)response // isAutoResponse:(BOOL)isAutoResponse
{
  // NSString* kUrlSendDataIM = @"%@im/sendDataIM?f=json&k=%@&a=%@&aimsid=%@&r=%d&&t=%@&cap=%@&type=%@&data=%@";
  // requires: kAPIBaseURL, key, authtoken, aimSid,requestid,target,capability,type,data
  
  NSMutableString* urlString = [NSMutableString stringWithFormat: kUrlSendDataIM, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId],
                         [invitation valueForKeyPath:@"eventData.source.aimId"], // ++++ need to re-encode target screenname?
                         [invitation valueForKeyPath:@"eventData.dataCapability"],
                         response,
                         @"x"]; // the data argument is required, although I don't think it is useful here
  
  // These are appended because I'm not yet sure that they are always required.
  // if anything is always required, it should be added to kUrlSendDataIM
  [urlString appendFormat:@"&cookie=%@", [invitation valueForKeyPath:@"eventData.cookie"]];
  [urlString appendFormat:@"&sequenceNum=%@", [invitation valueForKeyPath:@"eventData.sequenceNum"]];
  
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) { MLog(@"replyToProposal created invalid URL"); return;}
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventProposalReplySentResponse:withError:)];
  
  // I don't think we need to create a dictionary, then
  // [wimRequest setUserData:dictionary];
  
  MLog (@"fetching %@", urlString);
  [wimRequest requestURL:url];
}


- (void)setState:(OnlineState)onlineState withMessage:(NSString *)message
{
  //http://api.oscar.aol.com/presence/setState?f=json&k=MYKEY&c=callback&aimsid=AIMSID&view=away&away=Gone
  NSString *stateString = [WimSession_OnlineStateStrings valueForKey:[NSString stringWithFormat:@"%d", onlineState]];
  
  NSString *kUrlSetState = @"%@presence/setState?f=json&aimsid=%@&r=%d&view=%@"; // requires kAPIBaseURL, authtoken, requestid, state

  NSMutableString* urlString = [NSMutableString stringWithString:[NSString stringWithFormat: kUrlSetState, kAPIBaseURL, _sessionId, [self nextRequestId], stateString]];

  if (onlineState == OnlineState_away && message)
  {
    [urlString appendFormat:@"&away=%@", [message urlencode]];
  }
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventSetStateResponse:withError:)];

  MLog (@"fetching %@", urlString);
  [wimRequest requestURL:url];
}

- (void)setStatus:(NSString *)message
{  
  NSMutableString *queryString = [[[NSMutableString alloc] init] autorelease];
  [queryString appendValue:@"json" forName:@"f"];
  [queryString appendValue:[NSString stringWithFormat:@"%d", [self nextRequestId]] forName:@"r"];
  [queryString appendValue:_sessionId forName:@"aimsid"];
  if (message)
  {
   // [queryString appendValue:message forName:@"statusMsg"];
   // [queryString appendFormat:@"&statusMsg=%@", [[message stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] urlencode]];
    [queryString appendFormat:@"&statusMsg=%@", [message urlencode]];

  }
  else
  {
    [queryString appendString:@"&statusMsg="];
  }

  
  NSString *urlString = [NSMutableString stringWithFormat:@"%@presence/setStatus?%@", kAPIBaseURL, queryString];
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventSetStatusResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  [wimRequest requestURL:url];
}

- (void)setProfile:(NSString *)message
{
  NSMutableString *queryString = [[[NSMutableString alloc] init] autorelease];
  [queryString appendValue:@"json" forName:@"f"];
  [queryString appendValue:[NSString stringWithFormat:@"%d", [self nextRequestId]] forName:@"r"];
  [queryString appendValue:_sessionId forName:@"aimsid"];
  //[queryString appendFormat:@"&profile=%@", [message urlencode]];
  [queryString appendValue:message forName:@"profile"];

  NSString *urlString = [NSMutableString stringWithFormat:@"%@presence/setProfile?%@", kAPIBaseURL, queryString];
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventSetProfileResponse:withError:)];
  
  MLog (@"fetching %@", urlString);
  [wimRequest requestURL:url];
}



- (void)setLargeBuddyIcon:(NSData*)iconData
{
  // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, expression type
  NSString* urlString = [NSString stringWithFormat: kUrlUploadExpression, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                        @"buddyIcon"];
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventSetLargeBuddyIconResponse:withError:)];
  
  MLog (@"posting %@", urlString);
  [wimRequest requestURL:url withData:iconData];
}

- (void)setExpresssion:(NSString *)expressionId
{
  
  NSString *kUrlSetExpression = @"%@expressions/set?f=json&k=%@&a=%@&aimsid=%@&r=%d&type=%@&id=%@";
  
  // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, expression type, expression id
  
  NSString* urlString = [NSString stringWithFormat: kUrlSetExpression, kAPIBaseURL, [self devID], _authToken, _sessionId, [self nextRequestId], 
                         @"buddyIcon", expressionId];
  
  NSURL *url = [NSURL URLWithString:urlString];
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventSetExpressionResponse:withError:)];
  
  MLog (@"posting %@", urlString);
  [wimRequest requestURL:url];
  
}


#pragma mark ClientLogin Delegate

- (void) clientLoginRequiresChallenge:(ClientLogin *)aClientLogin
{
  // delegate UI handling login challenge - delegate should relogin after providing answer to challenge
  int code = [[aClientLogin statusDetailCode] intValue];
  
  switch (code)
  {

    case 3011: // password challenge
      [_password autorelease];
      _password = @"";
      if ([_delegate respondsToSelector:@selector(wimSessionRequiresPassword:)])
        [_delegate performSelector:@selector(wimSessionRequiresPassword:) withObject:self];
      break;
    case 3012: // securid challenge
    case 3013: // securid seconde challenge

      if ([_delegate respondsToSelector:@selector(wimSessionRequiresChallenge:)])
        [_delegate performSelector:@selector(wimSessionRequiresChallenge:) withObject:self];
      break;
    case 3015: // captcha challenge

      if ([_delegate respondsToSelector:@selector(wimSessionRequiresCaptcha:url:)])
      {
        NSString *captchaURL = [NSString stringWithFormat:@"%@?devId=%@&f=image&context=%@", [aClientLogin challengeURL], [self devID], [aClientLogin challengeContext]];
        NSURL *url = [NSURL URLWithString:captchaURL];
        [_delegate performSelector:@selector(wimSessionRequiresCaptcha:url:) withObject:self withObject:url];
      }
      break;
    default:
      MLog(@"clientLoginRequiresChallenge unsupported secondary challenge");
      break;
  }
}

- (void) clientLoginComplete:(ClientLogin *)aClientLogin
{
  MLog(@"onAimLoginEventTokenGranted");
  
  _passwordHash = [[self password] hash];
 
  [_sessionKey release];
  _sessionKey = [[aClientLogin sessionKey] retain];
  
  [_authToken release];
  _authToken = [[aClientLogin tokenStr] retain];
  
  NSTimeInterval seconds = [[aClientLogin expiresIn] intValue];
  NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
  [_tokenExpiration release];
  _tokenExpiration = [expirationDate retain];
  
  _clockSkew = [aClientLogin clockSkew];
  
  // we are done with the client login
  [_clientLogin release];
  _clientLogin = nil;
  

  [self setConnectionState:ConnectionState_Connecting];
}

- (void) clientLoginFailed:(ClientLogin *)aClientLogin
{
  MLog(@"onAimLoginEventTokenFailure");
  
  // if login is failing - don't use cached credentials
  [_tokenExpiration release];
  _tokenExpiration = nil;
  [_authToken release];
  _authToken = nil;
  [_sessionKey release];
  _sessionKey = nil;

  // we are done with the client login
  [_clientLogin release];
  _clientLogin = nil;
  
  [self setConnectionState:ConnectionState_Offline];
}

- (BOOL)validateBuddyList
{
  NSArray *buddyList = [_buddyList valueForKey:@"groups"];
  NSEnumerator* buddyListGroups = [buddyList objectEnumerator];
  NSArray* buddyGroup;
  
  while ((buddyGroup = [buddyListGroups nextObject])) 
  {
    NSEnumerator *buddies = [[buddyGroup valueForKey:@"buddies"] objectEnumerator];
    NSMutableDictionary *buddy;
    //NSString *groupName = [buddyGroup valueForKey:@"name"];
    while (buddy = [buddies nextObject])
    {
      NSString *aimId = [buddy aimId];

      if (aimId == nil)
      {
        MLog(@"buddy list validation failed from disk %@", buddy);
        return NO;
      }
    }
  }
  
  return YES;
}

- (void)buddyListArrived
{
  MLog(@"buddyListArrived");

  NSArray *buddyList = [_buddyList valueForKey:@"groups"];
  NSEnumerator* buddyListGroups = [buddyList objectEnumerator];
  NSArray* buddyGroup;
  
  while ((buddyGroup = [buddyListGroups nextObject])) 
  {
    NSEnumerator *buddies = [[buddyGroup valueForKey:@"buddies"] objectEnumerator];
    NSMutableDictionary *buddy;
    NSString *groupName = [buddyGroup valueForKey:@"name"];
    while (buddy = [buddies nextObject])
    {
      [buddy setObject:groupName forKey:@"_group"];
    }
  }

  [_delegate wimSession:self receivedBuddyList:_buddyList];
}

- (void)updateBuddyListWithBuddy:(NSDictionary*)newBuddyInfo
{
  MLog(@"updateBuddyListwithBuddy: %@", newBuddyInfo );
  
  NSArray *buddyList = [_buddyList valueForKey:@"groups"];
  
  NSEnumerator* buddyListGroups = [buddyList objectEnumerator];
  NSArray* buddyGroups;
  
  while ((buddyGroups = [buddyListGroups nextObject])) 
  {
    NSEnumerator *buddies = [[buddyGroups valueForKey:@"buddies"] objectEnumerator];
    NSMutableDictionary *buddy;
    while (buddy = [buddies nextObject])
    {
      // fire presence events for existing UI - allowing prexisting UI to update state
      if ( [buddy isEqualToBuddy:newBuddyInfo] ) 
      {
        [buddy updateBuddy:newBuddyInfo];
        [_delegate wimSession:self receivedPresenceEvent:buddy];
      }
    }
  }
}


#pragma mark EventParser

- (void)parseEvents:(NSArray*)aEvents
{
  NSEnumerator* enumerator = [aEvents objectEnumerator];
  NSArray* event;
  
  while ((event = [enumerator nextObject])) 
  {
    // should eventdata be reparsed as Dictionary?
    NSString* type = [event stringValueForKeyPath:@"type"];
    if ([type isEqualToString:@"myInfo"])
    {

      NSMutableDictionary *buddy = [event valueForKey:@"eventData"];
      if (![buddy isKindOfClass:[NSMutableDictionary class]] )
      {
        buddy = [buddy mutableCopy];
      }
      MLog(@"MyInfo: %@", buddy);

      if ([[buddy valueForKey:@"invisible"] intValue] == 0 && ![[_myInfo state] isEqualToString:@"invisible"]) // reset state after invisibility turns off remotely
      {
        [buddy setValue:[_myInfo state] forKey:@"state"];

        if ([buddy awayMsg])
        {
          [_awayMessage release];
          _awayMessage = [[buddy awayMsg] copy]; //awayMsg contains xhtml

        }
        else
        {
          [_statusMessage release];
          _statusMessage = [[NSString decodeHTMLEntities:[buddy statusMsg]] retain];
        }
      }
      
      [_myInfo release];
      _myInfo = [buddy retain];

      [_delegate wimSession:self receivedMyInfoEvent:buddy];
    }
    else if ([type isEqualToString:@"presence"]) 
    {
      NSDictionary *buddy = [event valueForKey:@"eventData"];
      [self updateBuddyListWithBuddy:buddy];  // Update the data to keep it in sync...
    }
    else if ([type isEqualToString:@"buddylist"]) 
    {
      [self setBuddyList:[event valueForKey:@"eventData"]];
    }
    else if ([type isEqualToString:@"typing"]) 
    {
      NSDictionary *buddy = [event valueForKey:@"eventData"];
      [_delegate wimSession:self receivedTypingEvent:buddy];
    }
    else if ([type isEqualToString:@"im"]) 
    {
      MLog(@"received IM %@", [event stringValueForKeyPath:@"eventData.source.aimId"]);
      [_delegate wimSession:self receivedIMEvent:(NSDictionary*)event];
    }
    else if ([type isEqualToString:@"dataIM"]) 
    {
      [_delegate wimSession:self receivedDataIMEvent:(NSDictionary*)event];
    }
    else if ([type isEqualToString:@"sessionEnded"]) 
    {
      _pendingEndSession = YES;
      [_delegate wimSession:self receivedSessionEndedEvent:(NSDictionary*)event];
      [self setConnectionState:ConnectionState_Offline];
    }
    else if ([type isEqualToString:@"offlineIM"]) 
    {
      // send generic handler out first - allowing application to create correct context
      [_delegate wimSession:self receivedOfflineIMEvent:(NSDictionary*)event];
    }
  }
}


// for now we just reset things so we can try to reconnect -- after tearing down the connection
- (void)resetSession
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(watchDog:) object:_wimFetchRequest];
  _pendingEndSession = NO;
  [_fetchUrl release];
  _fetchUrl = nil;
}

#pragma mark Web API Interface
/**
 * Actually performs a startSession query to WIM. It is the target of the SESSION_STARTING event.
 * It packages up all the parameters into a query string and SHA256 signs the resulting string.
 * @param evt
 *  challenge
 */ 

- (void)requestTokenForName:(NSString*)screenName withPassword:(NSString*)password // andChallengeAnswer:(NSString*)answer
{
  MLog(@"Token expired - due to requesting fetch token");
  [_clientLogin requestSessionKey:screenName withPassword:password forceCaptcha:_forceCaptcha];
}

//
//  sha256:withPath:
//
//  This utility method takes the parameters of a WIM call you want to make, and creates the sha256 digest for the query you will send.
//  it takes the kAPIBaseURL and appends the path (like "location/getPd") to it and then adds the query string in order to generate 
//  the sha256 value.
//
//  WARNING:  DO NOT send in the full URL string in the query parameter.  And always make sure you send the parameters in alphabetical order!
//
- (NSString*) sha256:(NSString*)queryString withPath:(NSString*)path
{
  CFStringRef encodedQueryStringRef = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)queryString,
                                                                              NULL, (CFStringRef)@";/?:@&=+$,",
                                                                              kCFStringEncodingUTF8);
  
  NSString *encodedQueryString = [(NSString*)encodedQueryStringRef autorelease];
  
  // Generate OAuth Signature Base
  NSString *temp = [[NSString stringWithFormat:@"%@%@", kAPIBaseURL, path] urlencode];
  NSString *openAuthSignatureBase = [NSString stringWithFormat:@"GET&%@&%@", temp, encodedQueryString];
  
  MLog(@"AIMBaseURL %@   : ", kAPIBaseURL);
  MLog(@"QueryParams %@   : ", queryString);
  MLog(@"encodedQueryString %@:", encodedQueryString); 
  MLog(@"Session Key %@   : ", _sessionKey);
  MLog(@"Signature Base %@ : ", openAuthSignatureBase);
  
  const char* sessionKey = [_sessionKey cStringUsingEncoding:NSASCIIStringEncoding];
  const char* signatureBase = [openAuthSignatureBase cStringUsingEncoding:NSASCIIStringEncoding];
  
  unsigned char macOut[CC_SHA256_DIGEST_LENGTH];
  CCHmac(kCCHmacAlgSHA256, sessionKey, strlen(sessionKey), signatureBase, strlen(signatureBase), macOut);
  NSData *hash = [[[NSData alloc] initWithBytes:macOut length:sizeof(macOut)] autorelease];
  NSString *baseSixtyFourHash = [hash base64Encoding];
  
  // Append the sig_sha256 data
  CFStringRef encodedB64Ref = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)baseSixtyFourHash,
                                                                      NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8);
  return [(NSString*)encodedB64Ref autorelease];  
}

// http://api.oscar.aol.com/aim/startSession
- (void)startSession
{
  NSString *supportedEvents;
  NSMutableString *assertCaps = NULL;
  BOOL haveCapabilities = NO;
  if (_capabilityUUIDs && [_capabilityUUIDs count])
  {
    // ++++ perhaps we could validate _capabilityUUIDs here
    supportedEvents = @"myInfo,presence,buddylist,im,offlineIM,dataIM";
    assertCaps = [NSMutableString stringWithString:@"&assertCaps="];
    NSString* caps =[[_capabilityUUIDs allObjects] componentsJoinedByString:@","];
    [assertCaps appendString:caps];
    haveCapabilities = YES;
  }

  if (!haveCapabilities)
  {
    supportedEvents = @"myInfo,presence,buddylist,im,offlineIM";
    assertCaps = @"";
  }

//NSString *supportedEvents = @"myInfo,presence,buddylist,typing,im,offlineIM";
//NSString *supportedEvents = @"myInfo,presence,buddylist,typing,im,dataIM,offlineIM";
  
  int clientTime = lrint([[NSDate date] timeIntervalSince1970] + _clockSkew);
  
  // Set up params in alphabetical order
  NSMutableString *queryString;
  queryString = [NSMutableString stringWithFormat:@"a=%@%@&clientName=%@&clientVersion=%@&events=%@&f=json&k=%@&sessionTimeout=%d&ts=%d",
                     _authToken, assertCaps, [_clientName urlencode], [_clientVersion urlencode], [supportedEvents urlencode],
                     _devID, kSessionTimeout, clientTime];
  
  NSString *encodedB64 = [self sha256:queryString withPath:@"aim/startSession"];
  
  MLog(@"StartSessionQuery: %@", queryString);
  NSString *urlString = [NSString stringWithFormat:kUrlStartSession, kAPIBaseURL, queryString,encodedB64];
  
  //will trigger onWimEventSessionStarted
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventStartSession:withError:)];
  [wimRequest setUserData:self];
  [wimRequest requestURL:[NSURL URLWithString:urlString]];
}


- (void)fetchEvents
{
  if (_wimFetchRequest)
  {
    MLog(@"[WimSession fetchEvents] already in fetch loop");
    return;
  }

  if (_fetchUrl == nil)
  {
    MLog(@"[WimSession fetchEvents] missing fetchUrl");
    [self resetSession];
    [self setConnectionState:ConnectionState_Authenticating];
    return;
  }
  
  NSURL *url = [NSURL URLWithString:_fetchUrl]; // host will timeout at kUrlFetchTimeout milliseconds (3 minutes currently)
  MLog (@"fetching %@", _fetchUrl);
  
  [_wimFetchRequest release];
  _wimFetchRequest = [[WimRequest wimRequest] retain]; 
  [_wimFetchRequest setTimeout:kHttpFetchTimeout];// NSURLConnection will timeout after 3minutes 10seconds
  [_wimFetchRequest setDelegate:self];
  [_wimFetchRequest setAction:@selector(onWimEventFetchEvents:withError:)];
  [_wimFetchRequest setUserData:self];
  [_wimFetchRequest requestURL:url];
  
  [self performSelector:@selector(checkForConnection:) withObject:_wimFetchRequest afterDelay:3.0];
  
  //watch for http timeout to not fire
  [self performSelector:@selector(watchDog:) withObject:_wimFetchRequest afterDelay:kHttpFetchTimeout+1];
}

- (void)endSession
{
  _pendingEndSession = YES;
  NSString *urlString = [NSString stringWithFormat:kUrlEndSession, kAPIBaseURL, _sessionId]; 
  MLog (@"endSession %@", urlString);
  
  [_wimFetchRequest setDelegate:nil];
  [_wimFetchRequest release];
  _wimFetchRequest = nil;
  
  
  WimRequest *wimRequest = [WimRequest wimRequest];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onWimEventEndSession:withError:)];
  [wimRequest setUserData:self];
  [wimRequest setSynchronous:YES];
  [wimRequest requestURL:[NSURL URLWithString:urlString]];
  
  [self setConnectionState:ConnectionState_Offline];
}

#pragma mark WatchDog Methods

- (void)checkForConnection:(id)fetchRequest
{
  if (_wimFetchRequest == fetchRequest)
    [self setConnectionState:ConnectionState_Connected];
}

- (void)watchDog:(id)fetchRequest
{
  if (_wimFetchRequest == fetchRequest)
  {
    // _wimFetchRequest hasn't completed yet, assume that the connection will never resume
    [_wimFetchRequest cancelRequest];
    NSError *error = [NSError errorWithDomain:@"WimFetchEvent" code:408 userInfo:nil];
    [self onWimEventFetchEvents:_wimFetchRequest withError:error];
  }
}


- (void)checkForAuthenticationError:(NSInteger)statusCode
{
  if (statusCode == 401 || statusCode == 462)
  {
    [self resetSession];
    [self setConnectionState:ConnectionState_Authenticating];
  }
}





#pragma mark Event handlers for Web API response

- (void)onWimEventStartSession:(WimRequest *)wimRequest withError:(NSError *)error
{  
  if (error)
  {
    _sessionAttempt++;

    MLog(@"EventSessionStarted(%d) failed with error: %@", _sessionAttempt, [error description]);

    if (_sessionAttempt < 4)
    {
      [self startSession];
    }
    else
    {
      _sessionAttempt = 0;
      [self setConnectionState:ConnectionState_Offline];
    }

    return;
  }
  
  MLog(@"onWimEventSessionStarted");
  
  NSString *jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  NSDictionary* dictionary = nil;
  
  @try {
    dictionary = [jsonResponse JSONValue];
  }
  @catch (NSException *e) {
    MLog(@"exception %@", e);
  }
  
  int statusCode = [[dictionary valueForKeyPath:@"response.statusCode"] intValue];
  
    switch (statusCode)
    {
      case 200:
      {
        _sessionAttempt = 0;
        
        [_sessionId release];
        _sessionId = [[dictionary stringValueForKeyPath:@"response.data.aimsid"] retain];

        NSString *fetchBaseURL = [dictionary stringValueForKeyPath:@"response.data.fetchBaseURL"];
        
        [_fetchUrl release];
        
        if (fetchBaseURL)
        {
          _fetchUrl = [[NSString stringWithFormat: kUrlFetchRequest, fetchBaseURL, [self nextRequestId] , kUrlFetchTimeout] retain];
        }
        else
        {
          _fetchUrl = nil;
        }
        
        NSMutableDictionary *myInfo = [[[NSMutableDictionary alloc] initWithDictionary:[dictionary valueForKeyPath:@"response.data.myInfo"]] autorelease];
        [_delegate wimSession:self receivedMyInfoEvent:myInfo];
        
        [_myInfo release];
        _myInfo = [myInfo retain];

        NSString* msg = [NSString decodeHTMLEntities:[myInfo statusMsg]];
        if (msg)
        {
          [_statusMessage release];
          _statusMessage = [msg retain];
        }
        msg = [NSString decodeHTMLEntities:[myInfo awayMsg]];
        if (msg)
        {
          _awayMessage = [msg copy]; //awayMsg contains xhtml

          [_awayMessage release];
          _awayMessage = [msg retain];
        }
        
        if ([dictionary valueForKeyPath:@"response.data.myInfo.aimId"])
        {
          // TODO:should this set?  or just ASSERT to be TRUE?
          [self setUserName:[dictionary valueForKeyPath:@"response.data.myInfo.aimId"]];
        }
        
        //[[NSNotificationCenter defaultCenter] postNotificationName:kWimClientSessionOnline object:self];
        //[[NSNotificationCenter defaultCenter] postNotificationName:kWimClientSessionEndConnectAttempt object:self];
        if (_fetchUrl)
        {
          [self setConnectionState:ConnectionState_Connected];
          [self fetchEvents];
        }
        else
        {
          [self resetSession];
          [self setConnectionState:ConnectionState_Authenticating];
        }
        break;
      }
      case 607:
      {
        MLog(@"account has been rate limited");

        if ([_delegate respondsToSelector:@selector(wimSessionRateLimited:)])
          [_delegate performSelector:@selector(wimSessionRateLimited:) withObject:self];
        
        [self setConnectionState:ConnectionState_Offline];
        return;
      }
        
      case 408:
      {
        MLog(@"timeout of backend servers");

        if ([_delegate respondsToSelector:@selector(wimSessionServerError:)])
          [_delegate performSelector:@selector(wimSessionServerError:) withObject:self];

        [self setConnectionState:ConnectionState_Offline];
        return;
      }
        
      case 400:
      case 401:
      case 440:
      case 462:
      {
        [_tokenExpiration release];
        _tokenExpiration = nil;
        [self setConnectionState:ConnectionState_Authenticating];
        return;
      }
        
        
      default:
      {
        MLog(@"retrying session start");
        [self setConnectionState:ConnectionState_Connecting];
        return;
      }
    }
}        


- (void)onWimEventFetchEvents:(WimRequest *)wimRequest withError:(NSError *)error
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(watchDog:) object:_wimFetchRequest];

  [_wimFetchRequest release];
  _wimFetchRequest = nil;
  
  if (error)
  {
    MLog(@"onWimEventFetchEvents failed with error: %@", [error description]);
    [self setConnectionState:ConnectionState_Reconnecting];
    
    return;
  }
  
  
  NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  MLog (jsonResponse);
  
  NSDictionary* aDictionary = nil;
  
  @try {
    aDictionary = [jsonResponse JSONValue];
  }
  @catch (NSException *e) {
    MLog (@"Exception %@", e);
  }
  
  MLog( @"onWimEventFetchEvents - %@", aDictionary );
  
  int statusCode = [[aDictionary valueForKeyPath:@"response.statusCode"] intValue];
  
  if (statusCode == 200)
  {
    // notify that we're in the good fetchloop
    [self setConnectionState:ConnectionState_Connected];
    
    NSTimeInterval nextFetch = [[aDictionary valueForKeyPath:@"response.data.timeToNextFetch"] intValue];

    NSString *fetchBaseURL = [aDictionary stringValueForKeyPath:@"response.data.fetchBaseURL"];
    [_fetchUrl release];
    
    if (fetchBaseURL)
    {
      _fetchUrl = [[NSString stringWithFormat: kUrlFetchRequest, fetchBaseURL, [self nextRequestId] , kUrlFetchTimeout] retain];
    }
    else
    {
      _fetchUrl = nil;
    }
        
    NSArray* events = [aDictionary valueForKeyPath:@"response.data.events"];
    [self parseEvents:events];
    
    if (_pendingEndSession==NO)
    {
      // change this to delay - timeIntervals as in seconds -- timeToNextFetch is in milliseconds
      nextFetch = nextFetch / 1000;
      
      if (nextFetch == 0 )
      {
        // wait at least a second
        nextFetch = 1;
      }
      
      [self performSelector:@selector(fetchEvents) withObject:self afterDelay:nextFetch];
    }
  }
  else
  {
    MLog(@"received error error from fetch (%d)", statusCode);
    
    if (statusCode == 401)
    {
      [_tokenExpiration release];
      _tokenExpiration = nil;
    }
    
    [self resetSession];
    [self setConnectionState:ConnectionState_Authenticating]; 
  }
}

- (void)onWimEventEndSession:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventEndSession failed with error: %@", [error description]);
  }

  [self resetSession];
  [self setConnectionState:ConnectionState_Offline];
}



- (void)onWimEventPresenceResponse:(WimRequest *)wimRequest withError:(NSError *)error
{  
  if (error)
  {
    MLog(@"onWimEventPresenceResponse failed with error: %@", [error description]);
    return;
  }
  
  NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  
  NSDictionary* dictionary =  nil;
  
  @try {
  dictionary = [jsonResponse JSONValue];
  } @catch (NSException *e) {
    MLog(@"Exception %@", e);
  }
  if (dictionary)
  {
    NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
    
    if ([statusCode isEqual:[NSNumber numberWithInt:200]])
    {
      NSEnumerator *buddies = [[dictionary valueForKeyPath:@"response.data.users"] objectEnumerator];
      NSMutableDictionary *buddy;
      while (buddy = [buddies nextObject])
      {
        [_delegate wimSession:self receivedPresenceEvent:buddy];
      }
    }
      }
    }

- (void)onWimEventProposalReplySentResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventProposalReplySentResponse failed with error: %@", [error description]);
  }
  else
  {
    NSString* jsonString = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
    MLog(@"onWimEventProposalReplySentResponse received indicating success:");
    MLog (jsonString);
  }
}

- (void)onWimEventIMSentResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  NSString* jsonString = nil;
  
  if (error)
  {
    // synthesize an error 400 from the server
    jsonString = @"{\"response\":{\"statusCode\":400, \"statusText\":\"Session does not exist\", \"requestId\":\"\", \"data\":{}}}";
    MLog(@"onWimEventIMSentResponse failed with error: %@", [error description]);
  }
  else
  {
    jsonString = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  }
    
  MLog (jsonString);
  
  
  NSDictionary* jsonDictionary =  nil;
  
  @try {
    jsonDictionary = [jsonString JSONValue];
  }
  @catch (NSException *e) {
    MLog (@"Exception %@", e);
  }

  if (jsonDictionary) {
    
    NSInteger statusCode = [[jsonDictionary valueForKeyPath:@"response.statusCode"] intValue];
    [self checkForAuthenticationError:statusCode];
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[wimRequest userData], @"sendIMData",
                                jsonDictionary, @"serverResponse",
                                nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:kWimClientIMSent object:self userInfo:dictionary];
  }
}

- (void)onWimEventSetStateResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventPresenceResponse failed with error: %@", [error description]);
    return;
  }
  
  NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];;
  NSDictionary* dictionary = nil;
  @try {
    dictionary = [jsonResponse JSONValue];  
  }
  @catch (NSException * e) {
    MLog(@"Exception %@", e);
  }
  
  if (dictionary)
  {
    NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
    
    if ([statusCode isEqual:[NSNumber numberWithInt:200]])
    {
      NSDictionary *buddy  = [dictionary valueForKeyPath:@"response.data.myInfo"];
      
      [_myInfo release];
      _myInfo = [buddy retain];

      if ([[[[wimRequest urlRequest] URL] query] rangeOfString:@"view=online"].location != NSNotFound)
      {
        [_myInfo setValue:@"online" forKey:@"state"];
      }
      else if ([[[[wimRequest urlRequest] URL] query] rangeOfString:@"view=away"].location != NSNotFound)
      {
        [_myInfo setValue:@"away" forKey:@"state"];
      }
      
      [_delegate wimSession:self receivedMyInfoEvent:_myInfo];
    }
  }
  
}

- (void)onWimEventSetStatusResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventSetStatusResponse failed with error: %@", [error description]);
    return;
  }
  
  NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  
  NSDictionary* dictionary = nil;
  @try {
    dictionary = [jsonResponse JSONValue];
  }
  @catch (NSException *e) {
    MLog(@"Exception %@", e);
  }
    
  if (dictionary)
  {
    NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
    
    if ([statusCode isEqual:[NSNumber numberWithInt:200]])
    {
		// successful
    }
  }
}

- (void)onWimEventSetProfileResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventSetProfileResponse failed with error: %@", [error description]);
  }
}  

- (void)onWimEventSetBuddyAttributeResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventSetBuddyAttributeResponse failed with error: %@", [error description]);
  }
}  

- (void)onWimEventRemoveBuddyResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventRemoveBuddyResponse failed with error: %@", [error description]);
  }
}


- (void)onWimEventAddBuddyResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventAddBuddyResponse failed with error: %@", [error description]);
  }
  else
  {
    NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
    
    NSDictionary* dictionary = nil;
    
    @try {
      dictionary = [jsonResponse JSONValue];
    }
    @catch (NSException *e) {
      MLog (@"exception %S", e);
    }
    
    if (dictionary)
    {
      NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
      
      if ([statusCode intValue] == 200)
      {
        NSInvocation *invocation = [[wimRequest userData] objectForKey:@"delayedInvocation"];
        [invocation invoke];
      }
    }
  }
}  


- (void)onWimEventSetLargeBuddyIconResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventSetLargeBuddyIconResponse failed with error: %@", [error description]);
    return;
  }

  NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  NSDictionary* dictionary = nil;
  
  @try {
    dictionary = [jsonResponse JSONValue];
  }
  @catch (NSException *e) {
    MLog (@"exception %S", e);
  }
  
  NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
  if (200 == [statusCode intValue])
  {
    
    MLog(@"SetLargeBuddyIcon response %@", jsonResponse);

    NSString *iconId = [dictionary valueForKeyPath:@"response.data.id"];
    if (iconId)
    {
      NSString *subIconId = [iconId substringFromIndex:4];
      MLog(@"new asset %@", subIconId);
      [self setExpresssion:subIconId];
    }
  }
}  

- (void)onWimEventSetExpressionResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventSetExpressionResponse failed with error: %@", [error description]);
    return;
  }
  
  NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  NSDictionary* dictionary = nil;
  
  @try {
    dictionary = [jsonResponse JSONValue];
  }
  @catch (NSException *e) {
    MLog (@"exception %S", e);
  }
  
  MLog(@"setExpression response %@", jsonResponse);
  
  NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
  if (200 == [statusCode intValue])
  {
    [self requestPresenceForAimId:[self aimId]];
    MLog(@"iconset");
  }
  
}

- (void)onWimEventMoveGroupResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventMoveGroupResponse failed with error: %@", [error description]);
    return;
  }
  
  //NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  //NSDictionary* dictionary = [jsonResponse JSONValue];//[NSDictionary dictionaryWithJSONString:jsonResponse];
  //NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
}  

- (void)onWimEventRemoveGroupResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventRemoveGroupResponse failed with error: %@", [error description]);
    return;
  }
  
  //NSString* jsonResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  //NSDictionary* dictionary = [jsonResponse JSONValue];//[NSDictionary dictionaryWithJSONString:jsonResponse];
  //NSNumber *statusCode = [dictionary valueForKeyPath:@"response.statusCode"];
}  


- (void)onWimEventGetHostBuddyInfoResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error)
  {
    MLog(@"onWimEventGetHostBuddyInfoResponse failed with error: %@", [error description]);
    return;
  }
  
  // resulting data is HTML
  NSString *htmlResponse = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];

  NSArray *userData = [wimRequest userData];
  if ([userData count] == 1)
  {
    NSString *aimId = [userData objectAtIndex:0];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                aimId, WimSessionBuddyInfoAimIdKey,
                                htmlResponse ? htmlResponse : @"", WimSessionBuddyInfoHtmlKey,
                                nil];
                                
    [_delegate wimSession:self receivedHostBuddyInfoEvent:dictionary];
  }
}  


#pragma mark Class Accessors

- (void)setDelegate:(id)aDelegate
{
  _delegate = aDelegate; // weak
}

- (id)delegate
{
  return _delegate;
}

// this method is really meant for testing of captcha based secondary challenges
- (void)setForceCaptcha:(BOOL)aForceCaptcha
{
  _forceCaptcha = aForceCaptcha;
}

- (void)setUserName:(NSString*)username
{
  username = [username copy];
  [_userName autorelease];
  _userName = username;
}

- (NSString *)userName
{
  return _userName;
}

- (void)setPassword:(NSString*)password
{
  password = [password copy];
  [_password autorelease];
  _password = password;
}

- (NSString *)password
{
  return _password;
}

- (NSDictionary *)buddyList
{
  return _buddyList;
}

- (void)setBuddyList:(NSDictionary *)buddyList
{
  NSMutableDictionary* mutableList = [buddyList mutableCopy];
  [_buddyList release];
  _buddyList = mutableList;
  [self buddyListArrived];
}


- (NSArray *)groupsForBuddy:(NSDictionary *)buddy
{
  NSMutableArray *result = [NSMutableArray array];
  
  NSArray *buddyList = [_buddyList valueForKey:@"groups"];
  
  NSEnumerator* buddyListGroups = [buddyList objectEnumerator];
  NSArray* buddyGroup;
  while ((buddyGroup = [buddyListGroups nextObject])) 
  {
    NSEnumerator *buddies = [[buddyGroup valueForKey:@"buddies"] objectEnumerator];
    NSMutableDictionary *testBuddy;
    while (testBuddy = [buddies nextObject])
    {
      if ( [testBuddy isEqualToBuddy:buddy] ) 
      {
        [result addObject:buddyGroup];
        // a buddy should only be in an individual buddygroup once
        break;
      }
    }
  }
  return result;
}


- (NSArray *)groups
{
  return [_buddyList valueForKey:@"groups"];
}

- (NSString*)aimId
{
  return _userName;
} 

- (NSDictionary*)myInfo
{
  if(!_myInfo) 
  {
    MLog(@"Returning minimal myInfo!");
    NSMutableDictionary *fakeMyInfo = [[NSMutableDictionary alloc] init];
    [fakeMyInfo setObject:[self userName] forKey:@"aimId"];
    [fakeMyInfo setObject:[self userName] forKey:@"displayId"];
    
    _myInfo = fakeMyInfo;
  }
  return _myInfo;
} 

@end


@implementation NSString (WimURLEncoding) 

- (NSString *)stringByAddingPercentEscapes 
{ 
  return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, 
                                                    (CFStringRef)self, NULL, NULL, 
                                                    CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) autorelease]; 
} 

- (NSString *)stringByReplacingPercentEscapes 
{ 
  return [(NSString *)CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault,(CFStringRef)self, CFSTR("")) autorelease]; 
} 

@end 
