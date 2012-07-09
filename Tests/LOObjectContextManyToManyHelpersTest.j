@import "../LightObject.j"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);

//FIXME: make sure we issue KVO notifications before changing the many-to-many properties.

@implementation TestObjectStore : LOLocalDictionaryObjectStore {
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)addFixtureObject:(id)aJSObject {
    var object = [CPMutableDictionary dictionaryWithJSObject:aJSObject];
    var entity = [self typeOfObject:object];
    var entityArray = [[self objectFixture] objectForKey:entity];
    if (!entityArray) {
        entityArray = [CPMutableArray array];
        [[self objectFixture] setObject:entityArray forKey:entity];
    }
    [entityArray addObject:object];
}

- (void)addFakeArrayFaultsForObjects:(CPArray)theObjects inObjectContext:(LOObjectContext)aContext {
    for (var i=0; i<theObjects.length; i++) {
        var object = theObjects[i];
        var relationshipKeys = [self relationshipKeysForObject:object];
        for (var j=0; j<relationshipKeys.length; j++) {
            var relationshipKey = relationshipKeys[j];
            var fault = [[LOFaultArray alloc] initWithObjectContext:aContext masterObject:object relationshipKey:relationshipKey];
            [object setValue:fault forKey:relationshipKey];
        }
    }
}

/*!
 * Returns a unique id for the object.
 * Overridden to use the property "key" instead of the default object UID
 * so that we can control object IDs in the tests.
 */
- (CPString)globalIdForObject:(id) theObject {
    return [theObject valueForKey:@"key"];
}

- (CPString) typeOfObject:(id) theObject {
    if ([theObject isKindOfClass:[CPDictionary class]])
        return [theObject valueForKey:@"entity"];
    return [theObject loObjectType];
}

- (CPArray)relationshipKeysForObject:(id)theObject {
    var theObjectClass = [theObject class];
    if ([theObjectClass respondsToSelector:@"relationshipKeys"]) {
        return [theObjectClass relationshipKeys];
    }
    return [];
}

- (CPArray) attributeKeysForObject:(id) theObject {
    var theObjectClass = [theObject class];
    if ([theObjectClass respondsToSelector:@"attributeKeys"]) {
        return [theObjectClass attributeKeys];
    }
    return [];
}

@end


@implementation BaseObject : CPObject {
    id key @accessors;
}
@end


@implementation Person : BaseObject {
    CPString name @accessors;
    CPArray persons_schools @accessors;
}
+ (CPArray)attributeKeys { return [@"name"]; }
+ (CPArray)relationshipKeys { return ["persons_schools"]; }
- (CPString)loObjectType { return "person"; }
@end


@implementation School : BaseObject {
    CPString name @accessors;
    CPArray persons_schools @accessors;
}
+ (CPArray)attributeKeys { return [@"name"]; }
+ (CPArray)relationshipKeys { return ["persons_schools"]; }
- (CPString)loObjectType { return "school"; }
@end


@implementation PersonSchoolMapping : BaseObject {
    Person person @accessors;
    School school @accessors;
}
+ (CPArray)attributeKeys { return [@"person_fk", @"school_fk"]; }
- (CPString)loObjectType { return "persons_school"; }
@end


@implementation LOObjectContextManyToManyHelpersTest : OJTestCase {
    LOObjectContext     objectContext;
    LOObjectStore       objectStore;
    CPArray             persons;
    CPArray             schools;
}

