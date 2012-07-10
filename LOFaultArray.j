/*
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@implementation LOFaultArray : CPMutableArray {
LOObjectContext objectContext @accessors;
id              masterObject @accessors;
CPString        relationshipKey @accessors;
BOOL            faultFired @accessors;
BOOL            faultPopulated @accessors;
CPArray         array @accessors;
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
    [self _requestFaultIfNecessary];
    return [array count];
}

- (id) objectAtIndex:(int) anIndex {
    [self _requestFaultIfNecessary];
    return [array objectAtIndex:anIndex];
}

- (void)addObject:(id)anObject {
    [self _requestFaultIfNecessary];
    [array addObject:anObject];
}

- (void)insertObject:(id)anObject atIndex:(int)anIndex {
    [self _requestFaultIfNecessary];
    [array insertObject:anObject atIndex:anIndex];
}

- (void)replaceObjectAtIndex:(int)anIndex withObject:(id)anObject {
    [self _requestFaultIfNecessary];
    [array replaceObjectAtIndex:anIndex withObject:anObject];
}

- (void)removeLastObject {
    [self _requestFaultIfNecessary];
    [array removeLastObject];
}

- (void)removeObjectAtIndex:(int)anIndex {
    [self _requestFaultIfNecessary];
    [array removeObjectAtIndex:anIndex];
}

- (void)removeObject:(id)anObject {
    [self _requestFaultIfNecessary];
    [array removeObject:anObject];
}

- (id)_handleObserverForKeyPath:(CPString)aKeyPath {
    return (@"faultFired" === aKeyPath || @"faultPopulated" === aKeyPath)
}

- (void)addObserver:(id)observer forKeyPath:(CPString)aKeyPath options:(unsigned)options context:(id)context {
    if ([self _handleObserverForKeyPath:aKeyPath]) {
        [super addObserver:observer forKeyPath:aKeyPath options:options context:context];
    } else {
        [array addObserver:observer forKeyPath:aKeyPath options:options context:context];
    }
}

- (void)removeObserver:(id)observer forKeyPath:(CPString)aKeyPath {
    if ([self _handleObserverForKeyPath:aKeyPath]) {
        [super removeObserver:observer forKeyPath:aKeyPath];
    } else {
        [array removeObserver:observer forKeyPath:aKeyPath];
    }
}

- (void)setValue:(id)aValue forKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        [self willChangeValueForKey:aKey];
        faultFired = aValue;
        [self didChangeValueForKey:aKey];
    } else if (@"faultPopulated" === aKey) {
        [self willChangeValueForKey:aKey];
        faultPopulated = aValue;
        [self didChangeValueForKey:aKey];
    } else {
        [super setValue:aValue forKey:aKey];
    }
}

- (id)valueForKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        return faultFired;
    } else if (@"faultPopulated" === aKey) {
        return faultPopulated;
    }
    return [super valueForKey:aKey];
}

- (void)sortUsingFunction:(Function)aFunction context:(id)aContext {
    [self _requestFaultIfNecessary];
    [array sortUsingFunction:aFunction context:aContext];
}

- (void)sortUsingDescriptors:(CPArray)descriptors {
    [self _requestFaultIfNecessary];
    [array sortUsingDescriptors:descriptors];
}

- (void)_requestFaultIfNecessary {
    if (!faultFired) {
        faultFired = YES;
        faultPopulated = NO;
        [self requestFault];
    }
}

/*!
 *  This is hard coded: The master object has an attribute (relationshipKey) that is used as the
 *  entity name (the last character is removed, "attribute:persons -> entity:person)
 *  The entity is expected to have a attribute named the type of the master object and ending with _fk (master object type: company -> entity attribute: company_fk)
 */
- (void) requestFault {
    var entityName = [relationshipKey substringToIndex:[relationshipKey length] - 1];
    var qualifier = [CPPredicate predicateWithFormat:[objectContext typeOfObject:masterObject] + @"_fk=%@", [objectContext globalIdForObject:masterObject]];
    var fs = [LOFetchSpecification fetchSpecificationForEntityNamed:entityName qualifier:qualifier];
    [objectContext requestFaultArray:self withFetchSpecification:fs];
}

@end
