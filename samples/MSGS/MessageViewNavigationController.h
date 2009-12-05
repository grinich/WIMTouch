#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "Three20/Three20.h"

#import "SearchTestController.h"
#import "MockDataSource.h"

@interface MessageViewNavigationController : UIViewController  <UINavigationController, TTMessageControllerDelegate, SearchTestControllerDelegate> {
    IBOutlet id delegate;
	
	MockDataSource* _dataSource;
	NSTimer* _sendTimer;
}


- (IBAction)compose:(id)sender;

@end
