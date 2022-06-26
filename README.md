# Hexcore

[![pub package](https://img.shields.io/pub/v/hexcore.svg)](https://pub.dev/packages/hexcore)

A Flutter package which provides an interface to the League of Legends Client API (LCU API) and LCU Socket connection.



## Usage

Use `Hexcore.create` to create a new instance of Hexcore

```dart
  Hexcore hexcore = await Hexcore.create();

  await hexcore.connectToClient();
```
At the moment that Hexcore connect to the client, it will watch the League Client state. If the player closes the client, the package will wait until the player reopen it.

Hexcore have three states:

1. `searchingClientPath`: When Hexcore is searching for ther League Client path at the player's PC.
2. `waiting`: Hexcore already found the League Client Path, and now is waiting for the player to open the game or connecting to it.
3. `connected`: Hexcore is connected and ready to work.

Hexcore have a `ValueNotifier` that notifies about the state of the connection, so you can use an AnimatedContainer to build according to it's state.

```dart
...
AnimatedBuilder(
    animation: hexcore.status,
    builder: (BuildContext context, Widget? child) {
        if (hexcore.status.value == HexcoreStatus.waiting) {
            return const Center(
                child: CircularProgressIndicator(),
            );
        } else {
            return const Center(
                child: Text('Hexcore is ready!');
            );
        }
    },
);
...
```

### Send custom notification 
With hexcore you can send notification throw the League Client.

```dart
await hexcore.sendCustomNotification(
    title: 'Hexcore notification',
    details: 'Hello World',
    iconUrl: 'https://some_url_here',
    backgroundUrl: 'https://some_url_here',
);
```

### Create and join a custom lobby
This method create and insert the current player in a custom lobby.
```dart
await hexcore.createCustomMatch(
    lobbyName: 'Custom game #1',
    lobbyPassword: 'hexcore_123', 
);
```

### List custom lobbys

List all the available custom matches, so you can get the information you need to [join a match](#join-custom-match).
```dart
var matches = await hexcore.listCustomMatches();
```

### Join custom match
Use this method when you need to join a match. You can get the id of the match at `listCustomMatches` method.

```dart
await hexcore.joinCustomMatch(
    id: 'lobby_id',
    password: 'lobby_password'
);

```


## `HexcoreSocket` Usage

In this package you can also find an interface for the LCU Socket connection, where you can subscribe and listen to events emitted by LCU.

Use `HexcoreSocket.connect` to create a new instance and connection.

❗ You need to connect to the LCU using `Hexcore.connectToClient` before trying the socket connection. ❗

```dart
  HexcoreSocket hexcoreSocket = await HexcoreSocket.connect();
```

### Subscribing to LCU Events.

To subscribe to new events you need to call the method `add`. 
```dart
hexcoreSocket.add('[5, "OnJsonApiEvent"]');
```
In this example you subscribe to all LCU Events. [Here](https://hextechdocs.dev/getting-started-with-the-lcu-websocket/) you can understand more about LCU Events.


### Handling Events

Use `listen` method to create a `StreamSubscription` to handle the events that have been subscribed.

```dart
hexcoreSocket.listen((event){
    print(event);
});
```
## Additional information

You may need to override the `badCertificateCallback` in way to send requests to the League Client, there is a example:

```dart
HttpOverrides.global = MyHttpOverrides();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
```
