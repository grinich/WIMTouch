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
#import "NSDictionary+Buddy.h"


@implementation NSDictionary (WIMBuddy)

-(NSString *)aimId
{
  return [self objectForKey:@"aimId"];
}

-(NSString *)displayName
{
  NSString *displayName = [self objectForKey:@"friendly"];
  
  if ([displayName length] == 0)
    displayName = [self objectForKey:@"displayId"];
  
  if ([displayName length] == 0)
    displayName = [self aimId];
  
  return displayName;
}

- (NSComparisonResult)compare:(NSDictionary *)otherBuddy
{
  NSString *myName = [self displayName];
  NSString *otherName = [otherBuddy displayName];
  return [myName localizedCaseInsensitiveCompare:otherName];
}

-(NSString *)buddyIcon
{
  NSString *uri = [self objectForKey:@"buddyIcon"];
  
  if (uri==nil && [self isMobile])
  {
//    uri = @"http://api.oscar.aol.com/expressions/get?f=redirect&t=christinadanger&type=buddyIcon";
 //     uri = @"http://api.oscar.aol.com/expressions/getAsset?t=christinadanger&f=native&type=buddyIcon&id=00052b000004d2";
    uri = [NSString stringWithFormat:@"http://api.oscar.aol.com/expressions/get?f=redirect&t=%@&type=buddyIcon", [self aimId]];
//      uri = @"http://api.oscar.aol.com/expressions/get?f=native&t=christinavm&type=buddyIcon";
  }
  
  return uri;
}

-(NSString *)state
{
  return [self objectForKey:@"state"];
}

-(NSString *)statusMsg
{
  return [self objectForKey:@"statusMsg"];
}

-(NSString *)awayMsg
{
  return [self objectForKey:@"awayMsg"];
}


- (BOOL)isMobile
{
  return [[self state] isEqualToString:@"mobile"]==YES;
}

-(NSString *)group
{
  // Underscore indicates that this data is not part of the WIM specification - and is updated by the client
  return [self objectForKey:@"_group"];
}


-(BOOL)isOnline
{
  return [[self state] isEqualToString:@"offline"]==NO;
}

-(BOOL)isAvailable
{
  NSString *state = [self state];
  
  return (! ([state isEqualToString:@"offline"] || [state isEqualToString:@"unknown"]));
}

-(BOOL)isAway
{
  return [[self state] isEqualToString:@"away"]==YES;
}

-(BOOL)isEqualToBuddy:(NSDictionary *)buddy
{
  return [ [self aimId] isEqualToString:[buddy aimId] ];
}


-(NSData *)buddyIconData
{
  return [self objectForKey:@"_iconData"];
}

@end

@implementation NSMutableDictionary (WIMBuddy)
-(void)updateBuddy:(NSDictionary *)buddyInfo
{
  // update the contents of this NSMutableDictionary to reflect the new status...
#if 0
  BOOL state = ([self state] isEqualToString:[buddyInfo state]);
  BOOL buddyIcon = ([self buddyIcon] isEqualToString:[buddyInfo buddyIcon]);
  BOOL statusMsg = ([self statusMsg] isEqualToString:[buddyInfo statusMsg]);
  
  if (state == NO)
  {
    [self willChangeValueForKey:@"state"];
  }
  
  if (buddyIcon == NO)
  {
    [self willChangeValueForKey:@"buddyIcon"];
  }
  
  if (statusMsg == NO)
  {
    [self willChangeValueForKey:@"statusMsg"];
  }
#endif
  NSString *currentGroup = [[self group] retain];
  
  [self removeAllObjects];
  [self addEntriesFromDictionary:buddyInfo];
  if (currentGroup)
    [self setObject:currentGroup forKey:@"_group"];
  [currentGroup release];
#if 0
  if (state == NO)
  {
    [self didChangeValueForKey:@"state"];
  }
  
  if (buddyIcon == NO)
  {
    [self didChangeValueForKey:@"buddyIcon"];
  }
  
  if (statusMsg == NO)
  {
    [self didChangeValueForKey:@"statusMsg"];
  }
#endif
}

-(void)setBuddyIcon:(NSString*)aBuddyIcon
{
  [self setObject:aBuddyIcon
           forKey:@"buddyIcon"];
}


-(void)setBuddyIconData:(NSData*)aIconData
{
  [self setObject:aIconData forKey:@"_iconData"];
}

@end
