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

#import "WimPlatform.h"
#import "WimConstants.h"



NSString* kUrlFetchTimeout = @"28000";

NSString* kAuthOffMethod = @"auth/logout";


NSString *kAPIBaseURL;
NSString *kAuthBaseURL;

NSString* kProdAPIBaseURL = @"http://api.oscar.aol.com/";
NSString* kProdAuthBaseURL = @"https://api.screenname.aol.com/";

NSString *kTestAPIBaseURL = @"http://reddev-l23.tred.aol.com:8000/";
NSString *kTestAuthBaseURL = @"https://api-login.tred.aol.com/";


NSString* kUrlGetClientLogin = @"%@auth/clientLogin"; // requires kAuthBaseURL

NSString* kUrlStartSession = @"%@aim/startSession?%@&sig_sha256=%@"; // requires kAPIBaseURL, queryString, digital signature
NSString* kUrlEndSession = @"%@aim/endSession?f=json&aimsid=%@"; // requires kAPIBaseURL, aimsid
NSString* kUrlFetchRequest = @"%@&f=json&r=%d&timeout=%d "; // requires: fetchBaseUrl, requestId, aimSid, timeout
//NSString* kUrlPresenceRequest = @"%@presence/get?f=json&k=%@&t=%@&awayMsg=1&profileMsg=1&emailLookup=1&location=1&memberSince=1"; // requires: kAPIBaseURL,  key, targetAimId
NSString* kUrlPresenceRequest = @"%@presence/get?f=json&k=%@&t=%@&awayMsg=1&profileMsg=1&statusMsg=1&friendly=1"; // requires: kAPIBaseURL,  key, targetAimId
NSString* kUrlSendIMRequest = @"%@im/sendIM?f=json&k=%@&a=%@&aimsid=%@&r=%d&message=%@&t=%@&autoResponse=%@&offlineIM=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid,requestid,message, target, autoResponse, offlineIM
NSString* kUrlSendDataIM = @"%@im/sendDataIM?f=json&k=%@&a=%@&aimsid=%@&r=%d&t=%@&cap=%@&type=%@&data=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid,requestid,target,capability,type,data
NSString *kUrlSetState = @"%@presence/setState?f=json&k=%@&aimsid=%@&r=%d&view=%@"; // requires kAPIBaseURL, key, authtoken, requestid, state
NSString *kUrlUploadExpression = @"%@expressions/upload?f=json&k=%@&a=%@&aimsid=%@&r=%d&type=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, expression type
NSString *kUrlAddBuddy = @"%@buddylist/addBuddy?f=json&k=%@&a=%@&aimsid=%@&r=%d&buddy=%@&group=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, newBuddy, groupName
NSString *kUrlSetBuddyAttribute = @"%@buddylist/setBuddyAttribute?f=json&k=%@&a=%@&aimsid=%@&r=%d&buddy=%@&friendly=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, aimId, friendlyName
NSString *kUrlMoveGroup = @"%@buddylist/moveGroup?f=json&k=%@&a=%@&aimsid=%@&r=%d&group=%@&beforeGroup=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, groupName, beforeGroup
NSString *kUrlRemoveGroup = @"%@buddylist/removeGroup?f=json&k=%@&a=%@&aimsid=%@&r=%d&group=%@"; // requires: kAPIBaseURL, key, authtoken, aimSid, requestid, group

// Fetched Event
NSString *kWimSessionMyInfoEvent = @"com.aol.aim.event.myInfoEvent";
NSString *kWimSessionPresenceEvent = @"com.aol.aim.event.presenceEvent";
NSString *kWimSessionTypingEvent = @"com.aol.aim.event.typingEvent";
NSString *kWimSessionDataIMEvent = @"com.aol.aim.event.dataIMEvent";
NSString *kWimSessionIMEvent = @"com.aol.aim.event.imEvent";
NSString *kWimSessionOfflineIMEvent = @"com.aol.aim.event.offineIMEvent";
NSString *kWimSessionBuddyListEvent = @"com.aol.aim.event.buddyListEvent";
NSString *kWimSessionSessionEndedEvent = @"com.aol.aim.event.sessionEndedEvent";
NSString *kWimSessionHostBuddyInfoEvent = @"com.aol.aim.event.hostBuddyInfoEvent";

// Client Events
NSString *kWimClientIMSent = @"com.aol.aim.client.imSent";
NSString *kWimClientConnectionStateChange = @"com.aol.aim.client.connectionchanged";


// WIMRequest events
NSString *kWimRequestDidStart = @"com.aol.aim.requestDidStart";
NSString *kWimRequestDidFinish = @"com.aol.aim.requestDidFinish";

NSString *WimSessionBuddyInfoAimIdKey = @"WimSessionBuddyInfoAimId";
NSString *WimSessionBuddyInfoHtmlKey = @"WimSessionBuddyInfoHtml";


// capabilities for dataIM
NSString* WimDataIMCapability_DirectIM = @"094613454c7f11d18222444553540000";

