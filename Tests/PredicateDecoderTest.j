@import "../LOJSONFormatSupport.j"
@import "OJTestCase+LOAdditions.j"

// Uncomment the following line to enable backtraces.
// Very useful sometimes, but don't enable always because
// all exceptions are traced, even when handled.
// objj_msgSend_decorate(objj_backtrace_decorator);

@implementation PredicateDecoderTest : OJTestCase {
}

- (void)testKeyPathExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "keyPath", "value": "some.path"}];
    [self assert:CPKeyPathExpressionType equals:[expr expressionType]];
    [self assert:@"some.path" equals:[expr keyPath]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "keyPath", "value": 123.0}];
    [self assert:CPKeyPathExpressionType equals:[expr expressionType]];
    [self assert:@"123" equals:[expr keyPath]];
}

- (void)testKeyPathExpressionThrowsOnNothing {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "keyPath", "value": null}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'keyPath'. Value must not be null"];
    f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "keyPath", "value": ""}]; }
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'keyPath'. Value must not be empty"];
}

- (void)testNilConstantValueExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "null", "value": null}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:nil equals:[expr constantValue]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "null", "value": "xyz"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:@"convert to nil"];
    [self assert:nil equals:[expr constantValue] message:@"convert to nil"];
}

- (void)testStringConstantValueExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "string", "value": "some string"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:@"some string" equals:[expr constantValue]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "string", "value": 5533.0}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:@"convert to string"];
    [self assert:@"5533" equals:[expr constantValue] message:@"convert to string"];
}

- (void)testStringConstantValueExpressionThrowsOnNull {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "string", "value": null}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'string'. Value must not be null"];
}

- (void)testStringConstantValueExpressionWithEmpty {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "string", "value": ""}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:@"" equals:[expr constantValue]];
}

- (void)testNumberConstantValueExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "number", "value": 3.14}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:3.14 equals:[expr constantValue]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "number", "value": "2.71"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:"convert to number"];
    [self assert:2.71 equals:[expr constantValue] message:"convert to number"];
}

- (void)testNumberConstantValueExpressionWithZero {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "number", "value": 0}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:0 equals:[expr constantValue]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "number", "value": "0"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:"convert to number"];
    [self assert:0 equals:[expr constantValue] message:"convert to number"];
}

- (void)testNumberConstantValueExpressionMustBeValidNumber {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "number", "value": "this is not a number"}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'number'. Value must be a valid number: 'NaN'"];
    f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "number", "value": null}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'number'. Value must be a valid number: 'null'"];
}

- (void)testBooleanConstantValueExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "bool", "value": true}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:true equals:[expr constantValue]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "bool", "value": "true"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:"convert to boolean"];
    [self assert:true equals:[expr constantValue] message:"convert to boolean"];
}

- (void)testBooleanConstantValueExpressionWithFalse {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "bool", "value": false}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:false equals:[expr constantValue]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "bool", "value": "false"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:"convert to boolean"];
    [self assert:false equals:[expr constantValue] message:"convert to boolean"];
}

- (void)testBooleanConstantValueExpressionMustBeValidNumber {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "bool", "value": "this is not a boolean"}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'bool'. Value must be a valid boolean: 'this is not a boolean'"];
    f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "bool", "value": null}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'bool'. Value must be a valid boolean: 'null'"];
}

- (void)testDateConstantValueExpressionMustBeValidNumber {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "datetime", "value": "this is not a number"}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'datetime'. Value must be a valid number: 'NaN'"];
    f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "datetime", "value": null}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'datetime'. Value must be a valid number: 'null'"];
}

- (void)testDateConstantValueExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "datetime", "value": 1234.0}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:[expr constantValue] equals:[CPDate dateWithTimeIntervalSinceReferenceDate:1234.0]];

    var expr = [CPExpression expressionFromLOJSONFormat:{"type": "datetime", "value": "1234.0"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:@"convert to number"];
    [self assert:[expr constantValue] equals:[CPDate dateWithTimeIntervalSinceReferenceDate:1234.0] message:@"convert to number"];
}

- (void)testNullConstantValueExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{type: "null", value: null}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType]];
    [self assert:[expr constantValue] equals:nil];

    var expr = [CPExpression expressionFromLOJSONFormat:{type: "null", value: "null"}];
    [self assert:CPConstantValueExpressionType equals:[expr expressionType] message:@"convert to null"];
    [self assert:[expr constantValue] equals:nil message:@"convert to null"];
}

