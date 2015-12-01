@import "../LightObject.j"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);

@implementation TestObjectStore : LOLocalDictionaryObjectStore {
}

- (id)init {
    self = [super init];
    if (self) {
        var objects = [
                       [CPMutableDictionary dictionaryWithJSObject:
                        {@"entity": @"person", @"key": 1, @"name": @"Maria", @"age": 9, @"shoeSize": 32, @"dad_fk" : 4, @"mom_fk": 5, @"school_fk" : 100}],
                       [CPMutableDictionary dictionaryWithJSObject:
                        {@"entity": @"person", @"key": 2, @"name": @"Olle", @"age": 3, @"shoeSize": 27, @"dad_fk" : 4, @"mom_fk": 5, @"school_fk" : 100}],
                       [CPMutableDictionary dictionaryWithJSObject:
                        {@"entity": @"person", @"key": 3, @"name": @"Kalle", @"age": 6, @"shoeSize": 31, @"dad_fk" : 4, @"mom_fk": 5, @"school_fk" : 100}],
                       [CPMutableDictionary dictionaryWithJSObject:
                        {@"entity": @"person", @"key": 4, @"name": @"Bertil", @"age": 36, @"shoeSize": 47}],
                       [CPMutableDictionary dictionaryWithJSObject:
                        {@"entity": @"person", @"key": 5, @"name": @"Clara", @"age": 35, @"shoeSize": 38}],
                       [CPMutableDictionary dictionaryWithJSObject:
                        {@"entity": @"school", @"key": 100, @"name": @"First School of Core Programing"}]
                       ];
        for (var i = 0; i < [objects count]; i++) {
            var object = [objects objectAtIndex:i];
            var entity = [self typeOfObject:object];
            var entityArray = [objectFixture objectForKey:entity];
            if (!entityArray) {
                entityArray = [CPMutableArray array];
                [objectFixture setObject:entityArray forKey:entity];
            }
            [entityArray addObject:object];
        }
    }
    return self;
}

/*!
 * Returns a unique id for the object
 */
- (CPString) globalIdForObject:(id) theObject {
    return [theObject objectForKey:@"key"];
}

- (CPArray)relationshipKeysForObject:(id)theObject withType:(CPString)entityName {
    var entity = [self typeOfObject:theObject];
    if (entity === @"school") {
        return [@"persons"];
    }
    return [];
}

- (id) newObjectForType:(CPString)aType objectContext:(LOObjectContext)anObjectContext {
    return [CPMutableDictionary dictionaryWithObject:aType forKey:@"entity"];
}

@end

@implementation LightObjectTest : OJTestCase {
    LOObjectContext     objectContext;
    LOObjectStore       objectStore;
    CPArray             persons;
    CPArray             schools;
}

- (void)setUp
{
    objectContext = [[LOObjectContext alloc] initWithDelegate:self];
    objectStore = [[TestObjectStore alloc] init];
    [objectContext setObjectStore:objectStore];
    [objectContext setAutoCommit:NO];
}

// Delegate method for LOObjectContext
- (void) objectContext:(LOObjectContext)anObjectContext objectsReceived:(CPArray)objects withFetchSpecification:fetchSpecification {
    if (fetchSpecification.entityName === @"person") {
        persons = objects;
    } else if (fetchSpecification.entityName === @"school") {
        schools = objects;
    }
}

- (void)testBasicInitialSetup
{
    [self assertNotNull:objectContext];
    [self assertNotNull:objectStore];
}

- (void)testBasicFetch
{
    var fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:@"person"];
    [objectContext requestObjectsWithFetchSpecification:fetchSpecification];
    [self assert:5 equals:[persons count]];
}

- (void)testQualiferFetch
{
    var fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:@"person" qualifier:[CPPredicate predicateWithFormat:@"age>%@", 8]];
    [objectContext requestObjectsWithFetchSpecification:fetchSpecification];
    [self assert:3 equals:[persons count]];
}

- (void)testModifyAttribute
{
    var fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:@"person" qualifier:[CPPredicate predicateWithFormat:@"name=%@", @"Kalle"]];
    [objectContext requestObjectsWithFetchSpecification:fetchSpecification];
    [self assert:1 equals:[persons count]];
    var kalle = [persons objectAtIndex:0];
    [self assert:6 equals:[kalle objectForKey:@"age"]];
    [self assert:NO equals:[objectContext isObjectModified:kalle]];
    [self assert:NO equals:[objectContext isObjectModified:kalle forAttributeKey:@"age"]];
    [kalle setObject:7 forKey:@"age"];
    [self assert:YES equals:[objectContext isObjectModified:kalle]];
    [self assert:YES equals:[objectContext isObjectModified:kalle forAttributeKey:@"age"]];
    [kalle setObject:@"Kalle Jr" forKey:@"name"];
    [self assert:7 equals:[kalle objectForKey:@"age"]];
    [self assert:@"Kalle Jr" equals:[kalle objectForKey:@"name"]];
    //    print(_cmd + " modifiedObjects = " + [[objectContext modifiedObjects] description]);
    [self assert:1 equals:[[objectContext modifiedObjects] count]];
    [objectContext revert];
    [self assert:6 equals:[kalle objectForKey:@"age"]];
    [self assert:@"Kalle" equals:[kalle objectForKey:@"name"]];
    //    print(_cmd + " modifiedObjects = " + [[[objectContext modifiedObjects] valueForKey:@"updateDict"] description]);
    [self assert:0 equals:[[[objectContext modifiedObjects] valueForKey:@"updateDict"] count]];
}

