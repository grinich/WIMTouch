//
//  MessageTableViewCellController.m
//  MSGS
//
//  Created by Michael Grinich on 5/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MessageTableViewCellController.h"


@implementation MessageTableViewCellController
@synthesize messageLabel, fromLabel;


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
		// Initialization code
		
		
		/*
		 init the title label.
		 set the text alignment to align on the left
		 add the label to the subview
		 release the memory
		 */
		self.messageLabel = [self newLabelWithPrimaryColor:[UIColor blackColor] selectedColor:[UIColor whiteColor] fontSize:14.0 bold:YES];
		self.messageLabel.textAlignment = UITextAlignmentLeft; // default
		[self.messageLabel setNumberOfLines:0];
		[self.contentView addSubview:self.messageLabel];
		[self.messageLabel release];
		
			
		/*
		 init the population label. (you will see a difference in the font color and size here!
		 set the text alignment to align on the left
		 add the label to the subview
		 release the memory
		 */
        self.fromLabel = [self newLabelWithPrimaryColor:[UIColor lightGrayColor] selectedColor:[UIColor whiteColor] fontSize:10.0 bold:NO];
		self.fromLabel.textAlignment = UITextAlignmentRight; // default
		[self.contentView addSubview:self.fromLabel];
		[self.fromLabel release];
		
		
	}
	
	return self;
}



- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	
	[super setSelected:selected animated:animated];
	// Configure the view for the selected state
}

-(void)setData:(NSDictionary *)dict {
	
	self.fromLabel.text = [NSString stringWithFormat:@"From: %@",  [dict valueForKeyPath:@"eventData.source.aimId"]];
	
	self.messageLabel.text = [self flattenHTML:[dict valueForKeyPath:@"eventData.message"]];
	
}


- (NSString *)flattenHTML:(NSString *)html {
	
    NSScanner *theScanner;
    NSString *text = nil;
	
    theScanner = [NSScanner scannerWithString:html];
	
    while ([theScanner isAtEnd] == NO) {
		
        // find start of tag
        [theScanner scanUpToString:@"<" intoString:NULL] ; 
		
        // find end of tag
        [theScanner scanUpToString:@">" intoString:&text] ;
		
        // replace the found tag with a space
        //(you can filter multi-spaces out later if you wish)
        html = [html stringByReplacingOccurrencesOfString:
				[ NSString stringWithFormat:@"%@>", text]
											   withString:@" "];
		
    } // while //
    
    return html;
}



/*
 this function will layout the subviews for the cell
 if the cell is not in editing mode we want to position them
 */
- (void)layoutSubviews {
	
    [super layoutSubviews];
	
	// getting the cell size
    CGRect contentRect = self.contentView.bounds;
	
	// In this example we will never be editing, but this illustrates the appropriate pattern
    if (!self.editing) {
		
		// get the X pixel spot
        CGFloat boundsX = contentRect.origin.x;
		CGRect frame;
		
		CGFloat endX = contentRect.size.width;
		CGFloat endY = contentRect.size.height;
		
        /*
		 Place the title label.
		 place the label whatever the current X is plus 10 pixels from the left
		 place the label 4 pixels from the top
		 make the label 200 pixels wide
		 make the label 20 pixels high
		 */
		
		frame = CGRectMake(boundsX + 10, 5, 280, 60);
		self.messageLabel.frame = frame;
		
		frame = CGRectMake(endX - 110, 35, 100, 14);
		self.fromLabel.frame = frame;
	}
	
	if (self.editing) { 
		NSLog(@"Self.editing is equal to: %@", self.editing);
		[self.messageLabel setTextColor:[UIColor purpleColor]];
	}
	
}

- (UILabel *)newLabelWithPrimaryColor:(UIColor *)primaryColor selectedColor:(UIColor *)selectedColor fontSize:(CGFloat)fontSize bold:(BOOL)bold
{
	/*
	 Create and configure a label.
	 */
	
    UIFont *font;
    if (bold) {
        font = [UIFont boldSystemFontOfSize:fontSize];
    } else {
        font = [UIFont systemFontOfSize:fontSize];
    }
	
    /*
	 Views are drawn most efficiently when they are opaque and do not have a clear background, so set these defaults.  To show selection properly, however, the views need to be transparent (so that the selection color shows through).  This is handled in setSelected:animated:.
	 */
	UILabel *newLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	newLabel.backgroundColor = [UIColor whiteColor];
	newLabel.opaque = YES;
	newLabel.textColor = primaryColor;
	newLabel.highlightedTextColor = selectedColor;
	newLabel.font = font;
	
	return newLabel;
}


- (void)dealloc {
	[fromLabel release];
	[messageLabel release];
    [super dealloc];
}


@end
