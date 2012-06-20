/*
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@implementation LOFaultArray : CPMutableArray {
LOObjectContext objectContext @accessors;
id              masterObject @accessors;
CPString        relationshipKey @accessors;
BOOL            faultFired;
CPArray         array;
}
/*
 + (id)alloc {
 CPLog.trace(@"tracing: LOFaultArray.alloc:");
 var array = [];
 
 array.isa = self;
 
 var ivars = class_copyIvarList(self),
 count = ivars.length;
 
 while (count--)
 array[ivar_getName(ivars[count])] = nil;
 
 return array;
 }
 */
- (id) initWithObjectContext:(CPObjectContext) anObjectContext masterObject:(id) aMasterObject relationshipKey:(CPString) aRelationshipKey {
    //    CPLog.trace(@"tracing: LOFaultArray.init:");
    self = [super init];
    if (self) {
        faultFired = NO;
        objectContext = anObjectContext;
        masterObject = aMasterObject;
        relationshipKey = aRelationshipKey;
        array = [CPArray array];
    }
    return self;
}

- (id)initWithArray:(CPArray)anArray {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithArray: count = " + [anArray count]);
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithArray:anArray];
    }
    return self;
}

- (id)initWithArray:(CPArray)anArray copyItems:(BOOL)shouldCopyItems {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithArray:copyItems:");
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithArray:anArray copyItems:shouldCopyItems];
    }
    return self;
}
/*
 - (id)initWithObjects:(id)anObject, ... {
 CPLog.trace(@"tracing: LOFaultArray.initWithObjects:...");
 self = [super initWithObjects:anObject];
 if (self) {
 }
 return self;
 }
 */
- (id)initWithObjects:(id)objects count:(unsigned)aCount {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithObjects:count:");
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithObjects:objects count:aCount];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)aCapacity {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithCapacity:");
    return [super initWithCapacity:aCapacity];
}

- (id)copy {
    var copy = [super copy];
    copy.objectContext = self.objectContext;
    copy.masterObject = self.masterObject;
    copy.relationshipKey = self.relationshipKey;
    copy.faultFired = self.faultFired;
    copy.array = [array copy];
    return copy;
}

- (int)count {
    //    CPLog.trace(@"tracing: (" + [masterObject loObjectType] + @", " + masterObject._UID + @", " + relationshipKey + @") LOFaultArray.count:" + [array count]);
    //    debugger;
    if (!faultFired) {
        [self requestFault];
        faultFired = YES;
    }
    return [array count];
}

- (id) objectAtIndex:(int) anIndex {
    //    CPLog.trace(@"tracing: (" + [masterObject loObjectType] + @", " + masterObject._UID + @", " + relationshipKey + @") LOFaultArray.objectAtIndex:" + anIndex);
    if (!faultFired) {
        [self requestFault];
        faultFired = YES;
    }
    return [array objectAtIndex:anIndex];
}

- (void)addObject:(id)anObject {
    //    CPLog.trace(@"tracing: LOFaultArray.addObject:");
    [array addObject:anObject];
}

- (void)insertObject:(id)anObject atIndex:(int)anIndex {
    [array insertObject:anObject atIndex:anIndex];
}

- (void)replaceObjectAtIndex:(int)anIndex withObject:(id)anObject {
    [array replaceObjectAtIndex:anIndex withObject:anObject];
}

- (void)removeLastObject {
    [array removeLastObject];
}

- (void)removeObjectAtIndex:(int)anIndex {
    [array removeObjectAtIndex:anIndex];
}

- (void)addObserver:(id)observer forKeyPath:(CPString)aKeyPath options:(unsigned)options context:(id)context {
    CPLog.trace([self className] + @" " + _cmd + @" Begin");
    [array addObserver:observer forKeyPath:aKeyPath options:options context:context];
    CPLog.trace([self className] + @" " + _cmd + @" End");
}

- (void)removeObserver:(id)observer forKeyPath:(CPString)aKeyPath {
    [array removeObserver:observer forKeyPath:aKeyPath];
}

- (void)sortUsingFunction:(Function)aFunction context:(id)aContext {
    [array sortUsingFunction:aFunction context:aContext];
}

- (void)sortUsingDescriptors:(CPArray)descriptors {
    [array sortUsingDescriptors:descriptors];
}

- (void) requestFault {
    var baseURL = [[objectContext objectStore] baseURL];
    if (!baseURL) throw new Error(_cmd + @" Has no baseURL to use");
    var objectStore = [objectContext objectStore];
    var entityName = [relationshipKey substringToIndex:[relationshipKey length] - 1];
    var fs = [LOFetchSpecification fetchSpecificationForEntityNamed:entityName];
    var request = [CPURLRequest requestWithURL:baseURL + @"/martin|/" + entityName + @"/" + [objectStore typeOfObject:masterObject] + @"_fk=" + [objectStore globalIdForObject:masterObject]];
    [request setHTTPMethod:@"GET"];
    receivedData = nil;
    var connection = [CPURLConnection connectionWithRequest:request delegate:objectStore];
    [objectStore.connections addObject:{connection: connection, fetchSpecification: fs, objectContext: objectContext, receiveSelector: LOFaultArrayRequestedFaultReceivedForConnectionSelector, faultArray:self}];
    CPLog.trace(@"tracing: requestFault: " + [masterObject loObjectType] + @", " + relationshipKey);
}

@end
