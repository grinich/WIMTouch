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

#import "ClientLogin.h"
#import "ClientLogin+Private.h"
#import "MLog.h"
#import "WimRequest.h"

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
#import <CommonCrypto/CommonHMAC.h>
#else
#import "CommonHMAC.h"
#endif

#import "NSDataAdditions.h"
#import "JSON.h"

NSString* kAimLoginEventTokenResponse = @"aim.login.event.token.response";
NSString* kAuthOnMethod  = @"auth/clientLogin";

@implementation ClientLogin

- (id)init
{
	if (self = [super init])
	{
	}
	return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_loginResponse release];
  [_screenName release];
  [_password release];
  [super dealloc];
}

- (void)setDelegate:(id)aDelegate
{
  _delegate = aDelegate; // weak
}


- (void)onClientLoginResponse:(WimRequest *)wimRequest withError:(NSError *)error
{
  if (error) 
  {
    // TODO: handle failures -- return to offline state
    MLog(@"onClientLoginResponse failure");
    return;
  }
  
  NSString* jsonString = [[[NSString alloc] initWithData:[wimRequest data] encoding:NSUTF8StringEncoding] autorelease];
  NSDictionary* jsonDictionary = [jsonString JSONValue];

	// Parse returned data
  [_loginResponse release];
  _loginResponse = [jsonDictionary retain];
  
  int statusCode = [[self statusCode] intValue];
  int statusDetailCode = 0;
  
  MLog(@"onClientLoginResponse statusCode = %d", statusCode);
  
  // Send a challenge event, if needed
  switch (statusCode)
  {
    case 330:
      statusDetailCode = [[self statusDetailCode] intValue];
      switch (statusDetailCode)
      {
        //Status DetailCodes (statusDetailCode)
        //3xxx - Authentication/Challenges Related errors
        //3011 - Password-LoginId Required/Invalid
        //3012 - SecurId Required/Invalid
        //3013 - SecurId Next Token Required
        //3014 - ASQ Required/Invalid
        //3015 - Captcha Required/Invalid
        //3016 - AOLKey Required
        //3017 - Rights/Consent Required
        //3018 - TOS/Privacy Policy Accept Required (this is not same as Rights/Consent - this is for future extension)
        //3019 - Account Not allowed
        //3020 - Email not confirmed
        //3021 - Account needs to be updated (send user to AOL)
        
        case 3011:
        case 3012:
        case 3014:
        case 3015:
          MLog(@"Secondary Challenge requested");
          if ([_delegate respondsToSelector:@selector(clientLoginRequiresChallenge:)])
            [_delegate performSelector:@selector(clientLoginRequiresChallenge:) withObject:self];
            break;
        default:
          MLog(@"Unhandled Secondary Challenge");
          break;
      }
      break;
    case 200:
      {
      // Create authDigest of password and sessionSecret. This is used as a key for signing future requests.
      const char* password = [[self password] cStringUsingEncoding:NSASCIIStringEncoding];
      const char* sessionSecret = [[self sessionSecret] cStringUsingEncoding:NSASCIIStringEncoding];

      unsigned char macOut[CC_SHA256_DIGEST_LENGTH];
    
      CCHmac(kCCHmacAlgSHA256, password, strlen(password), sessionSecret, strlen(sessionSecret), macOut);
      NSData *hash = [[[NSData alloc] initWithBytes:macOut length:sizeof(macOut)] autorelease];
      NSString *baseSixtyFourHash = [hash base64Encoding];
    
      [self setSessionSecret:nil];
      [self setSessionKey:baseSixtyFourHash];

      _clientTime = [[NSDate date] timeIntervalSince1970];
        
      MLog(@"ClockSkew = %f", [self clockSkew]);
        
      if ([_delegate respondsToSelector:@selector(clientLoginComplete:)])
           [_delegate performSelector:@selector(clientLoginComplete:) withObject:self];
                
      }
      break;
    default:
      {
      MLog(@"Sign On Failure");
      if ([_delegate respondsToSelector:@selector(clientLoginFailed:)])
        [_delegate performSelector:@selector(clientLoginFailed:) withObject:self];
      }
      break;
  }
}

- (void)requestSessionKey:(NSString *)screenName withPassword:(NSString*)password forceCaptcha:(BOOL)forceCaptcha
{
  [self requestSessionKey:screenName withPassword:password andChallengeAnswer:nil andForceCaptcha:forceCaptcha];
}

- (void)requestSessionKey:(NSString *)screenName withPassword:(NSString*)password
{
  [self requestSessionKey:screenName withPassword:password andChallengeAnswer:nil andForceCaptcha:NO];
}

- (void)answerChallenge:(NSString *)challengeAnswer
{
  if ([[self statusDetailCode] isEqualToString:@"3011"])
  {
    [self requestSessionKey:[self screenName] withPassword:challengeAnswer andChallengeAnswer:nil andForceCaptcha:NO];
  }
  else
  {
    [self requestSessionKey:[self screenName] withPassword:[self password] andChallengeAnswer:challengeAnswer andForceCaptcha:NO];
  }
}

