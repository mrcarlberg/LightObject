@import "../LightObject.j"

// The log levels are (in order): “fatal”, “error”, “warn”, “info”, “debug”, “trace”
CPLogRegister(CPLogPrint, "warn");

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
//objj_msgSend_decorate(objj_backtrace_decorator);

//FIXME: assert KVO for mapping attributes as well!

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
    return [theObject respondsToSelector:@selector(relationshipKeys)] ? [theObject relationshipKeys] : [];
}


- (CPArray) attributeKeysForObject:(id) theObject {
    return [theObject respondsToSelector:@selector(attributeKeys)] ? [theObject attributeKeys] : [];
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
- (CPArray)attributeKeys { return [@"name"]; }
- (CPArray)relationshipKeys { return ["persons_schools"]; }
- (CPString)loObjectType { return "person"; }
@end


@implementation School : BaseObject {
    CPString name @accessors;
    CPArray persons_schools @accessors;
}
- (CPArray)attributeKeys { return [@"name"]; }
- (CPArray)relationshipKeys { return ["persons_schools"]; }
- (CPString)loObjectType { return "school"; }
@end


@implementation PersonSchoolMapping : BaseObject {
    Person person @accessors;
    School school @accessors;
}
- (CPArray)attributeKeys { return [@"person_fk", @"school_fk"]; }
- (CPString)loObjectType { return "persons_school"; }
@end


@implementation LOObjectContextManyToManyHelpersTest : OJTestCase {
    LOObjectContext     objectContext;
    LOObjectStore       objectStore;
    CPArray             persons;
    CPArray             schools;

    CPArray             notifications;
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
- (Class) classForType:(CPString) aType {
    if (aType == "person") return Person;
    if (aType == "school") return School;
    if (aType == "persons_school") return PersonSchoolMapping;
    return nil;
}

// Delegate method for LOObjectContext
- (void) objectContext:(LOObjectContext)anObjectContext objectsReceived:(CPArray)theObjects withFetchSpecification:aFetchSpecification {
    if (aFetchSpecification.entityName === @"person") {
        persons = theObjects;
    } else if (aFetchSpecification.entityName === @"school") {
        schools = theObjects;
    }
}    

// KVO receiver. Records received KVO callbacks so that we can check them in test cases.
- (void)observeValueForKeyPath:(CPString)theKeyPath ofObject:(id)theObject change:(CPDictionary)theChanges context:(id)theContext {
    var x = [CPDictionary dictionaryWithJSObject:{@"keyPath": theKeyPath, @"object": theObject, @"changes": theChanges}];
    [notifications addObject:x];
}

// Test helper
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

- (void)testInsertUpdatesRelationships {
    var achilles = persons[1];
    var school = schools[0];
    var mapping = [[PersonSchoolMapping alloc] init];
    [mapping setKey:198723]; // fake temp key

    [objectContext insert:mapping withRelationshipWithKey:@"persons_schools" between:achilles and:school];

    [self assertTrue:[[achilles persons_schools] containsObject:mapping] message:@"Achilles should have mapping"];
    [self assertTrue:[[school persons_schools] containsObject:mapping] message:@"School should have mapping"];

    [self assert:3 equals:[[achilles persons_schools] count] message:@"Achilles' schools"];
    [self assert:2 equals:[[school persons_schools] count] message:@"school's persons"];
}

- (void)testInsertCreatesModifyRecord {
    var achilles = persons[1];
    var school = schools[0];
    var mapping = [[PersonSchoolMapping alloc] init];

    [objectContext insert:mapping withRelationshipWithKey:@"persons_schools" between:achilles and:school];

    var record = [[objectContext modifiedObjects] objectAtIndex:0];
    [self assert:mapping equals:[record object]];
    [self assert:1 equals:[[objectContext modifiedObjects] count]];
    [self assertNull:[record deleteDict] message:@"deletion marker"];
    [self assertNotNull:[record insertDict] message:@"insertion marker"];

    var updateDict = [record updateDict];
    [self assertNotNull:updateDict message:@"update dict"];
    [self assert:2 equals:[updateDict objectForKey:@"person_fk"]];
    [self assert:100 equals:[updateDict objectForKey:@"school_fk"]];

    [self assertTrue:[objectContext isObjectRegistered:mapping] message:@"mapping registered"];
}

- (void)testInsertSendsKVONotifications {
    var notifications = [];
    var achilles = persons[1];
    var school = schools[0];
    var mapping = [[PersonSchoolMapping alloc] init];
    [mapping setKey:198723]; // fake temp key

    // trigger faults
    [[achilles persons_schools] count];
    [[school persons_schools] count];

    [achilles addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];
    [school addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];

    [objectContext insert:mapping withRelationshipWithKey:@"persons_schools" between:achilles and:school];

    [achilles removeObserver:self forKeyPath:@"persons_schools"];
    [school removeObserver:self forKeyPath:@"persons_schools"];

    [self assertKVOInsertion:notifications[0] inObject:achilles keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:2]];
    [self assertKVOInsertion:notifications[1] inObject:school keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:1]];
}

- (void)testRevertInsertionRestoresRelationship {
    var achilles = persons[1];
    var school = schools[0];
    var mapping = [[PersonSchoolMapping alloc] init];
    [mapping setKey:198723]; // fake temp key

    [objectContext insert:mapping withRelationshipWithKey:@"persons_schools" between:achilles and:school];
    [objectContext revert];

    [self assertFalse:[[achilles persons_schools] containsObject:mapping] message:@"Achilles shouldn't have mapping"];
    [self assertFalse:[[school persons_schools] containsObject:mapping] message:@"school shouldn't have Achilles mapping"];
}

