%%%----------------------------------------------------------------------
%%% File    : ejabberd_hooks.erl
%%% Author  : Alexey Shchepin <alexey@process-one.net>
%%% Purpose : Manage hooks
%%% Created :  8 Aug 2004 by Alexey Shchepin <alexey@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2011   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
%%%
%%%----------------------------------------------------------------------

-module(ejabberd_hooks).
-author('alexey@process-one.net').

-behaviour(gen_server).

%% External exports
-export([start_link/0,
         add/4,
         add/5,
         delete/4,
         delete/5,
         run/2,
         run/3,
         run_fold/3,
         run_fold/4]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         code_change/3,
         handle_info/2,
         terminate/2]).

-export([add/1,
         delete/1]).

-export([error_running_hook/3]).

-include("mongoose.hrl").

-type hook() :: {atom(), jid:server() | global, module(), fun() | atom(), integer()}.

-record(state, {}).

-export_type([hook/0]).

%%%----------------------------------------------------------------------
%%% API
%%%----------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ejabberd_hooks}, ejabberd_hooks, [], []).

%% @doc Add a fun to the given hook.
%% The integer sequence is used to sort the calls:
%% low numbers are executed before high numbers.
-spec add(Hook :: atom(),
          Host :: jid:server() | global,
          Function :: fun() | atom(),
          Seq :: integer()) -> ok.
add(Hook, Host, Function, Seq) when is_function(Function) ->
    add(Hook, Host, undefined, Function, Seq).

%% @doc Add a module and function to the given hook.
%% The integer sequence is used to sort the calls:
%% low numbers are executed before high numbers.
-spec add(Hook :: atom(),
          Host :: jid:server() | global,
          Module :: atom(),
          Function :: fun() | atom(),
          Seq :: integer()) -> ok.
add(Hook, Host, Module, Function, Seq) ->
    gen_server:call(ejabberd_hooks, {add, Hook, Host, Module, Function, Seq}).

-spec add([hook()]) -> ok.
add(Hooks) when is_list(Hooks) ->
    add_or_del(add, Hooks).

-spec add_or_del(add | delete, [hook()]) -> ok.
add_or_del(AddOrDel, Hooks) ->
    [erlang:apply(?MODULE, AddOrDel, tuple_to_list(Hook)) ||
     Hook <- Hooks],
    ok.

%% @doc Delete a module and function from this hook.
%% It is important to indicate exactly the same information than when the call was added.
-spec delete(Hook :: atom(),
             Host :: jid:server() | global,
             Function :: fun() | atom(),
             Seq :: integer()) -> ok.
delete(Hook, Host, Function, Seq) when is_function(Function) ->
    delete(Hook, Host, undefined, Function, Seq).

-spec delete(Hook :: atom(),
             Host :: jid:server() | global,
             Module :: atom(),
             Function :: fun() | atom(),
             Seq :: integer()) -> ok.
delete(Hook, Host, Module, Function, Seq) ->
    gen_server:call(ejabberd_hooks, {delete, Hook, Host, Module, Function, Seq}).

-spec delete([hook()]) -> ok.
delete(Hooks) when is_list(Hooks) ->
    add_or_del(delete, Hooks).

%% @doc Run the calls of this hook in order, don't care about function results.
%% If a call returns stop, no more calls are performed.
-spec run(Hook :: atom(),
          Args :: [any()]) -> ok.
run(Hook, Args) ->
    run(Hook, global, Args).

-spec run(Hook :: atom(),
          Host :: jid:server() | global,
          Args :: [any()]) -> ok.
run(Hook, Host, Args) ->
    %% We don't provide mongoose_acc here because we can't create a valid one.
    run_fold(Hook, Host, ok, Args).

