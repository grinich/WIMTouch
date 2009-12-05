//
//  MessageTableViewCellController.h
//  MSGS
//
//  Created by Michael Grinich on 5/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface MessageTableViewCellController : UITableViewCell {

	// adding the 2 labels we want to show in the cell
	UILabel *messageLabel;
	UILabel *fromLabel;
	
	
}


// gets the data from another class
-(void)setData:(NSDictionary *)dict;

// internal function to ease setting up label text
-(UILabel *)newLabelWithPrimaryColor:(UIColor *)primaryColor selectedColor:(UIColor *)selectedColor fontSize:(CGFloat)fontSize bold:(BOOL)bold;
- (NSString *)flattenHTML:(NSString *)html;

	

@property (nonatomic, retain) UILabel *messageLabel;
@property (nonatomic, retain) UILabel *fromLabel;





@end
