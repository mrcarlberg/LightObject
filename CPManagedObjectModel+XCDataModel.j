//
//  CPManagedObjectModel+XCDataModel.j
//
//  Created by Raphael Bartolome on 23.11.09.
//

@import <Foundation/Foundation.j>
@import "CPManagedObjectModel.j"


@implementation CPManagedObjectModel (XCDataModel)

+ (void)modelWithContentsOfURL:(CPString)aPath completionHandler:(Function/*(CPManagedObjectModel)*/)completionBlock
{
    /*if(![modelPath hasSuffix:@"cxcdatamodel"])
    {
        var modelNameComponents = [modelPath componentsSeparatedByString:@"."];
        modelPath = [modelNameComponents objectAtIndex:0] + ".cxcdatamodel";
    }*/

    var request = [CPURLRequest requestWithURL:aPath];
    [CPURLConnection sendAsynchronousRequest:request queue:[CPOperationQueue mainQueue] completionHandler:function(response, result, error) {
        var data = [CPURLConnection sendSynchronousRequest: [CPURLRequest requestWithURL:aPath] returningResponse:nil];
        var managedObjectModel = [self objectModelFromXMLData:data];

        [managedObjectModel setNameFromFilePath:aPath];
        if (completionBlock) completionBlock(managedObjectModel);
    }];
}

+ (id)parseCoreDataModel:(CPString)aModelName
{
    var modelPath = aModelName;
    /*if(![modelPath hasSuffix:@"cxcdatamodel"])
    {
        var modelNameComponents = [modelPath componentsSeparatedByString:@"."];
        modelPath = [modelNameComponents objectAtIndex:0] + ".cxcdatamodel";
    }*/

    var data = [CPURLConnection sendSynchronousRequest: [CPURLRequest requestWithURL:modelPath] returningResponse:nil];

    if (data == nil) {
        console.log("Can't find model at path '" + modelPath + "'");
        return nil;
    } else {
        var managedObjectModel = [self objectModelFromXMLData:data];

        [managedObjectModel setNameFromFilePath:modelPath];
        return managedObjectModel;
    }
}

+ (id)objectModelFromXMLData:(CPData)modelData withName:(CPString)aName
{
    var managedObjectModel = [self objectModelFromXMLData:data];
    [managedObjectModel setName:aName];

    return managedObjectModel;
}

+ (id)objectModelFromXMLData:(CPData)modelData
{
    return [self objectModelFromXMLString:[modelData rawString]];
}

+ (id)objectModelFromXMLString:(CPString)modelString
{
    var plistContents = modelString.replace(/\<key\>\s*CF\$UID\s*\<\/key\>/g, "<key>CP$UID</key>");
    var unarchiver = [[CPKeyedUnarchiver alloc] initForReadingWithData:[CPData dataWithRawString:plistContents]];
    var managedObjectModel = [unarchiver decodeObjectForKey:@"root"];

    if (!managedObjectModel) {
        managedObjectModel = modelFromXML(modelString);
    }

    return managedObjectModel;
}

@end

var XML_XML                 = "xml",
    XML_DOCUMENT            = "#document",

    MODEL_MODEL             = "model",
    MODEL_ENTITY            = "entity",
    MODEL_ATTRIBUTE         = "attribute",
    MODEL_RELATIONSHIP      = "relationship",
    MODEL_USERINFO          = "userInfo",
    MODEL_ENTRY             = "entry",
    MODEL_ELEMENTS          = "elements",
    MODEL_ELEMENT           = "element",
    PLIST_KEY               = "key",
    PLIST_DICTIONARY        = "dict",
    PLIST_ARRAY             = "array",
    PLIST_STRING            = "string",
    PLIST_DATE              = "date",
    PLIST_BOOLEAN_TRUE      = "true",
    PLIST_BOOLEAN_FALSE     = "false",
    PLIST_NUMBER_REAL       = "real",
    PLIST_NUMBER_INTEGER    = "integer",
    PLIST_DATA              = "data";

