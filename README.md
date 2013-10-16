# Glowstone for Erlang

This project is a proof-of-concept port of
[Tom Heinan's Ruby Glowstone project](https://github.com/tomheinan/glowstone)
in Erlang. Here's a redacted version of his original README file.

This module implements the [GameSpy query protocol](http://int64.org/docs/gamestat-protocols/gamespy2.html)
to access pertinent real-time information hidden away inside your Minecraft
server. You give Glowstone your server info, and Glowstone gives you:
- which players are currently online
- the base map name and default gamemode
- what plugins you're running
- even more stuff you probably don't care about!

All credit goes to [Dinnerbone](http://dinnerbone.com/) for his
[excellent post](http://dinnerbone.com/blog/2011/10/14/minecraft-19-has-rcon-and-query/)
on the inner workings of the protocol. Check out his Python implementation
[here](https://github.com/Dinnerbone/mcstatus).


## Requirements

You should only need a somewhat recent version of Erlang/OTP. The module has
been tested with Erlang R15B and R16B.

You also need a recent version of [rebar](http://github.com/rebar/rebar) in
the system path.


## Installation

Run the following commands to checkout, retrieve the dependencies and compile
the project:

    git clone https://github.com/jcomellas/glowstone.git
    cd glowstone
    rebar get-deps compile


## Usage

Glowstone's interface is super simple. Just start the application and a client
(with the host name and port the server is listening on):
```erlang
glowstone:start().
{ok, Pid} = glowstone:start_client("minecraft.example.com", 25565, [{timeout, 10000}]).
```
And Glowstone will whip you up a process full of all that delicious realtime
data you've been craving:
```erlang
glowstone:status(Pid).
[{motd,<<"Welcome to Arkenfall!">>},
 {game_type,<<"SMP">>},
 {game_name,<<"MINECRAFT">>},
 {version,<<"1.6.4">>},
 {plugins,[<<"CraftBukkit on Bukkit 1.6.4-R0.1-SNAPSHOT: AdminCmd 7.3.5 (BUILD 06.04.2013 @ 18:26:"...>>,
           <<"Vault 1.2.25-b320">>,<<"WorldEdit 5.5.7">>,
           <<"TreeAssist 5.4.2">>,<<"WorldGuard 5.7.5">>,
           <<"PlayerMarkers 0.2.0">>,<<"PermissionsBukkit 2.0">>,
           <<"SimpleSpleef 3.4.2">>]},
 {map_name,<<"arkenfall">>},
 {num_players,0},
 {max_players,16},
 {players,[]},
 {last_update,{{2013,10,16},{18,46,4}}}]
```

And that's all there is to it! No fancy bukkit plugins or server-side scripts
required. If your process is particularly long-lived and you find yourself
wanting to refresh its data, just do `glowstone:refresh(Pid)` and it'll pull
down the latest information for you.


## Troubleshooting

**Help! I'm not receiving any data!**

The first thing to do is make sure your server is set up to send it.  Check
your `server.properties` file and make sure the `enable-query` flag is set to
`true`. Then, make sure your server's firewall allows connections on UDP port
`25565`.  If you've changed that value via the `query.port` flag, then you'll
also need to specify it when instantiating Glowstone, like so:
```erlang
{ok, Pid} = glowstone:start_client("myminecraftserver.com", 25565, []).
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
