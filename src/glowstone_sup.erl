%%%-------------------------------------------------------------------
%%% @author Juan Jose Comellas <juanjo@comellas.org>
%%% @copyright (C) 2012 Juan Jose Comellas
%%% @doc
%%% Supervisor for the Glowstone application.
%%% @end
%%%-------------------------------------------------------------------
-module(glowstone_sup).
-author('Juan Jose Comellas <juanjo@comellas.org>').

-behaviour(supervisor).

%% API
-export([start_link/0]).
-export([start_client/3, stop_client/1]).

%% Supervisor callbacks
-export([init/1]).

-compile([{parse_transform, lager_transform}]).

-define(SERVER, ?MODULE).
%% Helper macro for declaring children of supervisors
-define(WORKER(Id, Module, Args), {Id, {Module, start_link, Args}, transient, 5000, worker, [Module]}).

-type startlink_err()                       :: {'already_started', pid()} | 'shutdown' | term().
-type startlink_ret()                       :: {'ok', pid()} | 'ignore' | {'error', startlink_err()}.
-type start_client_ret()                    :: supervisor:startchild_ret().
-type stop_client_ret()                     :: ok | {error, Reason :: term()}.


-spec start_client(inet:hostname(), inet:port_number(), [glowstone_client:option()]) -> start_client_ret().
start_client(Host, Port, Options) ->
    lager:debug("Starting Glowstone client for ~s:~w~n", [Host, Port]),
    supervisor:start_child(?SERVER, [Host, Port, Options]).

-spec stop_client(pid()) -> stop_client_ret().
stop_client(ClientPid) ->
    lager:debug("Stopping Glowstone client for ~s:~w (pid ~p)~n",
                [glowstone_client:host(ClientPid), glowstone_client:port(ClientPid), ClientPid]),
    supervisor:terminate_child(?SERVER, ClientPid).


-spec start_link() -> startlink_ret().
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init(Args :: term()) -> {ok, {{RestartStrategy :: supervisor:strategy(), MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
                                    [ChildSpec :: supervisor:child_spec()]}}.
init([]) ->
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 30,
    MaxSecondsBetweenRestarts = 60,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {ok, {SupFlags, [
                     ?WORKER(glowstone_client, glowstone_client, [])
                    ]}}.
