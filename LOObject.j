/*!
   LOObject.j
 *
 * Created by Martin Carlberg on Sep 18, 2013.
 * Copyright 2013, All rights reserved.
 */

@import <Foundation/CPObject.j>

@protocol LOObject <CPObject>

@optional

/*!
	Used to perform additional initialization on the receiver upon its
	being fetched from the external repository into an object context
*/
- (void)awakeFromFetch:(LOObjectContext)anObjectContext;

/*!
	Used to perform additional initialization on the receiver upon its
	being inserted into an object context
*/
- (void)awakeFromInsertion:(LOObjectContext)anObjectContext;

@end