#define NODE_NAME(anXMLNode)        (String(anXMLNode.nodeName))
#define NODE_TYPE(anXMLNode)        (anXMLNode.nodeType)
#define TEXT_CONTENT(anXMLNode)     (anXMLNode.textContent || (anXMLNode.textContent !== "" && textContent([anXMLNode])))
#define FIRST_CHILD(anXMLNode)      (anXMLNode.firstChild)
#define NEXT_SIBLING(anXMLNode)     (anXMLNode.nextSibling)
#define PARENT_NODE(anXMLNode)      (anXMLNode.parentNode)
#define DOCUMENT_ELEMENT(aDocument) (aDocument.documentElement)

#define ATTRIBUTE_VALUE(anXMLNode, anAttributeName) (anXMLNode.getAttribute(anAttributeName))
#define HAS_ATTRIBUTE_VALUE(anXMLNode, anAttributeName, aValue) (ATTRIBUTE_VALUE(anXMLNode, anAttributeName) === aValue)

#define IS_OF_TYPE(anXMLNode, aType) (NODE_NAME(anXMLNode) === aType)
#define IS_MODEL(anXMLNode) IS_OF_TYPE(anXMLNode, MODEL_MODEL)

#define IS_WHITESPACE(anXMLNode) (NODE_TYPE(anXMLNode) === 8 || NODE_TYPE(anXMLNode) === 3)
#define IS_DOCUMENTTYPE(anXMLNode) (NODE_TYPE(anXMLNode) === 10)

#define PLIST_NEXT_SIBLING(anXMLNode) while ((anXMLNode = NEXT_SIBLING(anXMLNode)) && IS_WHITESPACE(anXMLNode));
#define PLIST_FIRST_CHILD(anXMLNode) { anXMLNode = FIRST_CHILD(anXMLNode); if (anXMLNode !== NULL && IS_WHITESPACE(anXMLNode)) PLIST_NEXT_SIBLING(anXMLNode) }

var textContent = function(nodes)
{
    var text = "",
        index = 0,
        count = nodes.length;

    for (; index < count; ++index)
    {
        var node = nodes[index];

        if (node.nodeType === 3 || node.nodeType === 4)
            text += node.nodeValue;

        else if (node.nodeType !== 8)
            text += textContent(node.childNodes);
    }

    return text;
}

var _plist_traverseNextNode = function(anXMLNode, stayWithin, stack)
{
    var node = anXMLNode;

    PLIST_FIRST_CHILD(node);

    // If this element has a child, traverse to it.
    if (node)
        return node;

    // If not, first check if it is a container class (as opposed to a designated leaf).
    // If it is, then we have to pop this container off the stack, since it is empty.
    if (NODE_NAME(anXMLNode) === PLIST_ARRAY || NODE_NAME(anXMLNode) === PLIST_DICTIONARY)
        stack.pop();

    // If not, next check whether it has a sibling.
    else
    {
        if (node === stayWithin)
            return NULL;

        node = anXMLNode;

        PLIST_NEXT_SIBLING(node);

        if (node)
            return node;
    }

    // If it doesn't, start working our way back up the node tree.
    node = anXMLNode;

    // While we have a node and it doesn't have a sibling (and we're within our stayWithin),
    // keep moving up.
    while (node)
    {
        var next = node;

        PLIST_NEXT_SIBLING(next);

        // If we have a next sibling, just go to it.
        if (next)
            return next;

        var node = PARENT_NODE(node);

        // If we are being asked to move up, and our parent is the stay within, then just
        if (stayWithin && node === stayWithin)
            return NULL;

        // Pop the stack if we have officially "moved up"
        stack.pop();
    }

    return NULL;
}

//function encodeHTMLComponent(/*String*/ aString)
//{
//    return aString.replace(/&/g,'&amp;').replace(/"/g, '&quot;').replace(/'/g, '&apos;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
//}

var decodeHTMLComponent = function(/*String*/ aString)
{
    return aString.replace(/&quot;/g, '"').replace(/&apos;/g, '\'').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
}

var parseXML = function(/*String*/ aString)
{
    if (window.DOMParser)
        return DOCUMENT_ELEMENT(new window.DOMParser().parseFromString(aString, "text/xml"));

    else if (window.ActiveXObject)
    {
        XMLNode = new ActiveXObject("Microsoft.XMLDOM");

        // Extract the DTD, which confuses IE.
        var matches = aString.match(CFPropertyList.DTDRE);

        if (matches)
            aString = aString.substr(matches[0].length);

        XMLNode.loadXML(aString);

        return XMLNode
    }

    return NULL;
}

