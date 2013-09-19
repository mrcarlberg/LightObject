/*
 * Created by Martin Carlberg on July 8, 2013.
 * Copyright 2013, All rights reserved.
 */

@import <Foundation/CPArray.j>
@import <Foundation/CPPredicate.j>
@import "LOFault.j"


@implementation LOFaultObject : CPObject <LOFault> {
    LOObjectContext objectContext @accessors;
//    id              masterObject @accessors;
//    CPString        relationshipKey @accessors;
    CPString        entityName @accessors;
    CPString        primaryKey @accessors;
    BOOL            faultFired @accessors;
    BOOL            faultPopulated @accessors;
    LOFetchSpecification fetchSpecification;
}

+ (LOFaultObject)faultObjectWithObjectContext:(CPObjectContext)anObjectContext entityName:(CPString)anEntityName primaryKey:(CPString)aPrimaryKey {
    return [[LOFaultObject alloc] initWithObjectContext:anObjectContext entityName:anEntityName primaryKey:aPrimaryKey];
}

- (id)initWithObjectContext:(CPObjectContext)anObjectContext entityName:(CPString)anEntityName primaryKey:(CPString)aPrimaryKey {
    self = [super init];
    if (self) {
        faultFired = NO;
        objectContext = anObjectContext;
        entityName = anEntityName;
        primaryKey = aPrimaryKey;
    }
    return self;
}

- (id)copy {
    var copy = [super copy];
    copy.objectContext = self.objectContext;
    copy.entityName = self.entityName;
    copy.primaryKey = self.primaryKey;
    copy.faultFired = self.faultFired;
    copy.faultPopulated = self.faultPopulated;
    copy.fetchSpecification = self.fetchSpecification;
    return copy;
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
        [self _requestFaultIfNecessary];

        // TODO: Save all the set values and maybe apply them later???
        [super setValue:aValue forKey:aKey];
    }
}

- (id)valueForKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        return faultFired;
    } else if (@"faultPopulated" === aKey) {
        return faultPopulated;
    }
    [self _requestFaultIfNecessary];

    // We do never have a valid value in the fault object so we just return nil
    return nil;
}

- (void)_requestFaultIfNecessary {
    if (!faultFired) {
        [self requestFaultWithCompletionBlock:nil];
    }
}

/*!
    This is hard coded: The relationshipKey from the master object is used as the entity name
    This can be changed when we are using a model.
 */
- (void) requestFaultWithCompletionBlock:(Function)aCompletionBlock {
    if (!faultFired) {
        [self setFaultFired:YES];
        faultFired = YES;
        faultPopulated = NO;
        var objectStore = [objectContext objectStore];
        var primaryKeyAttribute = [objectStore primaryKeyAttributeForType:entityName objectContext:objectContext];
        var qualifier = [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForKeyPath:primaryKeyAttribute]
                                                           rightExpression:[CPExpression expressionForConstantValue:primaryKey]
                                                                  modifier:CPDirectPredicateModifier
                                                                      type:CPEqualToPredicateOperatorType
                                                                   options:0];
        fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:entityName qualifier:qualifier];
        [objectContext requestFaultObject:self withFetchSpecification:fetchSpecification withCompletionBlock:aCompletionBlock];
        [[CPNotificationCenter defaultCenter] postNotificationName:LOFaultDidFireNotification object:self userInfo:[CPDictionary dictionaryWithObjects:[fetchSpecification] forKeys:[LOFaultFetchSpecificationKey]]];
        //CPLog.trace([self className] + " " + _cmd + " Fire fault: '" + entityName + "' q: " + [qualifier description]);
    } else if (aCompletionBlock) {
        if (faultPopulated) {
            aCompletionBlock(self);
        } else {
            [objectStore addCompletionBlock:aCompletionBlock toTriggeredFault:self];
        }
    }
}

- (void)faultReceivedWithObjects:(CPArray)objectList withCompletionBlocks:(CPArray)completionBlocks {
    // Here we morph this fault object to the real object now when we are getting its data.
    var faultDidPopulateNotificationUserInfo = [CPDictionary dictionaryWithObjects:[fetchSpecification] forKeys:[LOFaultFetchSpecificationKey]];
    var object = objectList[0];
    [self morphObjectTo:object callCompletionBlocks:completionBlocks postNotificationWithObject:self andUserInfo:faultDidPopulateNotificationUserInfo];
}

