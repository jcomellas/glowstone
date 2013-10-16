%%%-------------------------------------------------------------------
%%% @author Juan Jose Comellas <juanjo@comellas.org>
%%% @copyright (C) 2012 Juan Jose Comellas
%%% @doc
%%% Application that queries a Minecraft server status
%%% @end
%%%-------------------------------------------------------------------
-module(glowstone_app).
-author('Juan Jose Comellas <juanjo@comellas.org>').

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

-spec start(StartType :: normal | {takeover, node()} | {failover, node()}, StartArgs :: [term()]) -> {ok, pid()}.
start(_StartType, _StartArgs) ->
    glowstone_sup:start_link().

-spec stop(any()) -> ok.
stop(_State) ->
    ok.