var modelFromXML = function(/*String | XMLNode*/ aStringOrXMLNode)
{
    var XMLNode = aStringOrXMLNode;

    if (aStringOrXMLNode.valueOf && typeof aStringOrXMLNode.valueOf() === "string")
        XMLNode = parseXML(aStringOrXMLNode);

    // Skip over DOCTYPE and so forth.
    while (IS_OF_TYPE(XMLNode, XML_DOCUMENT) || IS_OF_TYPE(XMLNode, XML_XML))
        PLIST_FIRST_CHILD(XMLNode);

    // Skip over the DOCTYPE... see a pattern?
    if (IS_DOCUMENTTYPE(XMLNode))
        PLIST_NEXT_SIBLING(XMLNode);

    // If this is not a PLIST, bail.
    if (!IS_MODEL(XMLNode))
        return NULL;

    var key = "",
        object = NULL,
        modelObject = [[CPManagedObjectModel alloc] init],

        modelNode = XMLNode,

        containers = [],
        currentContainer = NULL;

    while (XMLNode = _plist_traverseNextNode(XMLNode, modelNode, containers))
    {
        var count = containers.length;

        //console.log(new Array(count + 1).join("  ") + NODE_NAME(XMLNode));

        if (count)
            currentContainer = containers[count - 1];

        switch (String(NODE_NAME(XMLNode)))
        {
            case MODEL_ENTITY:          object = [[CPEntityDescription alloc] init];
                                        [object setName:ATTRIBUTE_VALUE(XMLNode, "name")];
                                        [object setExternalName:ATTRIBUTE_VALUE(XMLNode, "representedClassName")];
                                        [object setAbstract:ATTRIBUTE_VALUE(XMLNode, "isAbstract") === 'YES'];
                                        [modelObject addEntity:object];
                                        if (FIRST_CHILD(XMLNode)) containers.push(object);
                                        break;
            case MODEL_ATTRIBUTE:       object = [[CPAttributeDescription alloc] init];
                                        [object setName:ATTRIBUTE_VALUE(XMLNode, "name")];
                                        [object setOptional:ATTRIBUTE_VALUE(XMLNode, "optional") === 'YES'];
                                        [object setTransient:ATTRIBUTE_VALUE(XMLNode, "transient") === 'YES'];
                                        var typeValueString = ATTRIBUTE_VALUE(XMLNode, "attributeType").replace(/\s+/g, ''); // Remove spaces
                                        if (typeValueString === "Binary") typeValueString = "BinaryData";
                                        var typeValue = global["CPD" + typeValueString + "AttributeType"];
                                        //console.log("ValueType for " + ATTRIBUTE_VALUE(XMLNode, "attributeType") + " : " + typeValue);
                                        [object setTypeValue:typeValue || CPDUndefinedAttributeType];
                                        [object setDefaultValue:ATTRIBUTE_VALUE(XMLNode, "defaultValueString")];
                                        [currentContainer addProperty:object];
                                        [object setEntity:currentContainer];
                                        if (FIRST_CHILD(XMLNode)) containers.push(object);
                                        break;
            case MODEL_RELATIONSHIP:    object = [[CPRelationshipDescription alloc] init];
                                        [object setName:ATTRIBUTE_VALUE(XMLNode, "name")];
                                        [object setOptional:ATTRIBUTE_VALUE(XMLNode, "optional") === 'YES'];
                                        [currentContainer addProperty:object];
                                        [object setEntity:currentContainer];
                                        if (FIRST_CHILD(XMLNode)) containers.push(object);
                                        break;
            case MODEL_USERINFO:        object = new CFMutableDictionary();
                                        [currentContainer setUserInfo:object];
                                        if (FIRST_CHILD(XMLNode)) containers.push(object);
                                        break;
            case MODEL_ENTRY:           currentContainer.setValueForKey(ATTRIBUTE_VALUE(XMLNode, "key"), ATTRIBUTE_VALUE(XMLNode, "value"));
                                        break;
            case MODEL_ELEMENTS:        break;
            case MODEL_ELEMENT:         break;

            default:                    throw new Error("*** '" + NODE_NAME(XMLNode) + "' tag not recognized in model file.");
        }
    }

    return modelObject;
}