- (void)setUp()
{
    persons = nil;
    schools = nil;

    objectStore = [[TestObjectStore alloc] init];

    objectContext = [[LOObjectContext alloc] initWithDelegate:self];
    [objectContext setObjectStore:objectStore];
    [objectContext setAutoCommit:NO];

    [objectStore addFixtureObject:{@"entity": @"person", @"key": 1, @"name": @"Hector"}];
    [objectStore addFixtureObject:{@"entity": @"school", @"key": 100, @"name": @"School 1"}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 1000, @"person_fk": 1, @"school_fk": 100}];

    [objectStore addFixtureObject:{@"entity": @"person", @"key": 2, @"name": @"Achilles"}];
    [objectStore addFixtureObject:{@"entity": @"person", @"key": 3, @"name": @"Penelope"}];
    [objectStore addFixtureObject:{@"entity": @"school", @"key": 200, @"name": @"University of Sparta"}];
    [objectStore addFixtureObject:{@"entity": @"school", @"key": 300, @"name": @"Troy Public School"}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 2000, @"person_fk": 2, @"school_fk": 200}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 2001, @"person_fk": 2, @"school_fk": 300}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 3000, @"person_fk": 3, @"school_fk": 300}];
    [objectStore addFixtureObject:{@"entity": @"persons_school", @"key": 3001, @"person_fk": 3, @"school_fk": 200}];

    [self requestAllObjectsForEntity:@"person"];
    [self requestAllObjectsForEntity:@"school"];
    [objectStore addFakeArrayFaultsForObjects:persons inObjectContext:objectContext];
    [objectStore addFakeArrayFaultsForObjects:schools inObjectContext:objectContext];
}

// Delegate method for LOObjectContext
- (id) newObjectForType:(CPString) aType {
    if (aType == "person") return [[Person alloc] init];
    if (aType == "school") return [[School alloc] init];
    if (aType == "persons_school") return [[PersonSchoolMapping alloc] init];
    return nil;
}

// Delegate method for LOObjectContext
- (void) objectsReceived:(CPArray)theObjects forObjectContext:(LOObjectContext)anObjectContext withFetchSpecification:aFetchSpecification {
    if (aFetchSpecification.entityName === @"person") {
        persons = theObjects;
    } else if (aFetchSpecification.entityName === @"school") {
        schools = theObjects;
    }
}    

- (void)requestAllObjectsForEntity:(CPString)anEntity {
    var fs = [LOFetchSpecification fetchSpecificationForEntityNamed:anEntity];
    [objectContext requestObjectsWithFetchSpecification:fs];
}

- (void)testFaultingManyToManyWorks {
    [self assert:3 equals:[persons count] message:@"persons"];
    [self assert:3 equals:[schools count] message:@"schools"];
    // trigger faults
    var person = persons[0];
    var school = schools[0];
    [self assert:1 equals:[[person persons_schools] count] message:@"person's schools"];
    [self assert:1 equals:[[school persons_schools] count] message:@"school's persons"];
    var mapping1 = [[person persons_schools] objectAtIndex:0];
    var mapping2 = [[school persons_schools] objectAtIndex:0];
    [self assert:mapping1 equals:mapping2];
    [self assert:@"PersonSchoolMapping" equals:[mapping1 className]];
    //[self assert:@"persons_school" equals:[mapping1 objectForKey:@"entity"]];
    [self assert:person equals:[mapping1 person]];
    [self assert:school equals:[mapping1 school]];
}

- (void)testDeleteUpdatesRelationships {
    var person = persons[0];
    var school = schools[0];
    var mapping = [[person persons_schools] objectAtIndex:0];

    [objectContext delete:mapping withRelationshipWithKey:@"persons_schools" between:person and:school];

    [self assert:[] equals:[person persons_schools] message:@"person's schools"];
    [self assert:[] equals:[school persons_schools] message:@"school's persons"];
}

- (void)testDeleteCreatesModifyRecord {
    var person = persons[0];
    var school = schools[0];
    var mapping = [[person persons_schools] objectAtIndex:0];

    [objectContext delete:mapping withRelationshipWithKey:@"persons_schools" between:person and:school];

    var record = [[objectContext modifiedObjects] objectAtIndex:0];
    [self assert:mapping equals:[record object]];
    [self assert:1 equals:[[objectContext modifiedObjects] count]];
    [self assertNotNull:[record deleteDict] message:@"deletion marker"];
    [self assertNull:[record updateDict] message:@"update dict"];
    [self assertNull:[record insertDict] message:@"insert dict"];
    [self assertFalse:[objectContext isObjectRegistered:mapping] message:@"mapping registered"];
}