- (void)testAggregateExpression {
    var expr = [CPExpression expressionFromLOJSONFormat:{type: @"array", value: [ { type:@"string", value:@"str"}]}];
    [self assert:[expr expressionType] equals:CPAggregateExpressionType];
    var value = [expr collection];
    [self assertTrue:[value isKindOfClass:[CPArray class]] message:@"value is of class " + CPStringFromClass([value class])];
    [self assert:[value count] equals:1];

    var subexpr = value[0];
    [self assert:[subexpr expressionType] equals:CPConstantValueExpressionType];
    [self assert:[subexpr constantValue] equals:@"str"];
}

- (void)testAggregateExpressionMustBeArray {
    var f = function() { [CPExpression expressionFromLOJSONFormat:{type: @"array", value: @"this is not an array"}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'array'. Value must be an array: 'this is not an array'"];
}

- (void)testAggregateExpressionThrowsOnInvalidSubexpression {
    var f = function() {
        [CPExpression expressionFromLOJSONFormat:{type: @"array", value: [@"this is not a valid value"] }];
    };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type 'array'. Invalid sub-value: Expression format missing type and value"];
}

- (void)testExpressionThrowsOnMissingValue {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "keyPath", "value": undefined}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Expression format missing value"];
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "keyPath"}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Expression format missing value"];
}

- (void)testExpressionThrowsOnMissingType {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"value": "abc"}]; };
    [self assertThrows:f name:LOJSONInvalidExpressionValueException reason:@"Expression format missing type"];
}

- (void)testExpressionThrowsOnUnsupportedType {
    var f = function (x) { [CPExpression expressionFromLOJSONFormat:{"type": "not supported", "value": "abc"}]; };
    [self assertThrows:f name:LOJSONUnsupportedExpressionTypeException reason:@"Unsupported expression type 'not supported'"];
}

- (void)testComparisonPredicate {
    var pred = [CPPredicate predicateFromLOJSONFormat:{"o": "==", "l": "k", "r": "s", "lt": "keyPath", "rt": "string"}];
    [self assert:[CPComparisonPredicate class] equals:[pred class]];

    [self assert:CPEqualToPredicateOperatorType equals:[pred predicateOperatorType]];
    [self assertKeyPathExpression:[pred leftExpression] equals:@"k"];
    [self assertConstantValueExpression:[pred rightExpression] equals:@"s"];
}

- (void)testComparisonPredicateWithCaseInsensitiveLike {
    var pred = [CPPredicate predicateFromLOJSONFormat:{"o": "like", "l": "k", "r": "s", "lt": "keyPath", "rt": "string", "c": true}];
    [self assert:[CPComparisonPredicate class] equals:[pred class]];

    [self assert:CPLikePredicateOperatorType equals:[pred predicateOperatorType]];
    [self assert:CPCaseInsensitivePredicateOption equals:[pred options]];
    [self assertKeyPathExpression:[pred leftExpression] equals:@"k"];
    [self assertConstantValueExpression:[pred rightExpression] equals:@"s"];
}

- (void)testComparisonPredicateWithConstantValueInKeyPath {
    var pred = [CPComparisonPredicate predicateFromLOJSONFormat:{o: "in", l: "v", r: "k", lt: "string", rt: "keyPath"}];
    [self assert:[CPComparisonPredicate class] equals:[pred class]];

    [self assert:CPInPredicateOperatorType equals:[pred predicateOperatorType]];
    [self assertConstantValueExpression:[pred leftExpression] equals:@"v"];
    [self assertKeyPathExpression:[pred rightExpression] equals:@"k"];
}

- (void)testComparisonPredicateWithKeyPathInConstantValues {
    var json = {o: "in", l: "k", r: [ {type:"number", value:1},{type:"number", value:2} ], lt: "keyPath", rt: "array"};
    var pred = [CPComparisonPredicate predicateFromLOJSONFormat:json];
    [self assert:[CPComparisonPredicate class] equals:[pred class]];

    [self assert:CPInPredicateOperatorType equals:[pred predicateOperatorType]];
    [self assertKeyPathExpression:[pred leftExpression] equals:@"k"];

    var right = [pred rightExpression];
    [self assert:CPAggregateExpressionType equals:[right expressionType] message:@"aggregate type"];

    var collection = [right collection];
    [self assert:2 equals:[collection count]];
    [self assertConstantValueExpression:collection[0] equals:1];
    [self assertConstantValueExpression:collection[1] equals:2];
}

