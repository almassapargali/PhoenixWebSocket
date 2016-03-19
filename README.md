# PhoenixWebSocket

`PhoenixWebSocket` is a websockets framework designed to work with [Phoenix Framework](https://github.com/phoenixframework/phoenix). It uses [Starscream](https://github.com/daltoniam/Starscream) under the hood.

## Installation

### Carthage

```
github "almassapargali/PhoenixWebSocket"
```

## Usage

### Connecting

Don't forget to append `/websocket`, to specify transport, to you socket path.

```swift
let url = NSURL(string: "ws://localhost:4000/socket/websocket")!
// create socket and channel
socket = Socket(url: url)

channel = Channel(topic: "rooms:lobby")

// you can optionally set join payload
channel.joinPayload = ["user_id": 123]

socket.join(channel)

// you can optionally enable logging
socket.enableLogging = true

// then connect
socket.connect()
```

This framework users `NSTimer`s extensively for reconnecting or sending heartbeat message. And since iOS invalidates all `NSTimer`s when app goes background, it's recommended to call `connect` again on `UIApplicationWillEnterForegroundNotification`. Like:

```swift
override func viewDidLoad() {
  super.viewDidLoad()

  subscription = NSNotificationCenter.defaultCenter().addObserverForName(
    UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
      self?.socket.connect()
  }
}

deinit {
  if let observer = subscription {
    NSNotificationCenter.defaultCenter().removeObserver(observer)
  }
}
```

And, also, since `NSTimer`s retains their targets, it's hardly recommended to call `disconnect` on `deinit`. Disconnecting would invalidate all timers:

```swift
deinit {
  socket.disconnect(0)
}
```

### Token authentication

When creating socket:

```swift
let params = ["token": "abc...", ...]
socket = Socket(url: url, params: params)
```

And in server:

```elixir
def connect(%{"token" => token}, socket) do
  ..
end
```

### Receiving messages

```swift
channel
  // channel connection status
  .onStatusChange { newStatus in ... }
  .on("new:msg") { message in print(message.payload) }
  .on("user:joined") { message in ... }
```

### Sending messages

You can optionally pass message callback if server replies to this message.

```swift
let payload = ["user": "Chuck Norris", "body": "Two seconds till"]
socket.send(channel, event: "new:msg", payload: payload) { res in
  switch res {
    case .Success(let response): // received server response
      switch response { // server replied on handle_in with {:reply, response, socket}
      case .Ok(let payload): // response is {:ok, payload}
      case let .Error(reason, payload): // response is {:error, %{reason: "Good reason"}}
      }
    case .Error(let error): // connection error
  }
}
```

### See demo app

To run demo app:

0. Clone [chrismccord/phoenix_chat_example](https://github.com/chrismccord/phoenix_chat_example) and run it locally.
1. Clone this repo, then `init` and `update` submodules.
2. Open `PhoenixChatDemo/PhoenixChatDemo.xcodeproj` and run it.

## License

PhoenixWebSocket is available under the MIT license. See the LICENSE file for more info.