- (void)testRevertInsertionRestoresObjectContext {
    var achilles = persons[1];
    var school = schools[0];
    var mapping = [[PersonSchoolMapping alloc] init];
    [mapping setKey:198723]; // fake temp key

    [objectContext insert:mapping withRelationshipWithKey:@"persons_schools" between:achilles and:school];
    [objectContext revert];

    [self assertFalse:[objectContext isObjectRegistered:mapping] message:@"mapping shouldn't be registered"];
    [self assertFalse:[objectContext hasChanges] message:@"has changes"];
}

- (void)testRevertInsertionSendsKVONotifications {
    var notifications = [];
    var achilles = persons[1];
    var school = schools[0];
    var mapping = [[PersonSchoolMapping alloc] init];
    [mapping setKey:198723]; // fake temp key

    [objectContext insert:mapping withRelationshipWithKey:@"persons_schools" between:achilles and:school];

    [achilles addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];
    [school   addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];

    [objectContext revert];

    [achilles removeObserver:self forKeyPath:@"persons_schools"];
    [school   removeObserver:self forKeyPath:@"persons_schools"];

    [self assertKVORemoval:notifications[0] fromObject:achilles keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:2] old:[mapping]];
    [self assertKVORemoval:notifications[1] fromObject:school keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:1] old:[mapping]];
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

- (void)testDeleteSendsKVONotifications {
    var notifications = [];
    var person = persons[0];
    var school = schools[0];
    var mapping = [[person persons_schools] objectAtIndex:0];
    [[school persons_schools] count]; // trigger fault

    [person addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];
    [school addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];

    [objectContext delete:mapping withRelationshipWithKey:@"persons_schools" between:person and:school];

    [person removeObserver:self forKeyPath:@"persons_schools"];
    [school removeObserver:self forKeyPath:@"persons_schools"];

    [self assertKVORemoval:notifications[0] fromObject:person keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:0] old:[mapping]];
    [self assertKVORemoval:notifications[1] fromObject:school keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:0] old:[mapping]];
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

    [self assert:0 equals:[[achilles persons_schools] indexOfObjectIdenticalTo:mappingAchillesSparta] message:@"Achilles Sparta index"];
    [self assert:0 equals:[[sparta persons_schools] indexOfObjectIdenticalTo:mappingAchillesSparta] message:@"Sparta Achilles index"];

    [self assert:1 equals:[[penelope persons_schools] indexOfObjectIdenticalTo:mappingPenelopeSparta] message:@"Penelope Sparta index"];
    [self assert:1 equals:[[sparta persons_schools] indexOfObjectIdenticalTo:mappingPenelopeSparta] message:@"Sparta Penelope index"];

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

- (void)testRevertDeletionSendsKVONotifications {
    var notifications = [];
    var penelope = persons[2];
    var sparta = schools[1];
    var mappingPenelopeSparta = [[penelope persons_schools] objectAtIndex:1];
    [[sparta persons_schools] count]; // trigger fault

    [objectContext delete:mappingPenelopeSparta withRelationshipWithKey:@"persons_schools" between:penelope and:sparta];

    [penelope addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];
    [sparta   addObserver:self forKeyPath:@"persons_schools" options:(CPKeyValueObservingOptionNew|CPKeyValueObservingOptionOld) context:nil];

    [objectContext revert];

    [penelope removeObserver:self forKeyPath:@"persons_schools"];
    [sparta removeObserver:self forKeyPath:@"persons_schools"];

    [self assertKVOInsertion:notifications[0] inObject:penelope keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:1]];
    [self assertKVOInsertion:notifications[1] inObject:sparta keyPath:@"persons_schools" indexes:[CPIndexSet indexSetWithIndex:1]];
}

//TODO: think over the index stuff here. I feel we might need a few more tests, to make sure -revert works as expected, especially if we have several consecutive deletions, a mix of deletions and insertions, etc.

- (void)assertKVOInsertion:(id)aKVONotification inObject:(id)expectedObject keyPath:(CPString)expectedKeyPath indexes:(CPIndexSet)expectedIndexes {
    if (!aKVONotification)
        [self fail:@"expected a KVO insertion for key path '" + expectedKeyPath + "' of object " + expectedObject];

    [self assert:expectedObject equals:[aKVONotification objectForKey:@"object"] message:@"object"];
    [self assert:expectedKeyPath equals:[aKVONotification objectForKey:@"keyPath"] message:@"key path"];

    var changes = [aKVONotification objectForKey:@"changes"];
    [self assert:CPKeyValueChangeInsertion equals:[changes objectForKey:CPKeyValueChangeKindKey] message:@"change kind"];
    [self assert:expectedIndexes equals:[changes objectForKey:CPKeyValueChangeIndexesKey] message:@"change indexes"];
}

- (void)assertKVORemoval:(id)aKVONotification fromObject:(id)expectedObject keyPath:(CPString)expectedKeyPath indexes:(CPIndexSet)expectedIndexes old:(id)expectedOldValues {
    if (!aKVONotification)
        [self fail:@"expected a KVO removal for key path '" + expectedKeyPath + "' of object " + expectedObject];

    [self assert:expectedObject equals:[aKVONotification objectForKey:@"object"] message:@"object"];
    [self assert:expectedKeyPath equals:[aKVONotification objectForKey:@"keyPath"] message:@"key path"];

    var changes = [aKVONotification objectForKey:@"changes"];
    [self assert:CPKeyValueChangeRemoval equals:[changes objectForKey:CPKeyValueChangeKindKey] message:@"change kind"];
    [self assert:expectedIndexes equals:[changes objectForKey:CPKeyValueChangeIndexesKey] message:@"change indexes"];
    [self assert:expectedOldValues equals:[changes objectForKey:CPKeyValueChangeOldKey] message:@"change indexes"];
}

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
