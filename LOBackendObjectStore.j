/*
 * LOBackendObjectStore.j
 *
 * Created by Martin Carlberg on Januaray 31, 2016.
 * Copyright 2016, All rights reserved.
 */


@import "LOAdvanceJSONObjectStore.j"

/*!
    This object store should be used if the you want to connect to the node Backend
    written in Objective-J
*/

@implementation LOBackendObjectStore : LOAdvanceJSONObjectStore {
    CPString baseURL @accessors;
    CPArray blocksToRunWhenModelIsReceived;
}

- (id)init {
    self = [super init];
    if (self) {
        if (window && window.location) {
            var hostname = window.location.hostname;
            var protocol = window.location.protocol;
            if (hostname != nil && protocol != nil) {
                baseURL = protocol + @"//" + hostname + "/backend";
            }
        }
    }
    return self;
}

- (void)awakeFromCib {
    [super awakeFromCib];
    if (!model) {
        [CPManagedObjectModel modelWithContentsOfURL:baseURL + @"/retrievemodel" completionHandler:function(receivedModel) {
            if (model) {
                console.error("Model is already set on object store when receiving model from backend.");
            } else {
                model = receivedModel;
                if (blocksToRunWhenModelIsReceived) {
                    [blocksToRunWhenModelIsReceived enumerateObjectsUsingBlock:function(aBlock) {
                        aBlock();
                    }];
                    blocksToRunWhenModelIsReceived = nil;
                }
            }
        }];
    }
}

- (void)retrieveModelWithCompletionHandler:(Function/*(CPManagedObjectModel)*/)completionBlock {
    [CPManagedObjectModel modelWithContentsOfURL:baseURL + @"/retrievemodel" completionHandler:function(receivedModel) {
        model = receivedModel;

        if (completionBlock) completionBlock(receivedModel);
    }];
}

// This is used to get things to run after the model is loaded
- (void)addBlockToRunWhenModelIsReceived:(Function)aBlock {
    if (!blocksToRunWhenModelIsReceived) {
        blocksToRunWhenModelIsReceived = [];
    }

    [blocksToRunWhenModelIsReceived addObject:aBlock];
}

- (CPString)urlForSaveChangesWithData:(id)data {
    if (!baseURL) throw new Error(_cmd + @" Has no baseURL to use");
    return baseURL + @"/modify";
}

