
#import "MessageTestController.h"
#import "SearchTestController.h"
#import "MockDataSource.h"

@implementation MessageTestController

- (id)init {
  if (self = [super init]) {
    _sendTimer = nil;
    _dataSource = nil;
  }
  return self;
}

- (void)dealloc {
  [_sendTimer invalidate];
  [_dataSource release];
	[super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////


- (void)cancelAddressBook {
  [[TTNavigationCenter defaultCenter].frontViewController dismissModalViewControllerAnimated:YES];
}

- (void)sendDelayed:(NSTimer*)timer {
  _sendTimer = nil;
  
  NSArray* fields = timer.userInfo;
  UIView* lastView = [self.view.subviews lastObject];
  CGFloat y = lastView.bottom + 20;
  
  TTMessageRecipientField* toField = [fields objectAtIndex:0];
  for (id recipient in toField.recipients) {
    UILabel* label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    label.backgroundColor = self.view.backgroundColor;
    label.text = [NSString stringWithFormat:@"Sent to: %@", recipient];
    [label sizeToFit];
    label.frame = CGRectMake(30, y, label.width, label.height);
    y += label.height;
    [self.view addSubview:label];
  }
  
  [self.modalViewController dismissModalViewControllerAnimated:YES];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
// TTMessageControllerDelegate

- (void)composeController:(TTMessageController*)controller didSendFields:(NSArray*)fields {
  _sendTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self
    selector:@selector(sendDelayed:) userInfo:fields repeats:NO];
}

- (void)composeControllerDidCancel:(TTMessageController*)controller {
  [_sendTimer invalidate];
  _sendTimer = nil;

  [controller dismissModalViewControllerAnimated:YES];
}

- (void)composeControllerShowRecipientPicker:(TTMessageController*)controller {
  SearchTestController* searchController = [[[SearchTestController alloc] init] autorelease];
  searchController.delegate = self;
  searchController.title = @"Address Book";
  searchController.navigationItem.prompt = @"Select a recipient";
  searchController.navigationItem.rightBarButtonItem = 
    [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
      target:self action:@selector(cancelAddressBook)] autorelease];
    
  UINavigationController* navController = [[[UINavigationController alloc] init] autorelease];
  [navController pushViewController:searchController animated:NO];
  [controller presentModalViewController:navController animated:YES];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// SearchTestControllerDelegate

- (void)searchTestController:(SearchTestController*)controller didSelectObject:(id)object {
  TTMessageController* composeController = (TTMessageController*)self.modalViewController;
  [composeController addRecipient:object forFieldAtIndex:0];
  [controller dismissModalViewControllerAnimated:YES];
}

@end
