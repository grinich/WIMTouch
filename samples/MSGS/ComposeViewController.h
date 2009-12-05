//
//  ComposeViewController.h
//  MSGS
//
//  Created by Michael Grinich on 5/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ComposeViewController : UIViewController {
	IBOutlet UITextField *toField;
	IBOutlet UITextField *messageField;

	
}

- (IBAction)sendMessage:(id)sender;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil responseAIMid:(NSString *)AIMid;


@property (nonatomic, retain) UITextField *toField;
@property (nonatomic, retain) UITextField *messageField;




@end
