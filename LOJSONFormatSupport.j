@import <Foundation/CPCompoundPredicate.j>
@import <Foundation/CPComparisonPredicate.j>
@import <Foundation/CPExpression.j>

LOJSONUnsupportedPredicateOperatorException = @"LOJSONUnsupportedPredicateOperatorException";

LOJSONInvalidExpressionValueException = @"LOJSONInvalidExpressionValueException";
LOJSONUnsupportedExpressionTypeException = @"LOJSONUnsupportedExpressionTypeException";
LOJSONUnsupportedExpressionValueException = @"LOJSONUnsupportedExpressionValueException";


@implementation CPPredicate (LOJSONFormatSupport)

+ (CPPredicate)predicateFromLOJSONFormat:(JSON)someJSON {
    if ([LOJSONFormatSupportGetComparisonOperatorMap() isSupportedOperatorString:someJSON.o]) {
        return [CPComparisonPredicate predicateFromLOJSONFormat:someJSON];
    } else {
        return [CPCompoundPredicate predicateFromLOJSONFormat:someJSON];
    }
}

@end


@implementation CPComparisonPredicate (LOJSONFormatSupport)

+ (CPPredicate)predicateFromLOJSONFormat:(JSON)someJSON {
    var opType = [LOJSONFormatSupportGetComparisonOperatorMap() getTypeFromStringOrRaise:someJSON.o];
    var leftExpression = [CPExpression expressionFromLOJSONFormat:{"type": someJSON.lt, "value": someJSON.l}];
    var rightExpression = [CPExpression expressionFromLOJSONFormat:{"type": someJSON.rt, "value": someJSON.r}];
    var options = 0;
    if (someJSON.c) options = CPCaseInsensitivePredicateOption;
    return [[CPComparisonPredicate alloc] initWithLeftExpression:leftExpression rightExpression:rightExpression modifier:CPDirectPredicateModifier type:opType options:options];
}

- (JSON)LOJSONFormat {
    var result = {};

    result["o"] = [LOJSONFormatSupportGetComparisonOperatorMap() getStringFromTypeOrRaise:[self predicateOperatorType]];

    var expressionJSON = [[self leftExpression] LOJSONFormat];
    result["l"] = expressionJSON.value;
    result["lt"] = expressionJSON.type;

    expressionJSON = [[self rightExpression] LOJSONFormat];
    result["r"] = expressionJSON.value;
    result["rt"] = expressionJSON.type;

    if ([self options] & CPCaseInsensitivePredicateOption)
        result["c"] = true;

    return result;
}

@end


@implementation CPCompoundPredicate (LOJSONFormatSupport)

+ (CPPredicate)predicateFromLOJSONFormat:(JSON)someJSON {
    var opType = [LOJSONFormatSupportGetCompoundOperatorMap() getTypeFromStringOrRaise:someJSON.o];
    var subpreds = [];
    for (var i=0; i<someJSON.p.length; i++) {
        var predJson = someJSON.p[i];
        var subpred = [CPPredicate predicateFromLOJSONFormat:predJson];
        [subpreds addObject:subpred];
    }
    return [[CPCompoundPredicate alloc] initWithType:opType subpredicates:subpreds];
}

- (JSON)LOJSONFormat {
    var result = {};

    result["o"] = [LOJSONFormatSupportGetCompoundOperatorMap() getStringFromTypeOrRaise:[self compoundPredicateType]];

    result.p = [];
    for (var i=0; i < [[self subpredicates] count]; i++) {
        var subpred = [[self subpredicates] objectAtIndex:i];
        [result.p addObject:[subpred LOJSONFormat]];
    }
    return result;
}

@end


@implementation CPExpression (LOJSONFormatSupport)

function _BOPValidValueJSONOrRaise(someJSON) {
    var missing = [CPMutableArray array];
    if (!someJSON.type) [missing addObject:@"type"];
    if (someJSON.value === undefined) [missing addObject:@"value"];
    if ([missing count] > 0)
        [CPException raise:LOJSONInvalidExpressionValueException reason:@"Expression format missing " + missing.join(@" and ")];

    return someJSON;
}

