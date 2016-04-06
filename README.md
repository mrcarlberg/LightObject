# What Is LightObject?
LightObject is a [Cappuccino](https://github.com/cappuccino/cappuccino) framework that you use to manage the model layer objects in your application. It provides generalized and automated solutions to common tasks associated with object life cycle and object graph management, including persistence.

Light Object typically decreases the amount of code you write to support the model layer. This is primarily due to the following built-in features that you do not have to implement, test, or optimize:

- Change tracking of attributes on objects.
- Maintenance of change propagation, including maintaining the consistency of relationships among objects.
- Lazy loading of objects, partially materialized futures (faulting).
- Grouping, filtering, and organizing data in memory and in the user interface.
- Automatic support for storing objects in postgresql database with this [backend](https://github.com/mrcarlberg/objj-backend)
- Sophisticated query compilation. Instead of writing SQL, you can create complex queries by associating an CPPredicate object with a fetch request.
- Effective integration with the OS X and iOS tool chains.

# Tutorial

Lets do a quick tutorial how you can create a small application running in the web browser and updating an postgresql database.

You have to install the following things before we begin:
- [Node](https://nodejs.org) version 4 or later
- [Postgresql](http://www.postgresql.org)
- [Cappuccino](http://www.cappuccino-project.org) version 0.9.9 or later
- Some kind of webserver

First we need to create a new Cappuccino project inside your document directory for your webserver:
```
cd /path/to/your/webserver/document/directory
capp gen PersonApplication
```

Install the LightObject framework:
```
cd PersonApplication/Frameworks
git clone https://github.com/mrcarlberg/LightObject.git
cd ..
```

Open the AppController.j file with your favorite text editor and edit it to look like this:
```
@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>
@import <LightObject/LightObject.j>
@import <LightObject/LOBackendObjectStore.j>

@implementation AppController : CPObject
{
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    var theWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask],
        contentView = [theWindow contentView],
        tableView = [[CPTableView alloc] initWithFrame:CGRectMakeZero()],
        columnFirstname = [[CPTableColumn alloc] initWithIdentifier:'firstnameId'],
        columnLastname = [[CPTableColumn alloc] initWithIdentifier:'lastnameId'],
        scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(50, 50, 210, 300)],
        objectContext = [[LOObjectContext alloc] init],
        personArrayController = [[LOArrayController alloc] init],
        objectStore = [[LOBackendObjectStore alloc] init],
        insertButton = [[CPButton alloc] initWithFrame:CGRectMake(280, 80, 30.0, 25)],
        removeButton = [[CPButton alloc] initWithFrame:CGRectMake(280, 110, 30.0, 25)];

    // Setup the tableview
    [tableView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [tableView setUsesAlternatingRowBackgroundColors:YES];

    // Setup the table columns
    [[columnFirstname headerView] setStringValue:@"Firstname"];
    [[columnLastname headerView] setStringValue:@"Lastname"];
    [columnFirstname setEditable:YES];
    [columnLastname setEditable:YES];

    // Add the columns to the table view
    [tableView addTableColumn:columnFirstname];
    [tableView addTableColumn:columnLastname];

    // Bind the tableview columns with the array controller
    [columnFirstname bind:@"value" toObject:personArrayController withKeyPath:@"arrangedObjects.firstname" options:nil];
    [columnLastname bind:@"value" toObject:personArrayController withKeyPath:@"arrangedObjects.lastname" options:nil];

    // Connect the object store, object context and array controller
    [objectContext setObjectStore:objectStore];
    [personArrayController setObjectContext:objectContext];

    // Tell the array controller what entity it handles
    [personArrayController setEntityName:@"Person"];

    // Get the model from the Backend
    [objectStore retrieveModelWithCompletionHandler:function(receivedModel) {
        // When the model has arrived we can fetch the Person objects
        var fs = [LOFetchSpecification fetchSpecificationForEntityNamed:@"Person"];

        [objectContext requestObjectsWithFetchSpecification:fs withCompletionHandler:function(objects, statusCode) {
            // Set the content on the array controller
            if (statusCode === 200)
                [personArrayController setContent:objects];
        }];
    }];

    // Add insert and remove buttons. Connect the actions to the array controller.
    [insertButton setTitle:@"+"];
    [removeButton setTitle:@"-"];
    [contentView addSubview:insertButton];
    [contentView addSubview:removeButton];
    [insertButton setTarget:personArrayController];
    [insertButton setAction:@selector(insert:)];
    [removeButton setTarget:personArrayController];
    [removeButton setAction:@selector(remove:)];

    // Add the views to the content view in the window
    [scrollView setBorderType:CPLineBorder];
    [scrollView setDocumentView:tableView];
    [contentView addSubview:scrollView];
    [theWindow orderFront:self];

    // Uncomment the following line to turn on the standard menu bar.
    //[CPMenu setMenuBarVisible:YES];
}

@end
```

Now we need to install the backend:
```
cd /somewhere/on/your/harddisc
npm install objj-backend
cd node_modules/objj-backend
```

Open your favorite text editor again and create a model xml file that look like this:
```
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0">
    <entity name="Person" representedClassName="CPMutableDictionary">
        <attribute name="firstname" optional="YES" attributeType="String"/>
        <attribute name="lastname" optional="YES" attributeType="String"/>
        <attribute name="primaryKey" attributeType="Integer 64"/>
    </entity>
</model>
```

We need to create a postgresql database:
```
createdb -U <YourPostgresqlUsername> MyPersonDatabase
```
Enter a password for the database

Now start the backend:
```
bin/objj main.j -d MyPersonDatabase -u <YourPostgresqlUsername> -v -V -A /path/to/model/file/created/above
```

The option ```-v``` (verbose) will log all sql statements etc. ```-V``` (Validate) will validate the database against the model file. ```-A``` (Alter) will generate sql statements if the validation fail. It will alter the database so it will correspond to the model file.

The backend should prompt for a username for the database. After the password is entered the validation should fail but it will generate the nessesary sql to create any missing tables etc.
The backend should start on port 1337

The last thing we need to do is to setup the webserver to direct requests with the URL /backend to http://localhost:1337

If you use an Apache webserver you could use the proxy module and add the following line to your config:
```
ProxyPass /backend http://localhost:1337
```

Now you should be able to open the index.html or index-debug.html file in the PersonApplication directory. Press the plus and minus buttons to add and remove rows in the table.



More documentation is coming shortly....