%% @spec (Hook::atom(), Val, Args) -> Val | stopped | NewVal
%% @doc Run the calls of this hook in order.
%% The arguments passed to the function are: [Val | Args].
%% The result of a call is used as Val for the next call.
%% If a call returns 'stop', no more calls are performed and 'stopped' is returned.
%% If a call returns {stop, NewVal}, no more calls are performed and NewVal is returned.
-spec run_fold(Hook :: atom(), Val :: term(), Args :: [term()]) -> term() | stopped.
run_fold(Hook, Val, Args) ->
    run_fold(Hook, global, Val, Args).

-spec run_fold(Hook :: atom(),
               Host :: global | jid:server(),
               Val :: term(),
               Args :: [term()]) ->
    term() | stopped.
run_fold(Hook, Host, Val, Args) ->
    case ets:lookup(hooks, {Hook, Host}) of
        [{_, Ls}] ->
            mongoose_metrics:increment_generic_hook_metric(Host, Hook),
            run_fold1(Ls, Hook, Val, Args);
        [] ->
            Val
    end.

%%%----------------------------------------------------------------------
%%% Callback functions from gen_server
%%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%%----------------------------------------------------------------------
init([]) ->
    ets:new(hooks, [named_table, {read_concurrency, true}]),
    {ok, #state{}}.

%%----------------------------------------------------------------------
%% Func: handle_call/3
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%%----------------------------------------------------------------------
handle_call({add, Hook, Host, Module, Function, Seq}, _From, State) ->
    Reply = case ets:lookup(hooks, {Hook, Host}) of
                [{_, Ls}] ->
                    El = {Seq, Module, Function},
                    case lists:member(El, Ls) of
                        true ->
                            ok;
                        false ->
                            NewLs = lists:merge(Ls, [El]),
                            ets:insert(hooks, {{Hook, Host}, NewLs}),
                            ok
                    end;
                [] ->
                    NewLs = [{Seq, Module, Function}],
                    ets:insert(hooks, {{Hook, Host}, NewLs}),
                    mongoose_metrics:create_generic_hook_metric(Host, Hook),
                    ok
            end,
    {reply, Reply, State};

handle_call({delete, Hook, Host, Module, Function, Seq}, _From, State) ->
    Reply = case ets:lookup(hooks, {Hook, Host}) of
                [{_, Ls}] ->
                    NewLs = lists:delete({Seq, Module, Function}, Ls),
                    ets:insert(hooks, {{Hook, Host}, NewLs}),
                    ok;
                [] ->
                    ok
            end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%----------------------------------------------------------------------
%% Func: handle_cast/2
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%%----------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%----------------------------------------------------------------------
%% Func: handle_info/2
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%%----------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%----------------------------------------------------------------------
%% Func: terminate/2
%% Purpose: Shutdown the server
%% Returns: any (ignored by gen_server)
%%----------------------------------------------------------------------
terminate(_Reason, _State) ->
    ets:delete(hooks),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%----------------------------------------------------------------------
%%% Internal functions
%%%----------------------------------------------------------------------

run_fold1([], _Hook, Val, _Args) ->
    Val;
run_fold1([{_Seq, Module, Function} | Ls], Hook, Val, Args) ->
    Res = hook_apply_function(Module, Function, Val, Args),
    case Res of
        {'EXIT', Reason} ->
            error_running_hook(Reason, Hook, Args),
            run_fold1(Ls, Hook, Val, Args);
        stop ->
            stopped;
        {stop, NewVal} ->
            NewVal;
        NewVal ->
            run_fold1(Ls, Hook, NewVal, Args)
    end.

hook_apply_function(_Module, Function, Val, Args) when is_function(Function) ->
    safely:apply(Function, [Val | Args]);
hook_apply_function(Module, Function, Val, Args) ->
    safely:apply(Module, Function, [Val | Args]).

error_running_hook(Reason, Hook, Args) ->
    ?LOG_ERROR(#{what => hook_failed,
                 text => <<"Error running hook">>,
                 hook => Hook, args => Args, reason => Reason}).
