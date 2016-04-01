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

More documentation is coming shortly....
