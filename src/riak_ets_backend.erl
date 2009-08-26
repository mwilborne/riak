%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at

%%   http://www.apache.org/licenses/LICENSE-2.0

%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.    

% @doc riak_ets_backend is a Riak storage backend using ets.

-module(riak_ets_backend).
-behaviour(gen_server).

-include_lib("eunit/include/eunit.hrl").
-export([start/1,stop/1,get/2,put/3,list/1,list_bucket/2,delete/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

% @type state() = term().
-record(state, {t}).

% @private
simple_test() ->
    {ok,S} = riak_ets_backend:start(42),
    ok = riak_ets_backend:put(S,<<"k1">>,<<"v1">>),
    ok = riak_ets_backend:put(S,<<"k2">>,<<"v2">>),
    {ok,<<"v2">>} = riak_ets_backend:get(S,<<"k2">>),
    [<<"k1">>,<<"k2">>] = lists:sort(riak_ets_backend:list(S)),
    ok = riak_ets_backend:delete(S,<<"k2">>),
    [<<"k1">>] = riak_ets_backend:list(S),
    ok = riak_ets_backend:stop(S).

% @spec start(Partition :: integer()) ->
%                        {ok, state()} | {{error, Reason :: term()}, state()}
start(Partition) ->
    gen_server:start_link(?MODULE, [Partition], []).

%% @private
init([Partition]) ->
    {ok, #state{t=ets:new(list_to_atom(integer_to_list(Partition)),[])}}.

%% @private
handle_cast(_, State) -> {noreply, State}.

%% @private
handle_call(stop,_From,State) -> {reply, srv_stop(State), State};
handle_call({get,BKey},_From,State) -> {reply, srv_get(State,BKey), State};
handle_call({put,BKey,Val},_From,State) ->
    {reply, srv_put(State,BKey,Val),State};
handle_call({delete,BKey},_From,State) -> {reply, srv_delete(State,BKey),State};
handle_call(list,_From,State) -> {reply, srv_list(State), State};
handle_call({list_bucket,Bucket},_From,State) ->
    {reply, srv_list_bucket(State, Bucket), State}.

% @spec stop(state()) -> ok | {error, Reason :: term()}
stop(SrvRef) -> gen_server:call(SrvRef,stop).
srv_stop(State) ->
    case ets:delete(State#state.t) of
        true -> ok;
        Err -> {error, Err}
    end.

% get(state(), Key :: binary()) ->
%   {ok, Val :: binary()} | {error, Reason :: term()}
% key must be 160b
get(SrvRef, BKey) -> gen_server:call(SrvRef,{get,BKey}).
srv_get(State, BKey) ->
    case ets:lookup(State#state.t,BKey) of
        [] -> {error, notfound};
        [{BKey,Val}] -> {ok, Val};
        Err -> {error, Err}
    end.

% put(state(), {B :: atom(), K :: binary()}, Key :: binary(),
%     Val :: binary()) ->
%   ok | {error, Reason :: term()}
% key must be 160b
put(SrvRef, BKey, Val) -> gen_server:call(SrvRef,{put,BKey,Val}).
srv_put(State,BKey,Val) ->
   case ets:insert(State#state.t, {BKey,Val}) of
        true -> ok;
        Err -> {error, Err}
    end.

% delete(state(), Key :: binary()) ->
%   ok | {error, Reason :: term()}
% key must be 160b
delete(SrvRef, BKey) -> gen_server:call(SrvRef,{delete,BKey}).
srv_delete(State, BKey) ->
    case ets:delete(State#state.t, BKey) of
        true -> ok;
        Err -> {error, Err}
    end.

% list(state()) -> [Key :: binary()]
list(SrvRef) -> gen_server:call(SrvRef,list).
srv_list(State) ->
    MList = ets:match(State#state.t,{'$1','_'}),
    list(MList,[]).
list([],Acc) -> Acc;
list([[K]|Rest],Acc) -> list(Rest,[K|Acc]).

% list_bucket(Bucket :: atom(), state()) -> [Key :: binary()]
list_bucket(SrvRef, Bucket) ->
    gen_server:call(SrvRef,{list_bucket, Bucket}).
srv_list_bucket(State, Bucket) ->
    MList = ets:match(State#state.t,{{Bucket,'$1'},'_'}),
    list(MList,[]).

%% @private
handle_info(_Msg, State) -> {noreply, State}.

%% @private
terminate(_Reason, _State) -> ok.

%% @private
code_change(_OldVsn, State, _Extra) -> {ok, State}.
