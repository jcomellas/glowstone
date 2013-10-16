%%%-------------------------------------------------------------------
%%% @author Juan Jose Comellas <juanjo@comellas.org>
%%% @copyright (C) 2012 Juan Jose Comellas
%%% @doc
%%% Main module for the Glowstone application.
%%% @end
%%%-------------------------------------------------------------------
-module(glowstone).
-author('Juan Jose Comellas <juanjo@comellas.org>').

-export([start/0, stop/0]).
-export([get_env/0, get_env/1, get_env/2, set_env/2]).
-export([start_client/3, stop_client/1]).
-export([status/1, refresh/1]).

-compile([{parse_transform, lager_transform}]).

-define(APP, glowstone).


%% @doc Start the application and all its dependencies.
-spec start() -> ok.
start() ->
    start_deps(?APP).

%% @doc Stop the application and all its dependencies.
-spec stop() -> ok.
stop() ->
    stop_deps(?APP).

%% @doc Retrieve all key/value pairs in the env for the specified app.
-spec get_env() -> [{Key :: atom(), Value :: term()}].
get_env() ->
    application:get_all_env(?APP).

%% @doc The official way to get a value from the app's env.
%%      Will return the 'undefined' atom if that key is unset.
-spec get_env(Key :: atom()) -> term().
get_env(Key) ->
    get_env(Key, undefined).

%% @doc The official way to get a value from this application's env.
%%      Will return Default if that key is unset.
-spec get_env(Key :: atom(), Default :: term()) -> term().
get_env(Key, Default) ->
    case application:get_env(?APP, Key) of
        {ok, Value} ->
            Value;
        _ ->
            Default
    end.

%% @doc Sets the value of the configuration parameter Key for this application.
-spec set_env(Key :: atom(), Value :: term()) -> ok.
set_env(Key, Value) ->
    application:set_env(?APP, Key, Value).

-spec start_deps(App :: atom()) -> ok.
start_deps(App) ->
    application:load(App),
    {ok, Deps} = application:get_key(App, applications),
    lists:foreach(fun start_deps/1, Deps),
    start_app(App).

-spec start_app(App :: atom()) -> ok.
start_app(App) ->
    case application:start(App) of
        {error, {already_started, _}} -> ok;
        ok                            -> ok
    end.

-spec stop_deps(App :: atom()) -> ok.
stop_deps(App) ->
    stop_app(App),
    {ok, Deps} = application:get_key(App, applications),
    lists:foreach(fun stop_deps/1, lists:reverse(Deps)).

-spec stop_app(App :: atom()) -> ok.
stop_app(kernel) ->
    ok;
stop_app(stdlib) ->
    ok;
stop_app(App) ->
    case application:stop(App) of
        {error, {not_started, _}} -> ok;
        ok                        -> ok
    end.


-spec start_client(inet:hostname(), inet:port_number(), [glowstone_client:option()]) -> glowstone_sup:start_client_ret().
start_client(Host, Port, Options) ->
    glowstone_sup:start_client(Host, Port, Options).


-spec stop_client(ClientPid :: pid()) -> glowstone_sup:stop_client_ret().
stop_client(ClientPid) ->
    glowstone_sup:stop_client(ClientPid).


-spec status(ClientPid :: pid()) -> proplists:proplist().
status(ClientPid) ->
    glowstone_client:status(ClientPid).


-spec refresh(ClientPid :: pid()) -> ok | {error, Reason :: term()}.
refresh(ClientPid) ->
    glowstone_client:refresh(ClientPid).
