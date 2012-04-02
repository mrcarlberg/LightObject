/*
 * LOArrayController.j
 *
 * Created by Martin Carlberg on Feb 27, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>

@implementation LOArrayController : CPArrayController
{
    @outlet LOObjectContext objectContext;
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)insert:(id)sender {
    if (![self canInsert])
        return;
    
    var newObject = [self automaticallyPreparesContent] ? [self newObject] : [self _defaultNewObject];
    [self addObject:newObject];
    // Ok, now we need to tell the object context that we have this new object and it is a new relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var info = [self infoForBinding:@"contentArray"];
    var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
    var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
    var lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
    var bindToObject = [info objectForKey:CPObservedObjectKey];
    var selectedOwnerObjects = [bindToObject selectedObjects];
    var selectedOwnerObjectsSize = [selectedOwnerObjects count];
    for (var i = 0; i < selectedOwnerObjectsSize; i++) {
        var selectedOwnerObject = [selectedOwnerObjects objectAtIndex:i];
        if ([objectContext isObjectRegistered:selectedOwnerObject]) {
            [objectContext _add:newObject toRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
        }
    }
    [objectContext insertObject:newObject]; // Do this last so if autoCommit is on it will trigger saveChanges
}

- (void)remove:(id)sender {
    var selectedObjects = [self selectedObjects];
    [self removeObjectsAtArrangedObjectIndexes:_selectionIndexes];
    // Ok, now we need to tell the object context that we have this removed object and it is a removed relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var selectedObjectsSize = [selectedObjects count];
    for (var i = 0; i < selectedObjectsSize; i ++) {
        var deletedObject = [selectedObjects objectAtIndex:i];
        var info = [self infoForBinding:@"contentArray"];
        var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
        var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
        var lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
        var bindToObject = [info objectForKey:CPObservedObjectKey];
        var selectedOwnerObjects = [bindToObject selectedObjects];
        var selectedOwnerObjectsSize = [selectedOwnerObjects count];
        for (var j = 0; j < selectedOwnerObjectsSize; j++) {
            var selectedOwnerObject = [selectedOwnerObjects objectAtIndex:j];
            if ([objectContext isObjectRegistered:selectedOwnerObject]) {
                [objectContext _delete:deletedObject withRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
            }
        }
    }
    [objectContext deleteObjects: selectedObjects]; // Do this last so if autoCommit is on it will trigger saveChanges
}
/*
- (CPArray) arrangeObjects: (CPArray) objects {
    var testArray = [[_CPKVCArray alloc] init];
    var testArrayCopy = [testArray copy];
    CPLog.trace(@"tracing: arrangeObjects: class = " + [objects class]);
    if ([objects className] === @"_CPKVCArray") {
        debugger;
    }
    var copy = [objects copy];
    CPLog.trace(@"tracing: arrangeObjects: " + [CPString JSONFromObject:copy]);
    [super arrangeObjects:objects];
}
*/
@end