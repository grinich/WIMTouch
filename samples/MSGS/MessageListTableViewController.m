//
//  MessageListTableViewController.m
//  MSGS
//
//  Created by Michael Grinich on 5/3/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MessageListTableViewController.h"
#import "MessageTableViewCellController.h"
#import "ComposeViewController.h"


@implementation MessageListTableViewController



/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/


/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[self.tableView reloadData];
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
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



#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {	
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	MSGSAppDelegate *appDelegate = (MSGSAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSLog(@"All message: %@", [appDelegate allMessages]);
	NSLog(@"Row count: %i", [[appDelegate allMessages] count] );
	return [[appDelegate allMessages] count];

}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath  
{  
	// All rows have same height
    return 70.0; //returns floating point which will be used for a cell row height at specified row index  
}  

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    MessageTableViewCellController *cell = (MessageTableViewCellController *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[MessageTableViewCellController alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Set up the cell...

	
	[cell setAccessoryType:(UITableViewCellAccessoryDisclosureIndicator)];
	MSGSAppDelegate *appDelegate = (MSGSAppDelegate *)[[UIApplication sharedApplication] delegate];

	[cell setData:[[appDelegate allMessages] objectAtIndex:indexPath.row]];
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
	
		
	ComposeViewController *compose = [[ComposeViewController alloc] initWithNibName:@"ComposeView" bundle:nil];
	MSGSAppDelegate *appDelegate = (MSGSAppDelegate *)[[UIApplication sharedApplication] delegate];

	compose.toField.text = [NSString stringWithString:[[[appDelegate allMessages] objectAtIndex:indexPath.row] valueForKeyPath:@"eventData.source.aimId"]];
	
	[self.navigationController pushViewController:compose animated:YES];
	
	
//	MSGSAppDelegate *appDelegate = (MSGSAppDelegate *)[[UIApplication sharedApplication] delegate];
//	NSString* aid = [[[appDelegate allMessages] objectAtIndex:indexPath.row] valueForKeyPath:@"eventData.source.aimId"];
//	
//	ComposeViewController *compose = [[ComposeViewController alloc] initWithNibName:@"ComposeView" bundle:nil responseAIMid:aid];
//	
//	[self.navigationController pushViewController:compose animated:YES];
	
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


- (void)dealloc {
    [super dealloc];
}


@end

