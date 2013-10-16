%%%-------------------------------------------------------------------
%%% @author Juan Jose Comellas <juanjo@comellas.org>
%%% @copyright (C) 2012 Juan Jose Comellas
%%% @doc
%%% Minecraft status client.
%%% @end
%%%-------------------------------------------------------------------
-module(glowstone_client).
-author('Juan Jose Comellas <juanjo@comellas.org>').

-behaviour(gen_server).

%% API
-export([start_link/3]).
-export([host/1, port/1,
         motd/1, game_type/1, game_name/1, version/1, plugins/1, map_name/1,
         num_players/1, max_players/1, players/1, last_update/1]).
-export([status/1, refresh/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export_type([option/0]).

-compile([{parse_transform, lager_transform}]).

-include_lib("kernel/include/inet.hrl").

-define(MAGIC_BYTE_1, 16#FE).
-define(MAGIC_BYTE_2, 16#FD).
-define(PACKET_TYPE_CHALLENGE, 16#09).
-define(PACKET_TYPE_QUERY, 16#00).
-define(CLIENT_ID, <<"glow">>).
-define(SOCKET_TIMEOUT, 3000).  %% 3 seconds
-define(BUFSIZE, 2048).
-define(PORT, 25565).

-type server_ref()                                            :: pid().
-type option()                                                :: {timeout, timeout()}.

-record(status, {
          motd                                                :: binary(),
          game_type                                           :: binary(),
          game_name                                           :: binary(),
          version                                             :: binary(),
          plugins                                             :: [binary()],
          map_name                                            :: binary(),
          num_players = 0                                     :: non_neg_integer(),
          max_players = 0                                     :: non_neg_integer(),
          players = []                                        :: [binary()],
          last_update                                         :: calendar:datetime()
         }).

-record(state, {
          host = erlang:error({required, host})               :: inet:hostname(),
          port = erlang:error({required, port})               :: inet:port_number(),
          socket                                              :: inet:socket(),
          ip_addr                                             :: inet:ip_address(),
          timeout                                             :: timeout(),
          session_id                                          :: binary(),
          status = #status{}                                  :: #status{},
          plugins_split_regex                                 :: re:mp()
         }).


%%%===================================================================
%%% API
%%%===================================================================

%% @doc
%% Starts the server
-spec start_link(inet:hostname(), inet:port_number(), [option()]) ->
                        {ok, pid()} | ignore | {error, Reason :: term()}.
start_link(Host, Port, Options) ->
    gen_server:start_link(?MODULE, [Host, Port, Options], []).

-spec host(server_ref()) -> inet:hostname().
host(ServerRef) ->
    gen_server:call(ServerRef, host).

-spec port(server_ref()) -> inet:port_number().
port(ServerRef) ->
    gen_server:call(ServerRef, port).

-spec motd(server_ref()) -> binary().
motd(ServerRef) ->
    gen_server:call(ServerRef, motd).

-spec game_type(server_ref()) -> binary().
game_type(ServerRef) ->
    gen_server:call(ServerRef, game_type).

-spec game_name(server_ref()) -> binary().
game_name(ServerRef) ->
    gen_server:call(ServerRef, game_name).

-spec version(server_ref()) -> binary().
version(ServerRef) ->
    gen_server:call(ServerRef, version).

-spec plugins(server_ref()) -> [binary()].
plugins(ServerRef) ->
    gen_server:call(ServerRef, plugins).

-spec map_name(server_ref()) -> binary().
map_name(ServerRef) ->
    gen_server:call(ServerRef, map_name).

-spec num_players(server_ref()) -> non_neg_integer().
num_players(ServerRef) ->
    gen_server:call(ServerRef, num_players).

-spec max_players(server_ref()) -> non_neg_integer().
max_players(ServerRef) ->
    gen_server:call(ServerRef, max_players).

-spec players(server_ref()) -> [binary()].
players(ServerRef) ->
    gen_server:call(ServerRef, players).

-spec last_update(server_ref()) -> calendar:datetime().
last_update(ServerRef) ->
    gen_server:call(ServerRef, last_update).

-spec status(server_ref()) -> proplists:proplist().
status(ServerRef) ->
    gen_server:call(ServerRef, status).

-spec refresh(server_ref()) -> ok | {error, Reason :: term()}.
refresh(ServerRef) ->
    gen_server:call(ServerRef, refresh).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
%% @doc Initializes the client socket
-spec init(Args :: list()) -> {ok, #state{}, timeout()} | {stop, Reason :: term()}.
init([Host, Port, Options]) ->
    case gen_udp:open(0, [{active, false}, binary]) of
        {ok, Socket} ->
            {ok, PluginsSplitRegex} = re:compile(<<";\\s*">>),
            State = #state{
                       host = Host,
                       port = Port,
                       socket = Socket,
                       timeout = proplists:get_value(timeout, Options, ?SOCKET_TIMEOUT),
                       plugins_split_regex = PluginsSplitRegex
                      },
            %% Asynchronously perform the DNS lookup
            {ok, State, 0};
        {error, Reason} ->
            {stop, Reason}
    end.


%% @private
%% @doc Handle call messages
-spec handle_call(Request :: term(), From :: term(), #state{}) -> {reply, Reply :: term(), #state{}}.
handle_call(host, _From, State) ->
    {reply, State#state.host, State};
handle_call(port, _From, State) ->
    {reply, State#state.port, State};
handle_call(motd, _From, #state{status = Status} = State) ->
    {reply, Status#status.motd, State};
handle_call(game_type, _From, #state{status = Status} = State) ->
    {reply, Status#status.game_type, State};
handle_call(game_name, _From, #state{status = Status} = State) ->
    {reply, Status#status.game_name, State};
handle_call(version, _From, #state{status = Status} = State) ->
    {reply, Status#status.version, State};
handle_call(plugins, _From, #state{status = Status} = State) ->
    {reply, Status#status.plugins, State};
handle_call(map_name, _From, #state{status = Status} = State) ->
    {reply, Status#status.map_name, State};
handle_call(num_players, _From, #state{status = Status} = State) ->
    {reply, Status#status.num_players, State};
handle_call(max_players, _From, #state{status = Status} = State) ->
    {reply, Status#status.max_players, State};
handle_call(players, _From, #state{status = Status} = State) ->
    {reply, Status#status.players, State};
handle_call(last_update, _From, #state{status = Status} = State) ->
    {reply, Status#status.last_update, State};
handle_call(status, _From, #state{status = Status} = State) ->
    Reply = [{motd, Status#status.motd},
             {game_type, Status#status.game_type},
             {game_name, Status#status.game_name},
             {version, Status#status.version},
             {plugins, Status#status.plugins},
             {map_name, Status#status.map_name},
             {num_players, Status#status.num_players},
             {max_players, Status#status.max_players},
             {players, Status#status.players},
             {last_update, Status#status.last_update}],
    {reply, Reply, State};
handle_call(refresh, _From, State) ->
    case refresh_internal(State) of
        {ok, {SessionId, Status}} ->
            {reply, ok, State#state{session_id = SessionId, status = Status}};
        Error ->
            {reply, Error, State}
    end;
handle_call(Request, _From, State) ->
    Reply = {error, {not_implemented, Request}},
    {reply, Reply, State}.


%% @private
%% @doc Handle cast messages.
-spec handle_cast(Msg :: term(), #state{}) -> {noreply, #state{}}.
handle_cast(_Msg, State) ->
    {noreply, State}.


%% @private
%% @doc Handle all non call/cast messages.
-spec handle_info(Info :: term(), #state{}) -> {noreply, #state{}} | {noreply, #state{}, timeout()} |
                                               {stop, Reason :: term(), #state{}}.
handle_info(timeout, #state{host = Host} = State0) ->
    case inet:gethostbyname(Host) of
        %% Use the first one of the IP addresses the host name resolves to
        {ok, #hostent{h_addr_list = [IpAddr | _Tail]}} ->
            lager:debug("Resolved UDP host name '~s' to ~p~n", [Host, IpAddr]),
            State = State0#state{ip_addr = IpAddr},
            case refresh_internal(State) of
                {ok, {SessionId, Status}} ->
                    {noreply, State#state{
                                session_id = SessionId,
                                status = Status
                               }};
                {error, Reason} ->
                    lager:warning("Could not refresh the status for host '~s': ~p~n", [Host, Reason]),
                    {stop, Reason, State}
            end;
        {error, Reason} ->
            lager:warning("Could not resolve UDP host name '~s': ~p~n", [Host, Reason]),
            {stop, Reason, State0}
    end;
handle_info(_Info, State) ->
    lager:debug("Unexpected message received in ~s: ~p~n", [?MODULE, _Info]),
    {noreply, State}.


%% @private
%% @doc This function is called by a gen_server when it is about to
%%      terminate. It should be the opposite of Module:init/1 and do any
%%      necessary cleaning up. When it returns, the gen_server terminates
%%      with Reason. The return value is ignored.
-spec terminate(Reason :: term(), #state{}) -> term().
terminate(_Reason, _State) ->
    ok.


%% @private
%% @doc Convert process state when code is changed.
-spec code_change(OldVsn :: term(), #state{}, Extra :: term()) -> {ok, NewState :: #state{}}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.



%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec handshake(#state{}) -> {ok, SessionId :: binary()} | {error, Reason :: term()}.
handshake(State) ->
    Req = [?MAGIC_BYTE_1, ?MAGIC_BYTE_2, ?PACKET_TYPE_CHALLENGE, ?CLIENT_ID],
    case perform_request(Req, State) of
        {ok, <<?PACKET_TYPE_CHALLENGE, _ClientId:4/binary, Rest/binary>>}  ->
            %% the challenge token comes back as a NULL-terminated string that represents
            %% the integer we want, so we have to convert it to the actual 32 bit integer.
            SessionId = bin2int(binary_part(Rest, 0, byte_size(Rest) - 1)),
            lager:debug("Received session ID ~w from ~s:~w~n",
                        [SessionId, State#state.host, State#state.port]),
            {ok, SessionId};
        {ok, InvalidResponse} ->
            lager:warning("Received invalid response to challenge from ~s:~w: ~p~n",
                          [State#state.host, State#state.port, InvalidResponse]),
            {error, {invalid_challenge_response, InvalidResponse}};
        {error, _Reason} = Error ->
            lager:warning("Could not retrieve session ID from ~s:~w: ~p~n",
                          [State#state.host, State#state.port, _Reason]),
            Error
    end.


-spec refresh_internal(#state{}) -> {ok, {SessionId :: non_neg_integer(), #status{}}} | {error, Reason :: term()}.
refresh_internal(State) ->
    case handshake(State) of
        {ok, SessionId} ->
            Req = [?MAGIC_BYTE_1, ?MAGIC_BYTE_2, ?PACKET_TYPE_QUERY, ?CLIENT_ID,
                   <<SessionId:32/big-unsigned-integer>>, ?CLIENT_ID],
            lager:debug("Sending query to ~s:~w (session ID ~w): ~p~n",
                        [State#state.host, State#state.port, SessionId, Req]),
            case perform_request(Req, State) of
                {ok, Resp}  ->
                    %% lager:debug("Received response from ~s:~w (session ID ~w): ~p~n",
                    %%             [State#state.host, State#state.port, SessionId, Resp]),
                    case decode_status_packet(Resp) of
                        {ok, {Packet, _Rest}} ->
                            Plugins = proplists:get_value(plugins, Packet),
                            {ok, {SessionId,
                                  #status{
                                     motd         = proplists:get_value(motd, Packet),
                                     game_type    = proplists:get_value(game_type, Packet),
                                     game_name    = proplists:get_value(game_name, Packet),
                                     version      = proplists:get_value(version, Packet),
                                     plugins      = re:split(Plugins, State#state.plugins_split_regex),
                                     map_name     = proplists:get_value(map_name, Packet),
                                     num_players  = bin2int(proplists:get_value(num_players, Packet)),
                                     max_players  = bin2int(proplists:get_value(max_players, Packet)),
                                     players      = proplists:get_value(players, Packet),
                                     last_update  = calendar:universal_time()
                                    }}};
                        {error, _Reason} = Error ->
                            lager:warning("Could not decode response from ~s:~w: ~p~n",
                                          [State#state.host, State#state.port, _Reason]),
                            Error
                    end;
                {error, _Reason} = Error ->
                    Error
            end;
        {error, _Reason} = Error ->
            Error
    end.


-spec perform_request(Request :: iolist(), #state{}) -> {ok, Response :: binary()} | {error, Reason :: term()}.
perform_request(Req, #state{ip_addr = IpAddr, port = Port, socket = Socket} = State) ->
    case gen_udp:send(Socket, IpAddr, Port, Req) of
        ok ->
            case gen_udp:recv(Socket, ?BUFSIZE, State#state.timeout) of
                {ok, {IpAddr, Port, Resp}} ->
                    {ok, Resp};
                {error, _Reason} = Error ->
                    lager:warning("Failed to receive UDP response from ~s:~w: ~p~n",
                                  [State#state.host, Port, _Reason]),
                    Error
            end;
        {error, _Reason} = Error ->
            lager:warning("Failed to send UDP request to ~s:~w: ~p~n",
                          [State#state.host, Port, _Reason]),
            Error
    end.


decode_status_packet(Buffer) ->
    %% These fields were present in the document:
    %% http://dinnerbone.com/blog/2011/10/14/minecraft-19-has-rcon-and-query/
    StatusPacketSpec =
        [
         {request_type,    int8},
         {client_id,       {string, 4}},
         {skip, 9},                        %% "splitnum\0"
         {world_height,    uint8},         %% UNKNOWN - hardcoded "128". (world-height?)
         {skip, 10},                       %% "\0hostname\0"
         {motd,            stringz},
         {skip, 9},                        %% "gametype\0"
         {game_type,       stringz},
         {skip, 8},                        %% "game_id\0"
         {game_name,       stringz},       %% "MINECRAFT\0"
         {skip, 8},                        %% "version\0"
         {version,         stringz},
         {skip, 8},                        %% "plugins\0"
         {plugins,         stringz},
         {skip, 4},                        %% "map\0"
         {map_name,        stringz},
         {skip, 11},                       %% "numplayers\0"
         {num_players,     stringz},
         {skip, 11},                       %% "maxplayers\0"
         {max_players,     stringz},
         {skip, 9},                        %% "hostport\0"
         {port,            stringz},
         {skip, 9},                        %% hardcoded "hostname\0"
         {host,            stringz},
         {skip, 1},                        %% UNKNOWN - hardcoded "0".
         {skip, 1},                        %% UNKNOWN - hardcoded "1".
         {dummy1,          stringz},       %% hardcoded "player_\0"
         {skip, 1},
         {players,         {array, stringz, fun num_players_from_status/1}}
        ],
    decode_record(StatusPacketSpec, Buffer).


-spec num_players_from_status(Packet :: list()) -> non_neg_integer().
num_players_from_status(Packet) ->
    case lists:keyfind(num_players, 1, Packet) of
        {num_players, NumPlayers} when is_binary(NumPlayers) ->
            bin2int(NumPlayers);
        false ->
            0
    end.


-type bindata_type() :: int8 | uint8 | stringz | {string, Length :: non_neg_integer()} |
                        {array, bindata_type(), non_neg_integer() | fun()} |
                        {skip, Length :: non_neg_integer()}.

-spec decode_record([{FieldName :: atom(), bindata_type()}], Buffer :: binary()) ->
                           {ok, {Record :: proplists:proplist(), Rest :: binary()}} | {error, Reason :: term()}.
decode_record(Spec, Buffer) ->
    decode_record(Spec, Buffer, []).

decode_record([{skip, Length} = Skip | Tail], Buffer, Acc) when is_integer(Length) ->
    case decode_field(Skip, Acc, Buffer) of
        {skipped, Rest}          -> decode_record(Tail, Rest, Acc);
        undefined                -> {error, {skip_failed, Skip}};
        {error, _Reason} = Error -> Error
    end;
decode_record([{FieldName, Type} = Field | Tail], Buffer, Acc) ->
    case decode_field(Type, Acc, Buffer) of
        {ok, {Value, Rest}}      ->
            %% lager:debug("Decoded field '~s': ~p~n", [FieldName, Value]),
            decode_record(Tail, Rest, [{FieldName, Value} | Acc]);
        undefined                -> {error, {field_not_found, Field}};
        {error, _Reason} = Error -> Error
    end;
decode_record([], Buffer, Acc) ->
    {ok, {lists:reverse(Acc), Buffer}}.


-spec decode_field(bindata_type(), Record :: proplists:proplist(), Buffer :: binary()) ->
                          {Value :: term(), Rest :: binary()} | undefined | {error, Reason :: term()}.
decode_field({string, Length}, _Record, Buffer) ->
    case Buffer of
        <<String:Length/binary, Rest/binary>> -> {ok, {String, Rest}};
        _                                     -> undefined
    end;
decode_field(stringz, _Record, Buffer) ->
    decode_stringz(Buffer);
decode_field(int8, _Record, <<Int8/signed, Buffer/binary>>) ->
    {ok, {Int8, Buffer}};
decode_field(uint8, _Record, <<UInt8/unsigned, Buffer/binary>>) ->
    {ok, {UInt8, Buffer}};
decode_field(int16be, _Record, <<Int16:16/big-signed-integer, Buffer/binary>>) ->
    {ok, {Int16, Buffer}};
decode_field(uint16be, _Record, <<UInt16:16/big-unsigned-integer, Buffer/binary>>) ->
    {ok, {UInt16, Buffer}};
decode_field(int16le, _Record, <<Int16:16/little-signed-integer, Buffer/binary>>) ->
    {ok, {Int16, Buffer}};
decode_field(uint16le, _Record, <<UInt16:16/little-unsigned-integer, Buffer/binary>>) ->
    {ok, {UInt16, Buffer}};
decode_field(int32be, _Record, <<Int32:32/big-signed-integer, Buffer/binary>>) ->
    {ok, {Int32, Buffer}};
decode_field(uint32be, _Record, <<UInt32:32/big-unsigned-integer, Buffer/binary>>) ->
    {ok, {UInt32, Buffer}};
decode_field(int32le, _Record, <<Int32:32/little-signed-integer, Buffer/binary>>) ->
    {ok, {Int32, Buffer}};
decode_field(uint32le, _Record, <<UInt32:32/little-unsigned-integer, Buffer/binary>>) ->
    {ok, {UInt32, Buffer}};
decode_field({array, Type, Fun}, Record, Buffer) when is_function(Fun) ->
    decode_array(Type, Fun(Record), Buffer);
decode_field({array, Type, Count}, _Record, Buffer) ->
    decode_array(Type, Count, Buffer);
decode_field({skip, Length}, _Record, Buffer) ->
    case Buffer of
        <<_Skipped:Length/binary, Rest/binary>> -> {skipped, Rest};
        _                                       -> undefined
    end;
decode_field(_Type, _Record, <<>>) ->
    undefined;
decode_field(Type, _Record, _Buffer) ->
    {error, {invalid_type, Type}}.


-spec decode_stringz(Buffer :: binary()) -> {ok, {Stringz :: binary(), Rest :: binary()}} | undefined.
decode_stringz(Buffer) ->
    decode_stringz(Buffer, <<>>).

decode_stringz(<<0, Rest/binary>>, Acc) ->
    {ok, {Acc, Rest}};
decode_stringz(<<Char, Rest/binary>>, Acc) ->
    AccLen = byte_size(Acc),
    decode_stringz(Rest, <<Acc:AccLen/binary, Char>>);
decode_stringz(<<>>, _Acc) ->
    undefined.


-spec decode_array(bindata_type(), Count :: non_neg_integer(), Buffer :: binary()) ->
                          {ok, {[bindata_type()], Rest :: binary()}} | undefined.
decode_array(Type, Count, Buffer) ->
    decode_array(Type, Count, Buffer, []).

decode_array(Type, Count, Buffer, Acc) when Count > 0 ->
    case decode_field(Type, [], Buffer) of
        {ok, {Value, Rest}} ->
            decode_array(Type, Count - 1, Rest, [Value | Acc]);
        {skipped, Rest} ->
            decode_array(Type, Count - 1, Rest, Acc);
        undefined ->
            undefined
    end;
decode_array(_Type, _Count, Buffer, Acc) ->
    {ok, {lists:reverse(Acc), Buffer}}.


-spec bin2int(binary()) -> integer().
bin2int(Bin) ->
    list_to_integer(binary_to_list(Bin)).
