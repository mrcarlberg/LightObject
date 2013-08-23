/*
 * Created by Martin Carlberg on August 22, 2013.
 * Copyright 2013, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>


LOFaultDidFireNotification = @"LOFaultDidFireNotification";
LOFaultDidPopulateNotification = @"LOFaultDidPopulateNotification";

LOFaultKey = @"LOFaultKey";
LOFaultFetchSpecificationKey = @"LOFaultFetchSpecificationKey";
LOFaultFetchRelationshipKey = @"LOFaultFetchRelationshipKey";

@protocol LOFault <CPObject>

// Returns all the objects in a to many relationship or just one object if it is a to one relation
- (id)faultReceivedWithObjects:(CPArray)objectList;

- (id)faultDidPopulateNodtificationObject;
- (CPDictionary)faultDidPopulateNodtificationUserInfo;

@end
