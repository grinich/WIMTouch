//MLog.h

#ifdef LOGGING_ENABLED

  #define MLog(s,...) \
      [MStringLog logFile:__FILE__ lineNumber:__LINE__ \
            format:(s),##__VA_ARGS__]

  //Conditional logging without file and line numbers
  //#define MLog(s,...) \
  //    (__MLogOn ? NSLog(s, ##__VA_ARGS__) : (void)0)

#else
  
  //Logging as a NOOP
  #define MLog(s,...) \
      ((void)0)

#endif

@interface MStringLog : NSObject
{
}

+(void)logFile:(char*)sourceFile lineNumber:(int)lineNumber 
       format:(NSString*)format, ...;
+(void)setLogOn:(BOOL)logOn;

@end