- (void)testRevertDeletionSetup {
    // achilles => sparta, troy
    // penelope => troy, sparta
    var achilles = persons[1];
    var penelope = persons[2];
    [self assert:@"Achilles" equals:[achilles name]];
    [self assert:@"Penelope" equals:[penelope name]];

    var sparta = schools[1];
    var troy   = schools[2];
    [self assert:@"University of Sparta" equals:[sparta name]];
    [self assert:@"Troy Public School" equals:[troy name]];

    var mappingAchillesSparta = [[achilles persons_schools] objectAtIndex:0];
    var mappingPenelopeSparta = [[penelope persons_schools] objectAtIndex:1];
    [self assertNotNull:mappingAchillesSparta];
    [self assertNotNull:mappingPenelopeSparta];
    [self assert:achilles equals:[mappingAchillesSparta person]];
    [self assert:sparta equals:[mappingAchillesSparta school]];
    [self assert:penelope equals:[mappingPenelopeSparta person]];
    [self assert:sparta equals:[mappingPenelopeSparta school]];
}

// TODO: To make the setup more explicit for each test, split -setUp so that we can modify the fixture sligthly before each test.

- (void)testRevertDeletionRestoresRelationship {
    var achilles = persons[1];
    var sparta = schools[1];
    var mappingAchillesSparta = [[achilles persons_schools] objectAtIndex:0];

    [objectContext delete:mappingAchillesSparta withRelationshipWithKey:@"persons_schools" between:achilles and:sparta];
    [objectContext revert];

    [self assertTrue:[[achilles persons_schools] containsObject:mappingAchillesSparta] message:@"Achilles has mapping"];
    [self assertTrue:[[sparta persons_schools] containsObject:mappingAchillesSparta] message:@"school has Achilles mapping"];
}

- (void)testRevertDeletionRestoresObjectContext {
    var achilles = persons[1];
    var sparta = schools[1];
    var mappingAchillesSparta = [[achilles persons_schools] objectAtIndex:0];

    [objectContext delete:mappingAchillesSparta withRelationshipWithKey:@"persons_schools" between:achilles and:sparta];
    [objectContext revert];

    [self assertTrue:[objectContext isObjectRegistered:mappingAchillesSparta] message:@"Achilles mapping registered"];
    [self assertFalse:[objectContext hasChanges] message:@"has changes"];
}

- (void)testRevertDeletionRemembersIndexes {
    var achilles = persons[1];
    var penelope = persons[2];
    var sparta = schools[1];
    var troy   = schools[2];
    var mappingAchillesSparta = [[achilles persons_schools] objectAtIndex:0];
    var mappingPenelopeSparta = [[penelope persons_schools] objectAtIndex:1];

    [objectContext delete:mappingAchillesSparta withRelationshipWithKey:@"persons_schools" between:achilles and:sparta];
    [objectContext delete:mappingPenelopeSparta withRelationshipWithKey:@"persons_schools" between:penelope and:sparta];
    [objectContext revert];

    [self assert:0 equals:[[achilles persons_schools] indexOfObject:mappingAchillesSparta] message:@"achilles sparta"];
    [self assert:1 equals:[[penelope persons_schools] indexOfObject:mappingPenelopeSparta] message:@"penelope sparta"];
    [self assert:0 equals:[[sparta persons_schools] indexOfObject:mappingAchillesSparta] message:@"sparta achilles"];
    [self assert:1 equals:[[sparta persons_schools] indexOfObject:mappingPenelopeSparta] message:@"sparta penelope"];
}

//TODO: think over the index stuff here. I feel we might need a few more tests, to make sure -revert works as expected, especially if we have several consecutive deletions, a mix of deletions and insertions, etc.

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