- (void)requestSessionKey:(NSString *)screenName withPassword:(NSString*)password andChallengeAnswer:(NSString *)challengeAnswer andForceCaptcha:(BOOL)forceCaptcha
{
  MLog(@"ClientLogin baseURL: %@", kAuthBaseURL);
  
  WimRequest *wimRequest = [[[WimRequest alloc] init] autorelease];
  [wimRequest setDelegate:self];
  [wimRequest setAction:@selector(onClientLoginResponse:withError:)];

  NSString *urlString = [NSString stringWithFormat:@"%@%@", kAuthBaseURL, kAuthOnMethod];
  NSURL *url = [NSURL URLWithString:urlString];
  
  if(!challengeAnswer) 
  {
    [_loginResponse release];
    _loginResponse = nil;
  }

  [self setScreenName: screenName];
  [self setPassword:password];

  // Package up all params in query format and SHA256 sign resulting buffer.
  NSMutableString *queryString = [[[NSMutableString alloc] init] autorelease];
 
  // Set up params in alphabetical order
  // Captcha word
  if([[self statusDetailCode] isEqualToString:@"3015"]) 
  {
    [queryString appendValue:challengeAnswer forName:@"word"];
  }
  
  if([self challengeContext] != nil) 
  {
    [queryString appendValue:[self challengeContext] forName:@"context"];
  }
  
  if([[self statusDetailCode] isEqualToString:@"3012"]==NO && [[self statusDetailCode] isEqualToString:@"3015"]==NO) 
  {
      //[self setClientName: kClientName];
      //[self setClientVersion: kClientVersion];
    [queryString appendValue:[_delegate clientName] forName:@"clientName"];
    [queryString appendValue:[_delegate clientVersion] forName:@"clientVersion"];
  }

  NSMutableString *devId;
  devId = [[[_delegate devID] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  //[devId replaceOccurrencesOfString:@"-" withString:@"%2D" options:0 range:NSMakeRange(0, [devId length])];

  [queryString appendValue:devId forName:@"devId"];
  [queryString appendValue:@"json" forName:@"f"];
  [queryString appendValue:@"en-us" forName:@"language"];

  // request 1 year token
  [queryString appendValue:@"longterm" forName:@"tokenType"];

  if(forceCaptcha) 
  {
    [queryString appendValue:@"yes" forName:@"forceRateLimit"];
  }

  if([self statusDetailCode] == nil || 
    [[self statusDetailCode] isEqualToString:@"3011"] || 
    [[self statusDetailCode] isEqualToString:@"3015"] || 
    [[self statusDetailCode] isEqualToString:@"3012"])
  {
    [queryString appendValue:password forName:@"pwd"];
  }

  [queryString appendValue:[self screenName] forName:@"s"];

  if([[self statusDetailCode] isEqualToString:@"3012"] || 
    [[self statusDetailCode] isEqualToString:@"3013"] )
  {
    [queryString appendValue:challengeAnswer forName:@"securid"];
  }

  NSData *postData = [queryString dataUsingEncoding:NSUTF8StringEncoding];

  // Package up POST data
  MLog(@"ClientLogin: %@", queryString);

  //[self setStatusCode:nil];
  //[self setStatusDetailCode:nil];

  [wimRequest requestURL:url withData:postData];
}

- (NSString *) screenName {
  return _screenName;
}

- (void) setScreenName: (NSString *) newValue {
  [_screenName autorelease];
  _screenName = [newValue retain];
}


- (void) setPassword: (NSString *) newValue {
  newValue = [newValue copy];
  [_password autorelease];
  _password = newValue;
}

- (NSString*)password
{
  return _password;
}


- (NSString *) statusCode {
  return [_loginResponse stringValueForKeyPath:@"response.statusCode"];
}

- (NSString *) statusDetailCode {
  return [_loginResponse stringValueForKeyPath:@"response.statusDetailCode"];
}

- (NSString *) statusText {
  return [_loginResponse stringValueForKeyPath:@"response.statusText"];
}


- (NSString *) tokenStr {
  return [_loginResponse stringValueForKeyPath:@"response.data.token.a"];
}

- (NSString *) challengeContext {
  return [_loginResponse stringValueForKeyPath:@"response.data.challenge.context"];
}


- (NSString *) sessionSecret {
  return [_loginResponse stringValueForKeyPath:@"response.data.sessionSecret"];
}

- (NSTimeInterval) hostTime {
  return (NSTimeInterval)[[_loginResponse valueForKeyPath:@"response.data.hostTime"] doubleValue];
}

- (NSTimeInterval) clockSkew {
  return [self hostTime] - _clientTime;
}

- (void)setSessionSecret:(NSString*)newValue{
  // TODO: this should be mutable
  return;
}

- (NSString *) challengeURL {
  return [_loginResponse stringValueForKeyPath:@"response.data.challenge.url"];
}


- (NSString *) challengeInfo {
  return [_loginResponse stringValueForKeyPath:@"response.data.challenge.info"];
}

- (NSString *) expiresIn {
  return [_loginResponse stringValueForKeyPath:@"response.data.token.expiresIn"];
}

- (NSString *) sessionKey {
  return _sessionKey;
}

- (void) setSessionKey: (NSString *) newValue {
  [_sessionKey autorelease];
  _sessionKey = [newValue copy];

}

@end