- (void)morphObjectTo:(id)object callCompletionBlocks:(CPArray)completionBlocks postNotificationWithObject:(id)notificationObject andUserInfo:(CPDictionary)notificationUserInfo {
    [self morphObjectTo:object];
    [objectContext awakeFromFetchForObjects:[object]];
    [objectContext callCompletionBlocks:completionBlocks withObject:self];

    [[CPNotificationCenter defaultCenter] postNotificationName:LOFaultDidPopulateNotification object:notificationObject userInfo:notificationUserInfo];
}

- (id)morphObjectTo:(id)anObject {
    if (!anObject) {
        // If the fetch didn't find an object leave this fault alone. It will ne never fire again and it will return nil on all keys for 'valueForKey:'
        return self;
    }

    var objectStore = [objectContext objectStore],
        allAttributes = [objectStore attributeKeysForObject:anObject],
        attributes = [];

    //CPLog.trace([self className] + " " + _cmd + " Morph to object: '" + [anObject description]);

    // All to one relationsships need to be translated from foreign key attribute.
    for (var i = 0, size = allAttributes.length; i < size; i++) {
        var attributeKey = allAttributes[i];
        if ([objectStore isForeignKeyAttribute:attributeKey forType:entityName objectContext:objectContext])    // Handle to one relationship.
            attributes.push([objectStore toOneRelationshipAttributeForForeignKeyAttribute:attributeKey forType:entityName objectContext:objectContext]); // Remove "_fk" at end
        else
            attributes.push(attributeKey);
    }

    // Add to many relationships
    attributes = [attributes arrayByAddingObjectsFromArray:[objectStore relationshipKeysForObject:anObject]];

    // Here we set this a little early, but we can't do it later as the object will morph to another type after this
    [self setFaultPopulated:YES];

    // Make sure the object context does not record any of these changes. Should not be needed but so we can remove this.
    [objectContext setDoNotObserveValues:YES];

    // Start morph.
    self.isa = anObject.isa;
    self._UID = anObject._UID;

    // If we have a proxy someone is observing this object. Copy over the observing stuff
    var oldProxy = self.$KVOPROXY;
    if (oldProxy) {
        delete self.$KVOPROXY;
        var newProxy = [_CPKVOProxy proxyForObject:self];

        // Move observers to new Proxy
        newProxy._observersForKey = oldProxy._observersForKey;
        newProxy._observersForKeyLength = oldProxy._observersForKeyLength;

        // Move and create replaced keys.
        var replacedKeys = [oldProxy._replacedKeys allObjects];
        for (var i = 0, size = replacedKeys.length; i < size; i++) {
            [newProxy _replaceModifiersForKey:replacedKeys[i]];
        }
    }

    // Do willChange for all attributes in object
    for (var i = 0, size = attributes.length; i < size; i++) {
        [self willChangeValueForKey:attributes[i]];
    }

    // Remove current ivars and copy new ivars from anObject
    copyIvars(self, anObject);

    // Do didChange for all attributes in object
    for (var i = 0, size = attributes.length; i < size; i++) {
        [self didChangeValueForKey:attributes[i]];
    }

    [objectContext setDoNotObserveValues:NO];

    // Return the morphed object.
    return self;
}

@end


var copyIvars = function(anObject, toObject) {
    var ivars = ivarsForClass(anObject.isa);
    for (var i = 0, size = ivars.length; i < size; i++)
        delete ivars[i];

    var ivars = ivarsForClass(toObject.isa);
    for (var i = 0, size = ivars.length; i < size; i++) {
        var key = ivars[i];
        anObject[key] = toObject[key];
    }

    anObject._UID = toObject._UID;
}

var ivarsForClass = function(aClass) {
    var returnIvars = [];

    while(aClass) {
        var ivars = class_copyIvarList(aClass);

        for (var i = 0, size = ivars.length; i < size; i++) {
            returnIvars.push(ivars[i].name);
        }

        aClass = class_getSuperclass(aClass);
    }

    return returnIvars;
}
