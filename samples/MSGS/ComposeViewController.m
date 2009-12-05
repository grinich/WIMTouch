//
//  ComposeViewController.m
//  MSGS
//
//  Created by Michael Grinich on 5/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ComposeViewController.h"
#import "MSGSAppDelegate.h"


@implementation ComposeViewController

@synthesize toField, messageField;


/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/


 // The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil responseAIMid:(NSString *)AIMid {
 if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
	 [toField setText:AIMid];
 }
 return self;
 }
 

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
    [super dealloc];
}


#pragma mark Open/Close functionality

- (IBAction)sendMessage:(id)sender{
	MSGSAppDelegate *appDelegate = (MSGSAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate onSendWithMessage:[messageField text] recipient:[toField text]];
	[self.navigationController popViewControllerAnimated:YES];
}




@end
