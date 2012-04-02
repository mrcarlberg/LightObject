
@interface LOModifyRecord : NSObject
{

}

@end
@interface LOObjectContext : NSObject
{
    IBOutlet id delegate;
    IBOutlet LOObjectStore* objectStore;
}
- (IBAction)saveChanges(id)aSender;
@end