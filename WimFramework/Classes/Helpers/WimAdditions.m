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

#import "WimAdditions.h"

@implementation NSString (URLEncode)

#if 1

// this is all I came up with in at the moment
+ (NSString *)decodeHTMLEntities:(NSString *)source
{ 
  if(!source) return nil;
  else if([source rangeOfString: @"&"].location == NSNotFound) return source;
  else
  {

    NSMutableString *escaped = [NSMutableString stringWithString: source];


    NSArray *entities = [NSArray arrayWithObjects: 
                      @"&amp;", @"&lt;", @"&gt;", @"&quot;",
                      /* 160 = nbsp */
                      @"&nbsp;", @"&iexcl;", @"&cent;", @"&pound;", @"&curren;", @"&yen;", @"&brvbar;",
                      @"&sect;", @"&uml;", @"&copy;", @"&ordf;", @"&laquo;", @"&not;", @"&shy;", @"&reg;",
                      @"&macr;", @"&deg;", @"&plusmn;", @"&sup2;", @"&sup3;", @"&acute;", @"&micro;",
                      @"&para;", @"&middot;", @"&cedil;", @"&sup1;", @"&ordm;", @"&raquo;", @"&frac14;",
                      @"&frac12;", @"&frac34;", @"&iquest;", @"&Agrave;", @"&Aacute;", @"&Acirc;",
                      @"&Atilde;", @"&Auml;", @"&Aring;", @"&AElig;", @"&Ccedil;", @"&Egrave;",
                      @"&Eacute;", @"&Ecirc;", @"&Euml;", @"&Igrave;", @"&Iacute;", @"&Icirc;", @"&Iuml;",
                      @"&ETH;", @"&Ntilde;", @"&Ograve;", @"&Oacute;", @"&Ocirc;", @"&Otilde;", @"&Ouml;",
                      @"&times;", @"&Oslash;", @"&Ugrave;", @"&Uacute;", @"&Ucirc;", @"&Uuml;", @"&Yacute;",
                      @"&THORN;", @"&szlig;", @"&agrave;", @"&aacute;", @"&acirc;", @"&atilde;", @"&auml;",
                      @"&aring;", @"&aelig;", @"&ccedil;", @"&egrave;", @"&eacute;", @"&ecirc;", @"&euml;",
                      @"&igrave;", @"&iacute;", @"&icirc;", @"&iuml;", @"&eth;", @"&ntilde;", @"&ograve;",
                      @"&oacute;", @"&ocirc;", @"&otilde;", @"&ouml;", @"&divide;", @"&oslash;", @"&ugrave;",
                      @"&uacute;", @"&ucirc;", @"&uuml;", @"&yacute;", @"&thorn;", @"&yuml;", nil];
    
    NSArray *characters = [NSArray arrayWithObjects:@"&", @"<", @">", @"\"", nil];
    
    int i, count = [entities count], characterCount = [characters count];
    
    // Html
    for(i = 0; i < count; i++)
    {
      NSRange range = [source rangeOfString: [entities objectAtIndex:i]];
      if(range.location != NSNotFound)
      {
        if (i < characterCount)
        {
          [escaped replaceOccurrencesOfString:[entities objectAtIndex: i] 
                                   withString:[characters objectAtIndex:i] 
                                      options:NSLiteralSearch 
                                        range:NSMakeRange(0, [escaped length])];
        }
        else
        {
          [escaped replaceOccurrencesOfString:[entities objectAtIndex: i] 
                                   withString:[NSString stringWithFormat: @"%C", (160-characterCount) + i] 
                                      options:NSLiteralSearch 
                                        range:NSMakeRange(0, [escaped length])];
        }
      }
    }
    
    // Decimal & Hex
    NSRange start, finish, searchRange = NSMakeRange(0, [escaped length]);
    i = 0;
    
    while(i < [escaped length])
    {
      start = [escaped rangeOfString: @"&#" 
                             options: NSCaseInsensitiveSearch 
                               range: searchRange];
      
      finish = [escaped rangeOfString: @";" 
                              options: NSCaseInsensitiveSearch 
                                range: searchRange];
      
      if(start.location != NSNotFound && finish.location != NSNotFound &&
         finish.location > start.location)
      {
        NSRange entityRange = NSMakeRange(start.location, (finish.location - start.location) + 1);
        NSString *entity = [escaped substringWithRange: entityRange];     
        NSString *value = [entity substringWithRange: NSMakeRange(2, [entity length] - 2)];
        
        [escaped deleteCharactersInRange: entityRange];
        
        if([value hasPrefix: @"x"])
        {
          unsigned tempInt = 0;
          NSScanner *scanner = [NSScanner scannerWithString: [value substringFromIndex: 1]];
          [scanner scanHexInt: &tempInt];
          [escaped insertString: [NSString stringWithFormat: @"%C", tempInt] atIndex: entityRange.location];
        }
        else
        {
          [escaped insertString: [NSString stringWithFormat: @"%C", [value intValue]] atIndex: entityRange.location];
        }
        i = start.location;
      }
      else i++;
      searchRange = NSMakeRange(i, [escaped length] - i);
    }
    
    return escaped;    // Note this is autoreleased
  }
}