- (void)testInsertDeleteObject
{
    var fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:@"person" qualifier:[CPPredicate predicateWithFormat:@"name=%@", @"Kalle"]];
    [objectContext requestObjectsWithFetchSpecification:fetchSpecification];
    [self assert:1 equals:[persons count]];
    var mrPresident = [CPMutableDictionary dictionaryWithJSObject:
                       {@"entity": @"person", @"key": 199, @"name": @"Barack", @"age": 50, @"shoeSize": 43}];
    [objectContext insertObject:mrPresident];
    [self assert:1 equals:[[objectContext modifiedObjects] count]];
    [objectContext revert];
    [self assert:0 equals:[[objectContext modifiedObjects] count]];
    var kalle = [persons objectAtIndex:0];
    [objectContext deleteObject:kalle];
    [self assert:1 equals:[[objectContext modifiedObjects] count]];
    [objectContext revert];
    [self assert:0 equals:[[objectContext modifiedObjects] count]];
}

- (void)testToManyRelationshipArrayFault
{
    var fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:@"school"];
    [objectContext requestObjectsWithFetchSpecification:fetchSpecification];

    // We don't have an intelligent ObjectStore that will handle to many relationships. Lets fake and add a fault attribute for each school object.

    for (var i = 0; i < [schools count]; i++) {
        var school = [schools objectAtIndex:i];
        // Add fault. The person entity has already attribute school_fk that is pointing to the school.
        // The fault will, when accessed, fetch for the persons and replace it to the attribute persons on each school object.
        var fault = [[LOFaultArray alloc] initWithObjectContext:objectContext masterObject:school relationshipKey:@"persons"];
        [school setObject:fault forKey:@"persons"];
    }
    [self assert:1 equals:[schools count]];
    var school = [schools objectAtIndex:0];
    // trigger the fault
    var schoolPersons = [school objectForKey:@"persons"];
    [self assert:3 equals:[schoolPersons count]];
}