- (CPURLRequest)urlForRequestObjectsWithFetchSpecification:(LOFetchSpecification)fetchSpecification {
    if (!baseURL) throw new Error(_cmd + @" Has no baseURL to use");
    var resolvedEntityName = [fetchSpecification alias] || [fetchSpecification entityName];
    var url = baseURL;
    if ([fetchSpecification method]) {
        url = url + @"/" + [fetchSpecification method];
    } else {
        url = url + @"/fetch";
    }
    url += @"/" + resolvedEntityName;
    if ([fetchSpecification operator]) {
        url = url + @"/" + [fetchSpecification operator];
    }

    var advancedQualifierString = nil;
    var qualifier = [fetchSpecification qualifier];
    if (qualifier) {
        var qualifierString = [self buildRequestPathForQualifier:qualifier];
        if (qualifierString) {
            url = url + @"/" + qualifierString;
        } else {
            qualifierString = [LOAdvanceJSONObjectStore UTF16ToUTF8:JSON.stringify([qualifier LOJSONFormat])];
            advancedQualifierString = [[CPData dataWithRawString:qualifierString] base64];
            url = url + @"/X-LO-Advanced-Qualifier=" + md5lib.md5(qualifierString);
        }
    }
    var request = [CPURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    if (advancedQualifierString) {
        [request setValue:advancedQualifierString forHTTPHeaderField:@"X-LO-Advanced-Qualifier"];
    }

    return request;
}

- (CPString)buildRequestPathForQualifier:(CPPredicate)aQualifier {
    if (!aQualifier) return nil;

    var qualiferAndItems = [aQualifier];
    if ([aQualifier isKindOfClass:[CPCompoundPredicate class]]) {
        if ([aQualifier compoundPredicateType] != CPAndPredicateType) return nil;
        qualiferAndItems = [aQualifier subpredicates];
    }

    var qualiferAndItemSize = [qualiferAndItems count];
    for (var i = 0; i < qualiferAndItemSize; i++) {
        var eachQualifier = [qualiferAndItems objectAtIndex:i];
        if (![eachQualifier isKindOfClass:[CPComparisonPredicate class]]) return nil;
        if ([eachQualifier predicateOperatorType] != CPEqualToPredicateOperatorType) return nil;
        if ([[eachQualifier leftExpression] expressionType] != CPKeyPathExpressionType) return nil;
        if ([[eachQualifier rightExpression] expressionType] != CPConstantValueExpressionType) return nil;
        if (([[eachQualifier rightExpression] expressionType] === CPConstantValueExpressionType) &&
            (![[eachQualifier rightExpression] constantValue])) return nil;
        if (([[eachQualifier rightExpression] expressionType] === CPConstantValueExpressionType) &&
            ((![[[eachQualifier rightExpression] constantValue] isKindOfClass:[CPString class]]) &&
            (![[[eachQualifier rightExpression] constantValue] isKindOfClass:[CPNumber class]]))
            ) return nil;
    }

    // We've now ensured that each predicate is a simple 'keyPath equals constant value' predicate
    var parts = [];
    for (var i = 0; i < qualiferAndItemSize; i++) {
        var eachQualifier = [qualiferAndItems objectAtIndex:i];
        var left = [[eachQualifier leftExpression] description];
        var right = [[[eachQualifier rightExpression] constantValue] description];
        // todo: percent encode whitespace
        [parts addObject:[self escapeStringForQualifier:left] + @"=" + [self escapeStringForQualifier:right]];
    }

    if ([parts count] == 0) return nil;
    return parts.join(@"/");
}

- (CPString)escapeStringForQualifier:(CPString)aString {
    var result = [aString stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
    result = [result stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
    return result;
}

/*!
 * Returns the type for the raw row.
 */
- (CPString)typeForRawRow:(id)row objectContext:(LOObjectContext)objectContext fetchSpecification:(LOFetchSpecification)fetchSpecification {
    var type = row._type;

    // If we the row does not have the type use the entityName
    return type != nil ? type : fetchSpecification.entityName;
}

/*!
 * Returns the primary key attribute for the raw row.
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (CPString)primaryKeyAttributeForType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    return @"primaryKey";
}

/*!
 * Returns true if the attribute is a foreign key for the raw row.
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (BOOL)isForeignKeyAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    return [attribute hasSuffix:@"ForeignKey"];
}

/*!
 * Returns to one relationship attribute that correspond to the foreign key attribute for the raw row
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (CPString)toOneRelationshipAttributeForForeignKeyAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    return [attribute substringToIndex:[attribute length] - 10]; // Remove "ForeignKey" at end of attribute
}

/*!
 * Returns foreign key attribute that correspond to the to one relationship attribute for the type
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (CPString)foreignKeyAttributeForToOneRelationshipAttribute:(CPString)attribute forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
   return attribute + @"ForeignKey";
}

/*!
 * Returns the primary key for the raw row with type aType.
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (CPString)primaryKeyForRawRow:(id)row forType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    var primaryKeyAttribute = [self primaryKeyAttributeForType:aType objectContext:objectContext];
    return row[primaryKeyAttribute];
}

/*!
 * Returns LOError for data if the backend has returned a error.
 */
- (id)dataForResponse:(CPHTTPURLResponse)response andData:(CPString)data fromURL:(CPString)urlString connection:(CPURLConnection)connection error:(LOErrorRef)error {
    var statusCode = [response statusCode];

    if (statusCode === 200) return [data length] > 0 ? [data objectFromJSON] : data;

    if (statusCode === 537) { // Error from backend. Should maybe include more codes?
        var jSON = [data objectFromJSON];
        if (jSON.error) {
            if (jSON.error.code && jSON.error.domain) {
                @deref(error) = [LOError errorWithDomain:jSON.error.domain code:jSON.error.code userInfo:nil];
            } else {
                @deref(error) = [LOError errorWithDomain:nil code:0 userInfo:[CPDictionary dictionaryWithObject:jSON.error forKey:@"errorText"]];
            }
        } else if (jSON.exception) {
            @deref(error) = [LOError errorWithDomain:jSON.exception.domain code:jSON.exception.code userInfo:[CPDictionary dictionaryWithJSObject:jSON.exception]];
        }
    } else {
        @deref(error) = [LOError errorWithDomain:@"org.carlberg.LOF" code:statusCode userInfo:[CPDictionary dictionaryWithObject:urlString forKey:@"url"]];
    }
    return nil;
}

- (CPString)typeOfObject:(id)theObject {
    return theObject._loObjectType;
}

- (void)setType:(CPString)aType onObject:(id)theObject {
    theObject._loObjectType = aType;
}

   // TODO: Move this up to super class where we use the model.
- (id)newObjectForType:(CPString)aType objectContext:(LOObjectContext)objectContext {
    var entity = [self entityForName:aType];
    if (entity) {
        var className = [entity externalName];
        var aClass = objj_getClass(className);
        if (aClass) {
            var obj = [[aClass alloc] init];
            [self setType:aType onObject:obj];
            return obj;
        } else
            CPLog.error(@"[" + [self className] + @" " + _cmd + @"]: Class '" + className + "' can't be found for entity named '" + aType + "'");
    } else {
        CPLog.error(@"[" + [self className] + @" " + _cmd + @"]: Entity can't be found for entity named '" + aType + "'");
    }
    return nil;
}

/*!
 * Returns the primary key value for an object.
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (CPString)primaryKeyForObject:(id)theObject {
    return [theObject valueForKey:@"primaryKey"];
}

/*!
 * Sets the primary key value for an object.
   TODO: Move this up to super class and get information from model. Maybe this method can be removed?
 */
- (void)setPrimaryKey:(CPString)thePrimaryKey forObject:(id)theObject {
    [theObject setValue:thePrimaryKey forKey:@"primaryKey"];
}

@end