+ (CPExpression)expressionFromLOJSONFormat:(JSON)someJSON {
    var json = _BOPValidValueJSONOrRaise(someJSON);
    var type = json.type;
    var value = json.value;

    if ([type isEqual:@"array"]) {
        if (!value || !value.isa || ![value isKindOfClass:[CPArray class]])
            [CPException raise:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type '" + type + "'. Value must be an array: '" + value + "'"];

        var subexprs = [CPMutableArray array];
        try {
            for (var i=0; i<[value count]; i++) {
                var subValue = value[i];
                [subexprs addObject:[self _atomExpressionFromLOJSONFormat:subValue]];
            }
        }
        catch (exception) {
            [CPException raise:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type '" + type + "'. Invalid sub-value: "+ [exception reason]];
        }
        return [CPExpression expressionForAggregate:subexprs];
    }

    return [self _atomExpressionFromLOJSONFormat:json];
}

+ (CPExpression)_atomExpressionFromLOJSONFormat:(JSON)someJSON {
    _BOPValidValueJSONOrRaise(someJSON);

    var validNumberOrRaise = function(value,type) {
        var v = (value === null) ? null : Number(value);
        if (v === null || isNaN(v))
            [CPException raise:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type '" + type + "'. Value must be a valid number: '" + v + "'"];
        return v;
    };
    var validBooleanOrRaise = function(value,type) {
        if (typeof value == "boolean") return value;
        if (value == "true") return true;
        if (value == "false") return false;
        [CPException raise:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type '" + type + "'. Value must be a valid boolean: '" + value + "'"];
    };
    var validStringOrRaise = function(value,type) {
        if (value === null)
            [CPException raise:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type '" + type + "'. Value must not be null"];
        return String(value);
    }
    var validKeyPathOrRaise = function(value,type) {
        validStringOrRaise(value,type);
        if (value == "")
            [CPException raise:LOJSONInvalidExpressionValueException reason:@"Unable to parse expression of type '" + type + "'. Value must not be empty"];
        return String(value);
    }

    if (someJSON.type == "string") {
        return [CPExpression expressionForConstantValue:validStringOrRaise(someJSON.value, someJSON.type)];
    } else if (someJSON.type == "number") {
        return [CPExpression expressionForConstantValue:validNumberOrRaise(someJSON.value, someJSON.type)];
    } else if (someJSON.type == "bool") {
        return [CPExpression expressionForConstantValue:validBooleanOrRaise(someJSON.value, someJSON.type)];
    } else if (someJSON.type == "keyPath") {
        return [CPExpression expressionForKeyPath:validKeyPathOrRaise(someJSON.value, someJSON.type)];
    } else if (someJSON.type == "datetime") {
        return [CPExpression expressionForConstantValue:[CPDate dateWithTimeIntervalSinceReferenceDate:validNumberOrRaise(someJSON.value, someJSON.type)]];
    } else if (someJSON.type == "null") {
        return [CPExpression expressionForConstantValue:nil];
    }
    [CPException raise:LOJSONUnsupportedExpressionTypeException reason:@"Unsupported expression type '" + someJSON.type + "'"];
}

- (JSON)LOJSONFormat {
    var myType = [self expressionType];
    var myValue = (myType == CPConstantValueExpressionType) ? [self constantValue] : (myType == CPAggregateExpressionType) ? [self collection] : undefined;

    if (myType == CPAggregateExpressionType || (myType == CPConstantValueExpressionType && myValue && myValue.isa && [myValue isKindOfClass:[CPArray class]])) {
        var values = [CPMutableArray array];
        try {
            for (var i=0; i<[myValue count]; i++) {
                var subexpr = myValue[i];
                if (!subexpr.isa || ![subexpr isKindOfClass:[CPExpression class]]) {
                    subexpr = [CPExpression expressionForConstantValue:subexpr];
                }
                [values addObject:[subexpr _atomLOJSONFormat]];
            }
        } catch (exception) {
            [CPException raise:LOJSONUnsupportedExpressionValueException reason:@"Unsupported value of aggregate expression: " + [exception reason]];
        }
        return {type:"array", value:values};
    }

    return [self _atomLOJSONFormat];
}

- (JSON)_atomLOJSONFormat {
    var type = undefined;
    var value = undefined;

    switch ([self expressionType]) {
        case CPConstantValueExpressionType:
            value = [self constantValue];
            if (value === null || value === [CPNull null]) {
                value = nil;
                type = @"null";
            } else if (typeof value == "string") {
                type = "string";
            } else if (typeof value == "number") {
                type = "number";
            } else if (typeof value == "boolean") {
                type = "bool";
            } else if (value != null && value.isa && [value isKindOfClass:[CPDate class]]) {
                value = Number([value timeIntervalSinceReferenceDate]);
                type = "datetime";
            } else {
                [CPException raise:LOJSONUnsupportedExpressionValueException reason:@"Unsupported type '" + typeof value + "' for constant value expression"];
            }
            break;

        case CPKeyPathExpressionType:
            value = [self keyPath];
            if (value === undefined) [CPException raise:LOJSONUnsupportedExpressionValueException reason:@"Key path expression must not be undefined"];
            if (value === null) [CPException raise:LOJSONUnsupportedExpressionValueException reason:@"Key path expression must not be null"];
            if (value == @"") [CPException raise:LOJSONUnsupportedExpressionValueException reason:@"Key path expression must not be empty"];
            type = "keyPath";
            break;

        default:
            [CPException raise:LOJSONUnsupportedExpressionTypeException reason:@"Unsupported expression type '" + [self expressionType] + "'"];
    }

    return { @"type": type, @"value": value };
}

@end


@implementation LOJSONFormatTypeStringMap : CPObject {
    CPArray typesAndStrings;
    CPSet supportedTypes;
    JSON typeStringMap;
    JSON stringTypeMap;
}

+ (id)mapForComparisonOperators {
    var pairs = [
        [CPNotEqualToPredicateOperatorType,            @"!=" /* also @"<>" */],
        [CPLessThanOrEqualToPredicateOperatorType,     @"<=" /* also @"=<" */],
        [CPGreaterThanOrEqualToPredicateOperatorType,  @">=" /* also @"=>" */],
        [CPLessThanPredicateOperatorType,              @"<"],
        [CPGreaterThanPredicateOperatorType,           @">"],
        [CPEqualToPredicateOperatorType,               @"==" /* also @"="*/],
        [CPLikePredicateOperatorType,                  @"like"],
        [CPInPredicateOperatorType,                    @"in"],
        [CPBetweenPredicateOperatorType,               @"between"],
        [CPMatchesPredicateOperatorType,               @"MATCHES"],
        [CPBeginsWithPredicateOperatorType,            @"BEGINSWITH"],
        [CPEndsWithPredicateOperatorType,              @"ENDSWITH"],
        [CPContainsPredicateOperatorType,              @"CONTAINS"],
    ];
    var supported = [CPSet setWithArray:[
        CPNotEqualToPredicateOperatorType,
        CPLessThanOrEqualToPredicateOperatorType,
        CPGreaterThanOrEqualToPredicateOperatorType,
        CPLessThanPredicateOperatorType,
        CPGreaterThanPredicateOperatorType,
        CPEqualToPredicateOperatorType,
        CPLikePredicateOperatorType,
        CPInPredicateOperatorType,
        CPBetweenPredicateOperatorType,
    ]];
    return [[LOJSONFormatTypeStringMap alloc] initWithTypesAndStrings:pairs supportedTypes:supported];
}

+ (id)mapForCompoundOperators {
    var pairs = [
        [CPAndPredicateType,    @"and"],
        [CPOrPredicateType,     @"or"],
        [CPNotPredicateType,    @"not"],
    ];
    var supported = [CPSet setWithArray:[
        CPAndPredicateType,
        CPOrPredicateType,
        CPNotPredicateType,
    ]];
    return [[LOJSONFormatTypeStringMap alloc] initWithTypesAndStrings:pairs supportedTypes:supported];
}

- (id)initWithTypesAndStrings:(CPArray)typeStringPairs supportedTypes:(CPArray)someTypes {
    if (!(self = [super init])) return nil;
    typesAndStrings = typeStringPairs;
    supportedTypes = someTypes;
    [self generateMaps];
    return self;
}

- (void)generateMaps {
    typeStringMap = {};
    stringTypeMap = {};
    for (var i=0; i < typesAndStrings.length; i++) {
        var typeAndString = typesAndStrings[i];
        typeStringMap[typeAndString[0]] = typeAndString[1];
        stringTypeMap[typeAndString[1]] = typeAndString[0];
    }
}

- (CPNumber)getTypeFromStringOrRaise:(CPString)aString {
    var t = stringTypeMap[aString];
    if (t === undefined || ![supportedTypes containsObject:t]) {
        [self raiseForUnsupportedOperator:aString];
    }
    return t;
}

- (CPString)getStringFromTypeOrRaise:(CPNumber)aType {
    var s = typeStringMap[aType];
    if (s === undefined || ![supportedTypes containsObject:aType]) {
        [self raiseForUnsupportedOperator:s || aType];
    }
    return s;
}

- (BOOL)isSupportedOperatorString:(id)aString {
    var t = stringTypeMap[aString];
    if (t === undefined || ![supportedTypes containsObject:t]) return NO;
    return YES;
}

- (void)raiseForUnsupportedOperator:(id)anOperator {
    [CPException raise:LOJSONUnsupportedPredicateOperatorException reason:@"Unsupported predicate operator '" + anOperator + "'"];
}

@end


var LOJSONFormatSupportComparisonOperatorMap = nil;
var LOJSONFormatSupportCompoundOperatorMap = nil;

function LOJSONFormatSupportGetComparisonOperatorMap() {
    if (!LOJSONFormatSupportComparisonOperatorMap)
        LOJSONFormatSupportComparisonOperatorMap = [LOJSONFormatTypeStringMap mapForComparisonOperators];
    return LOJSONFormatSupportComparisonOperatorMap;
}

function LOJSONFormatSupportGetCompoundOperatorMap() {
    if (!LOJSONFormatSupportCompoundOperatorMap)
        LOJSONFormatSupportCompoundOperatorMap = [LOJSONFormatTypeStringMap mapForCompoundOperators];
    return LOJSONFormatSupportCompoundOperatorMap;
}
