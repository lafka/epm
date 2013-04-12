-module(epm_utils).

%% Parts of code (cmd/2, mktemp and temp_name) are copied from Klarna AB
%% and are licensed under the term of Apache License, Version 2.0.
%% The original work can be found @ https://github.com/klarna/tulib/blob/master/src/tulib_sh.erl
%% Full Apache license can be found at https://www.apache.org/licenses/LICENSE-2.0

-export([
	  debug/1
	, debug/2
	, info/1
	, info/2
	, err/1
	, err/2
	]).

-export([
	  cmd/1
	, cmd/2
	]).

-export([
	  save_cache/2
	, load_cache/1
	, cache_path/1
	, mktemp/0
	, mktemp/1
	, mktemp/2
	, temp_name/1
	, temp_name/2
	]).

-export([
	  get_domain/1
	]).

-export([
	  binjoin/2
	]).

-define(format(Type, Msg, Args),
	{_, {H, M, S}} = erlang:universaltime(),
	io:format("[~s] ~b:~b:~b -> " ++ Msg ++ "~n", [Type, H, M, S] ++ Args)).

-define(cache(File), binary_to_list(<<".cache/", File/binary>>)).

info(Msg) ->
	info(Msg, []).

info(Msg, Args) ->
	?format(info, Msg, Args).

debug(Msg) ->
	debug(Msg, []).

debug(Msg, Args) ->
	?format(debug, Msg, Args).

err(Msg) ->
	err(Msg, []).

err(Msg, Args) ->
	?format(error, Msg, Args).

-spec cmd(iolist()) -> {ok, Out} | {error, {non_neg_integer(), Out}}
	when Out :: string().
cmd(Cmd) ->
	cmd(Cmd, []).

-spec cmd(iolist(), [term()]) -> {ok, Out} | {error, {non_neg_integer(), Out}}
	when Out :: string().
cmd(Cmd, Args) ->
	File = mktemp("epm-eval"),
	Cmd2 = io_lib:format(Cmd, Args),
	Cmd3 = io_lib:format("~s > ~s 2>&1; echo $?", [Cmd2, File]),
	debug("+ ~s", [Cmd3]),
	{Status, "\n"} = string:to_integer(os:cmd(Cmd3)),
	{ok, Output0} = file:read_file(File),
	Output = binary_to_list(Output0),
	case Status of
		0 -> {ok, Output0};
		N -> {error, {N, Output}}
	end.

mktemp() ->
	mktemp(mktemp).
mktemp(Prefix) ->
	mktemp(Prefix, "/tmp").
mktemp(Prefix, Dir) ->
	File     = temp_name(Dir, Prefix),
	filelib:ensure_dir(File),
	{ok, FD} = file:open(File, [write, exclusive]),
	ok       = file:close(FD),
	File.

temp_name(Dir, "") -> temp_name(Dir ++ "/");
temp_name(Dir, Prefix) -> temp_name(filename:join(Dir, Prefix)).
temp_name(Stem) ->
	filename:join(Stem
		, integer_to_list(crypto:rand_uniform(0, 1 bsl 127))).

save_cache(Resource, Payload) ->
	File = ?cache(Resource),
	debug("save cache: ~s", [File]),
	Data = term_to_binary(Payload),
	filelib:ensure_dir(File),
	file:write_file(File, Data).

load_cache(Resource) ->
	File = ?cache(Resource),
	debug("lookup cache: ~s", [File]),
	case filelib:is_file(File) of
		true ->
			{ok, Data} = file:read_file(File),
			{ok, binary_to_term(Data)};
		false ->
			false
	end.

cache_path(Resource) ->
	?cache(Resource).

get_domain(Resource) ->
	URL = case binary:split(Resource, <<"://">>) of
		[_, P1] -> P1;
		[P1] -> P1 end,
	[Domain|_] = binary:split(URL, <<$/>>),
	Domain.

binjoin(BinList, Sep) when is_list(BinList), is_binary(Sep) ->
	lists:foldr(
		  fun(A,<<>>) -> <<A/binary>>;
		     (A,B)    -> <<A/binary, Sep/binary, B/binary>> end
		, <<>>
		, BinList).