- (void)testComparisonPredicateWithKeyPathBetweenConstantValues {
    var json = {o: "between", l: "k", r: [ {type:"number", value:1},{type:"number", value:2} ], lt: "keyPath", rt: "array"};
    var pred = [CPComparisonPredicate predicateFromLOJSONFormat:json];
    [self assert:[CPComparisonPredicate class] equals:[pred class]];

    [self assert:CPBetweenPredicateOperatorType equals:[pred predicateOperatorType]];
    [self assertKeyPathExpression:[pred leftExpression] equals:@"k"];

    var right = [pred rightExpression];
    [self assert:CPAggregateExpressionType equals:[right expressionType] message:@"aggregate type"];

    var collection = [right collection];
    [self assert:2 equals:[collection count]];
    [self assertConstantValueExpression:collection[0] equals:1];
    [self assertConstantValueExpression:collection[1] equals:2];
}

- (void)testComparisonPredicateSupportedOperators {
    var operatorTypeMap = [
        ["==", CPEqualToPredicateOperatorType],
        ["!=", CPNotEqualToPredicateOperatorType],
        ["<", CPLessThanPredicateOperatorType],
        [">", CPGreaterThanPredicateOperatorType],
        ["<=", CPLessThanOrEqualToPredicateOperatorType],
        [">=", CPGreaterThanOrEqualToPredicateOperatorType],
        ["like", CPLikePredicateOperatorType],
        ["in", CPInPredicateOperatorType],
        ["between", CPBetweenPredicateOperatorType],
    ];
    for (var i=0; i < operatorTypeMap.length; i++) {
        var operatorString = operatorTypeMap[i][0];
        var operatorType = operatorTypeMap[i][1];
        var json = {"o": operatorString, "l": "k", "r": "s", "lt": "keyPath", "rt": "string"};
        var pred = [CPComparisonPredicate predicateFromLOJSONFormat:json];
        [self assert:operatorType equals:[pred predicateOperatorType] message:@"operator '" + operatorString + "'"];
    }
}

- (void)testComparisonPredicateThrowsOnUnsupportedOperator {
    var f = function() {
        [CPComparisonPredicate predicateFromLOJSONFormat:{"o": "not an operator"}];
    };
    [self assertThrows:f name:LOJSONUnsupportedPredicateOperatorException reason:@"Unsupported predicate operator 'not an operator'"];
}

- (void)testCompoundPredicate {
    var json = {"o": "and", "p": [{"o": "==", "l": "k", "r": "s", "lt": "keyPath", "rt": "string"},{"o": "!=", "l": "l", "r": "t", "lt": "keyPath", "rt": "string"}]};
    var pred = [CPCompoundPredicate predicateFromLOJSONFormat:json];
    [self assert:CPAndPredicateType equals:[pred compoundPredicateType] message:@"and"];
    [self assert:2 equals:[[pred subpredicates] count]];
    [self assert:CPEqualToPredicateOperatorType equals:[[[pred subpredicates] objectAtIndex:0] predicateOperatorType]]
    [self assert:CPNotEqualToPredicateOperatorType equals:[[[pred subpredicates] objectAtIndex:1] predicateOperatorType]]
}

- (void)testCompoundPredicateSupportedOperators {
    var operatorTypeMap = [
        ["and", CPAndPredicateType],
        ["or", CPOrPredicateType],
        ["not", CPNotPredicateType],
    ];
    for (var i=0; i < operatorTypeMap.length; i++) {
        var operatorString = operatorTypeMap[i][0];
        var operatorType = operatorTypeMap[i][1];
        var json = {"o": operatorString, "p": [{"o": "==", "l": "k", "r": "s", "lt": "keyPath", "rt": "string"},{"o": "!=", "l": "l", "r": "t", "lt": "keyPath", "rt": "string"}]};
        var pred = [CPCompoundPredicate predicateFromLOJSONFormat:json];
        [self assert:operatorType equals:[pred compoundPredicateType] message:@"operator '" + operatorString + "'"];
    }
}