/*
- (void)testBindsTableViewContentToArrayController
{
    [listView setObjects:peopleController];
    [self assert:tableView bound:@"content" toObject:peopleController withKeyPath:@"arrangedObjects"];
}

- (void)testDoesntCreateColumnsWithoutSpecs
{
    [listView setObjects:peopleController];
    [self assert:0 equals:[tableView numberOfColumns]];
}

- (void)testDoesntCreateColumnsWithoutObjects
{
    [listView setColumnSpecifications:peopleColumnSpecifications];
    [self assert:0 equals:[tableView numberOfColumns]];
}

- (void)testAddsColumnWhenSettingSpecAfterObjects
{
    [listView setObjects:peopleController];
    [listView setColumnSpecifications: [{@"identifier": @"name"}] ];
    [self assertNotNull:[tableView tableColumnWithIdentifier:@"name"]];
    [self assert:1 equals:[tableView numberOfColumns]];
}

- (void)testAddsColumnWhenSettingObjectsAfterSpec
{
    [listView setColumnSpecifications: [{@"identifier": @"name"}] ];
    [listView setObjects:peopleController];
    [self assertNotNull:[tableView tableColumnWithIdentifier:@"name"]];
    [self assert:1 equals:[tableView numberOfColumns]];
}

- (void)testEnforcesUniqueColumnIdentifiers
{
    var f = function() {
        [listView setColumnSpecifications:[{@"identifier": @"duplicateId"}, {@"identifier": @"duplicateId" }]];
    }
    [self assertThrows:f name:CPInvalidArgumentException reason:@"Duplicate column identifier duplicateId"];
}

- (void)testOptionallySetsColumnTitle
{
    [listView setColumnSpecifications:peopleColumnSpecifications];
    [listView setObjects:peopleController];

    var column = [tableView tableColumnWithIdentifier:@"age"];
    [self assert:@"Ålder" equals:[[column headerView] stringValue]];
}

- (void)testOptionallySetsMinWidth
{
    [listView setColumnSpecifications: [{@"identifier": @"name", @"minWidth": 33.3}] ];
    [listView setObjects:peopleController];

    var column = [[tableView tableColumns] objectAtIndex:0];
    [self assert:33.3 equals:[column minWidth]];
}

- (void)testOptionallyBindsColumns {
    [listView setColumnSpecifications: [{@"identifier": @"name", @"attribute": @"name" }] ];
    [listView setObjects:peopleController];

    var column = [tableView tableColumnWithIdentifier:@"name"];
    [self assert:column bound:@"value" toObject:peopleController withKeyPath:@"arrangedObjects.name"];
}

- (void)testTableViewAndColumnBindingsOnSettingObjects
{
    [listView setColumnSpecifications: [{@"identifier": @"name", @"attribute": @"name" }] ];
    [listView setObjects:peopleController];
    var originalColumn = [tableView tableColumnWithIdentifier:@"name"];

    var newController = [[CPArrayController alloc] init];
    [listView setObjects:newController];

    // note: this test relies on the fact that we recreate the table columns on resetting the array controller.
    [self assert:originalColumn notBound:@"value"];

    var column = [tableView tableColumnWithIdentifier:@"name"];
    [self assert:tableView bound:@"content" toObject:newController withKeyPath:@"arrangedObjects"];
    [self assert:column bound:@"value" toObject:newController withKeyPath:@"arrangedObjects.name"];
}

- (void)testTableViewAndColumnBindingsOnSettingSpecs
{
    [listView setColumnSpecifications: [{@"identifier": @"name", @"attribute": @"name" }] ];
    [listView setObjects:peopleController];
    var originalColumn = [tableView tableColumnWithIdentifier:@"name"];

    [listView setColumnSpecifications: [{@"identifier": @"name", @"attribute": @"name" }] ];

    // note: this test relies on the fact that we recreate the table columns on resetting the array controller.
    [self assert:originalColumn notBound:@"value"];

    var column = [tableView tableColumnWithIdentifier:@"name"];
    [self assert:tableView bound:@"content" toObject:peopleController withKeyPath:@"arrangedObjects"];
    [self assert:column bound:@"value" toObject:peopleController withKeyPath:@"arrangedObjects.name"];
}

- (void)testUnsetObjects
{
    [listView setColumnSpecifications: [{@"identifier": @"name", @"attribute": @"name" }] ];
    [listView setObjects:peopleController];
    var originalColumn = [tableView tableColumnWithIdentifier:@"name"];
    [listView setObjects:nil];
    [self assert:tableView notBound:@"content"];
    [self assert:originalColumn notBound:@"value"];
    // note: we should be able to test for this, but there's an issue with column removals being delayed.
    // see FIXME comment in [BOPListView -unbindAndRemoveTableViewColumns]. Instead, we make sure the
    // column is really scheduled for removal.
    //[self assert:0 equals:[[tableView tableColumns] count]];
    [self assertNull:[originalColumn tableView]];
}

- (void)testUnsetSpecs
{
    [listView setColumnSpecifications: [{@"identifier": @"name", @"attribute": @"name" }] ];
    [listView setObjects:peopleController];
    var originalColumn = [tableView tableColumnWithIdentifier:@"name"];
    [listView setColumnSpecifications:nil];
    [self assert:tableView bound:@"content" toObject:peopleController withKeyPath:@"arrangedObjects"];
    [self assert:originalColumn notBound:@"value"];
    // note: we should be able to test for this, but there's an issue with column removals being delayed.
    // see FIXME comment in [BOPListView -unbindAndRemoveTableViewColumns]. Instead, we make sure the
    // column is really scheduled for removal.
    //[self assert:0 equals:[[tableView tableColumns] count]];
    [self assertNull:[originalColumn tableView]];
}
*/
- (void)assert:(id)anObject notBound:(CPString)aBinding
{
    //TODO: move to category
    var bindingInfo = [anObject infoForBinding:aBinding];
    if (!bindingInfo) return;
    [self fail:@"expected no binding '" + aBinding + "' but found " + bindingInfo];
}

- (void)assert:(id)anObject bound:(CPString)aBinding toObject:(id)expectedObservedObject withKeyPath:(CPString)expectedObservedKeyPath
{
    //TODO: move to category
    var bindingInfo = [anObject infoForBinding:aBinding];
    [self assertNotNull:bindingInfo message:@"expected binding '" + aBinding + "' of " + anObject + " to " + expectedObservedObject];
    [self assert:expectedObservedKeyPath equals:[bindingInfo objectForKey:CPObservedKeyPathKey]];
    [self assert:expectedObservedObject same:[bindingInfo objectForKey:CPObservedObjectKey]];
}

- (void)assertThrows:(Function)zeroArgClosure name:(CPString)expectedName reason:(CPString)expectedReason
{
    //TODO: move to category
    var expected = nil;
    try {
        zeroArgClosure();
    } catch (anException) {
        expected = anException;
    }
    if (!expected) [self fail:@"didn't throw " + expectedName];
    [self assert:expectedName equals:[expected name]];
    [self assert:expectedReason equals:[expected reason]];
}

@end
