//
//  CPManagedObjectModel+XCDataModel.j
//
//  Created by Raphael Bartolome on 23.11.09.
//

@import <Foundation/Foundation.j>


@implementation CPManagedObjectModel (XCDataModel)


+ (void)parseCoreDataModel:(CPString)aModelName
{
	var modelPath = aModelName;
	/*if(![modelPath hasSuffix:@"cxcdatamodel"])
	{
		var modelNameComponents = [modelPath componentsSeparatedByString:@"."];
		modelPath = [modelNameComponents objectAtIndex:0] + ".cxcdatamodel";
	}*/

	var data = [CPURLConnection sendSynchronousRequest: [CPURLRequest requestWithURL:modelPath] returningResponse:nil];
	var managedObjectModel = [self objectModelFromXMLData:data];

	[managedObjectModel setNameFromFilePath: modelPath];
	return managedObjectModel;
}

+ (void)objectModelFromXMLData:(CPData)modelData withName:(CPString)aName
{
	var managedObjectModel = [self objectModelFromXMLData:data];
	[managedObjectModel setName:aName];

	return managedObjectModel;
}

+ (void)objectModelFromXMLData:(CPData)modelData
{
	var plistContents = [modelData rawString].replace(/\<key\>\s*CF\$UID\s*\<\/key\>/g, "<key>CP$UID</key>");
	var unarchiver = [[CPKeyedUnarchiver alloc] initForReadingWithData:[CPData dataWithRawString:plistContents]];
	var managedObjectModel = [unarchiver decodeObjectForKey:@"root"];

	return managedObjectModel;
}

+ (void)objectModelFromXMLString:(CPString)modelString
{
	var plistContents = modelString.replace(/\<key\>\s*CF\$UID\s*\<\/key\>/g, "<key>CP$UID</key>");
	var unarchiver = [[CPKeyedUnarchiver alloc] initForReadingWithData:[CPData dataWithRawString:plistContents]];
	var managedObjectModel = [unarchiver decodeObjectForKey:@"root"];

	return managedObjectModel;
}

@end