//
//  CPRelationshipDescription.j
//
//  Created by Raphael Bartolome on 15.10.09.
//

@import <Foundation/CPObject.j>
@import "CPPropertyDescription.j"


CPRelationshipDescriptionDeleteRuleNullify = 0;
CPRelationshipDescriptionDeleteRuleCascade = 1;
CPRelationshipDescriptionDeleteRuleDeny = 2;
CPRelationshipDescriptionDeleteRuleNoAction = 3;


@implementation CPRelationshipDescription : CPPropertyDescription
{
    CPString _inversePropertyName @accessors(property=inversePropertyName);
    CPString _destinationEntityName @accessors(property=destinationEntityName);
    BOOL _toMany @accessors(property=isToMany);
    int _deleteRule @accessors(property=deleteRule);
}

- (Class)destinationClassType
{
    var result = [CPObject class];
    var classType = CPClassFromString(_destinationEntityName);

    if(classType != nil)
    {
        result = classType;
    }

    return result
}

- (BOOL)acceptValue:(id) aValue
{
    var result = NO;
    var theProperty = [[self propertiesByName] objectForKey:_name]; // FIXME: Don't know if this should be '_name' instead of the unknown variable 'aKey'
    result = [theProperty acceptValue:aValue];
    return result;
}

- (CPEntityDescription)destination
{
    return [[[self entity] model] entityWithName:_destinationEntityName];
}

- (CPString)stringRepresentation
{
    var result = "\n";
    result = result + "\n";
    result = result + "-CPRelationshipDescription-";

    result = result + "\n";
    result = result + "name:" + [self name] + ";";
    result = result + "\n";
    result = result + "destination:" + [self destinationEntityName] + ";";
    result = result + "\n";
    result = result + "isToMany:" + [self isToMany] + ";";
    result = result + "\n";
    result = result + "optional:" + [self isOptional] + ";";
    result = result + "\n";
    result = result + "deleteRule:" + [self deleteRule] + ";";
    return result;
}

@end