- (void)testCompoundPredicateThrowsOnUnsupportedOperator {
    var f = function() {
        [CPCompoundPredicate predicateFromLOJSONFormat:{"o": "not an operator"}];
    };
    [self assertThrows:f name:LOJSONUnsupportedPredicateOperatorException reason:@"Unsupported predicate operator 'not an operator'"];
}

- (void)testCompoundPredicateWithSeveralSubpredicates {
    var json = {"o": "and", "p": [
        {"o": "==", "l": "x", "r": "r", "lt": "keyPath", "rt": "string"},
        {"o": "!=", "l": "y", "r": "s", "lt": "keyPath", "rt": "string"},
        {"o": "<=", "l": "z", "r": "t", "lt": "keyPath", "rt": "string"}
    ]};
    var pred = [CPCompoundPredicate predicateFromLOJSONFormat:json];
    [self assert:CPAndPredicateType equals:[pred compoundPredicateType] message:@"and"];
    [self assert:3 equals:[[pred subpredicates] count]];
    [self assert:CPEqualToPredicateOperatorType equals:[[[pred subpredicates] objectAtIndex:0] predicateOperatorType] message:@"first"];
    [self assert:CPNotEqualToPredicateOperatorType equals:[[[pred subpredicates] objectAtIndex:1] predicateOperatorType] message:@"second"];
    [self assert:CPLessThanOrEqualToPredicateOperatorType equals:[[[pred subpredicates] objectAtIndex:2] predicateOperatorType] message:@"third"];
}

- (void)testNestedPredicates {
    var json = {
        "o": "and",
        "p": [
            {"o": "==", "l": "x", "r": "a", "lt": "keyPath", "rt": "string"},
            {
                "o": "or",
                "p": [
                    {"o": "!=", "l": "y", "r": "b", "lt": "keyPath", "rt": "string"},
                    {
                        "o": "and",
                        "p": [
                            {
                                "o": "not",
                                "p": [
                                    {"o": "<", "l": "z", "r": "c", "lt": "keyPath", "rt": "string"},
                                ]
                            },
                            {"o": ">", "l": "z", "r": "d", "lt": "keyPath", "rt": "string"},
                        ]
                    }
                ]
            }
        ]
    };
    var topLevel = [CPPredicate predicateFromLOJSONFormat:json];
    [self assert:CPAndPredicateType equals:[topLevel compoundPredicateType] message:@"top level"];
    [self assert:2 equals:[[topLevel subpredicates] count]];
    [self assert:CPEqualToPredicateOperatorType equals:[[topLevel subpredicates][0] predicateOperatorType] message:@"top level left"];

    var secondLevel = [topLevel subpredicates][1];
    [self assert:CPOrPredicateType equals:[secondLevel compoundPredicateType] message:@"second level 'or'"];
    [self assert:2 equals:[[secondLevel subpredicates] count]];
    [self assert:CPNotEqualToPredicateOperatorType equals:[[secondLevel subpredicates][0] predicateOperatorType] message:@"second level left"];

    var thirdLevel = [secondLevel subpredicates][1];
    [self assert:CPAndPredicateType equals:[thirdLevel compoundPredicateType] message:@"third level 'and'"];
    [self assert:2 equals:[[thirdLevel subpredicates] count]];
    [self assert:CPGreaterThanPredicateOperatorType equals:[[thirdLevel subpredicates][1] predicateOperatorType] message:@"third level right"];

    var fourthLevel = [thirdLevel subpredicates][0];
    [self assert:CPNotPredicateType equals:[fourthLevel compoundPredicateType] message:@"fourth level 'not'"];
    [self assert:1 equals:[[fourthLevel subpredicates] count]];
    [self assert:CPLessThanPredicateOperatorType equals:[[fourthLevel subpredicates][0] predicateOperatorType] message:@"fourth level"];
}

- (void)assertKeyPathExpression:(CPExpression)actual equals:(CPString)expectedKeyPath {
    [self assert:CPKeyPathExpressionType equals:[actual expressionType] message:@"key path expression type"];
    [self assert:expectedKeyPath equals:[actual keyPath]];
}

- (void)assertConstantValueExpression:(CPExpression)actual equals:(CPString)expectedValue {
    [self assert:CPConstantValueExpressionType equals:[actual expressionType] message:@"constant value expression type"];
    [self assert:expectedValue equals:[actual constantValue]];
    [self assert:typeof expectedValue equals:typeof [actual constantValue] message:@"constant value type"];
}

@end