+ (NSString *)encodeHTMLEntities:(NSString *)source
{ 
  if(!source) return nil;
  else
  {
    NSArray *characters = [NSArray arrayWithObjects:@"&",     @"<",    @">",    nil];
    NSArray *entities   = [NSArray arrayWithObjects:@"&amp;", @"&lt;", @"&gt;", nil];

    NSMutableString *encoded = [NSMutableString stringWithString: source];
    int i, count = [characters count];
    for(i = 0; i < count; i++)
    {
      [encoded replaceOccurrencesOfString:[characters objectAtIndex: i] 
                               withString:[entities objectAtIndex:i] 
                                  options:NSLiteralSearch 
                                    range:NSMakeRange(0, [encoded length])];
    }
    return encoded; // Note this is autoreleased
  }
}

-(NSString *) urlencode
{
  NSArray *escapeChars = [NSArray arrayWithObjects:@";" , @"/" , @"?" , @":" ,
                          @"@" , @"&" , @"=" , @"+" ,
                          @"$" , @"," , @"[" , @"]",
                          @"#", @"!", @"'", @"(", 
                          @")", @"*", @" ", nil];
	
  NSArray *replaceChars = [NSArray arrayWithObjects:@"%3B" , @"%2F" , @"%3F" ,
                           @"%3A" , @"%40" , @"%26" ,
                           @"%3D" , @"%2B" , @"%24" ,
                           @"%2C" , @"%5B" , @"%5D", 
                           @"%23", @"%21", @"%27",
                           @"%28", @"%29", @"%2A", @"+", nil];
	
  int len = [escapeChars count];
	
  NSMutableString *temp = [[[self stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];

  int i;
  for(i = 0; i < len; i++)
  {
		
    [temp replaceOccurrencesOfString: [escapeChars objectAtIndex:i]
                          withString:[replaceChars objectAtIndex:i]
                             options:NSLiteralSearch
                               range:NSMakeRange(0, [temp length])];
  }
	
  return temp;
}

#else

-(NSString *)urlencode
{
  NSString *escapeChars = @";/?:@&=+$,[]#!'( )*"; 
  return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, 
                                                              (CFStringRef)self, NULL, (CFStringRef)escapeChars, 
                                                              CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) autorelease]; 
}
#endif
@end

@implementation NSMutableString (URLEncode)
- (NSMutableString *)appendValue:(NSString *)value forName:(NSString *)name
{
	if ([self length])
	{
		[self appendString:@"&"];
	}
	
	[self appendFormat:@"%@=%@", name, [value urlencode]];
	return self;
}

@end
