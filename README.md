# Deprecation

Mix, Rebar and Erlang.mk does a much better job. This is no longer maintained.


# NOTE:

This project is in the process of being renamed to edam. Please check
out branch 0.3.0 ( https://github.com/lafka/edam/tree/0.3.0 ) for most
up-to-date code/info etc.

# Introduction

Todays state of erlang dependency manager is not optimal.
EPM was designed to handle dependencies in more controlled way.

+ https://hyperthunk.wordpress.com/2012/05/28/does-erlangotp-need-a-new-package-management-solution/
+ http://lists.basho.com/pipermail/riak-users_lists.basho.com/2013-April/011777.html
+ http://erlang.org/pipermail/erlang-questions/2012-October/069825.html

## Features:

+ Drop-in replacement for Rebar dependency management
+ Isolated dependencies pr. project
+ Deterministic checkout, no need to deps at specific position in config
+ Modular codebase with hooks for most common operations
+ Supports remote catalogs for simplifying dependency management

## Features coming to you soon:

+ Compiles to single binary without requirement for erlang (maybe?)
+ Release signing / key trust for packages
+ Isolated checkout, dependency will checkout required deps on it's
  own. Good when building multiple different applications


### Needs hacking:

#### Misc
+ Add logging for side-effects (e.g. "moved from _ref-A_ to _ref-B_")

#### Parsing
+ Add a `facts` to provide default options like libdir, append_versions (config is always parsed for deps, but facts are only processed for isolate/root pkgs)
+ Add async operations for checkout and friends, build 'action list' returned
  by parse/{0,1} which should define operations required for fixing
  consistency errors before main operation can process (<- think twice)
+ `epm_parser_epm` must use `<<` append operation to work
+ Dependencies are only allowed to override local catalogs (related to ^?)
+ Allow for appending information to a pkg by path or by name:
	`~meck =0.7.2 #0.7.2` will set version and ref of meck to 0.7.2
	`~[riakc, _, meck] =0.7.2 #master` will set any meck versions found
	under riakc to 0.7.2 but still use the master branch. This allows
	for tricking EPM do belive you are running the same version of the
	code.
+ Keep a list of synced repositores to avoid multiple syncs

#### Checkout
+ Make libdir/append_versions pkg specific (in config).
+ Fix automatic catalog selection AND catalog priority
+ If no version is specified, epm_pkg should find the version
  specified by the .app file, preferably with a symlink (if none exits)
+ Cleanout non-referenced directories
+ When checking updating GIT repo that has been rewritten, merge
  conflict will happend?
+ Validate that dependencies that change GIT remote gets propagated to
  config
+ When cache directory change, propegate update to lib/\_ aswell.
+ Calculate all referenced directories and delete non needed in .cache
  and lib/

#### Performance
+ Flatten and merge deps list before iterating

##### Conflicts
+ Find and warn about packages with version conflicts.
 + Add flag  to ignore one or more specific conflicts (`--ignore meck`
   or `--ignore-all`)
+ Find and warn about auto configured packages with multiple available catalogs?

# Various resolve functionality
+ Fix cache expiry of github catalogs
+ Add HTTP agent
+ Add local agent
+ Add gitorious catalog
+ Add bitbuck catalog
+ Add localfs catalog
+ Add search functionality to github catalog


## Catalogs

All `packages` resides within 1 catalog, the catalog is managed by a
developer or an organization. Catalogs contains a list of `packages`
and additionally a set of keys used for signing (not implemented).

Catalogs must export these functions:

```
name/0 :: binary()
Unique name used for path generation
```

```
match/1 :: (binary()) -> boolean()
Match function determining if a resource belongs to the catalog.
```

```
resource/2 :: (#pkg{}, #ctl{}) -> URL :: binary()
Build a URL used for fetching remote
```

```
fetch/1 :: (A :: binary()) -> #catalog{}
Fetches list of packages from remote server
```

```
search/1 :: (A :: binary()) -> [#pkg{}]
Search the remote catalog for package, returns a list of matching
packages.
```

```
sync/1 :: (Resource :: binary(), _) -> boolean()
Syncs a package to the local store. The second argument is reserved
for `source handler` hinting.
```

## Packages

A remote resource containing some source code. Once synced additional
information can be retrieved, mainly the version number and a list of
additional dependencies. This information is stored in one or more
configuration files (ie. `rebar.config` and `*.app`).

## Parsers

To be able to handle a multitude of configuration variants several
parsers are bundled with EPM. Each parser acts as an adapter to other
build tools/package managers.

A parser must export the following functions:

```
parse/2 :: (file:filename(), epm_pkg:pkg()) ->
	{ok, Cfg} | false {error, Reason :: term()}
Parses the configuration for a file, returns {ok, AbsName} if
configuration was updated, false if parser did nothing or a tuple
{error, Err :: term()} when there was an error.
```

## Agents

All the action is handled by a plug-in agent, there will typically
be 1 agent pr. version control system. GIT is the only supported
agent at the moment. In the future a plug-in for local filesystem
and HTTP might be added.

Agents must export the following functions:

```
name/0` :: () -> binary()
Return the name of the agent (ie `git`, `http`)
```

```
init/1 :: (epm_pkg:pkg()) -> epm_pkg:pkg()
Initiate the agent for a package, this will be called during config
parsing and can be used to set any additional options for the pkg.
```

```
fetch/2 :: (epm_pkg:pkg(), epm:cfg()) -> ok | {error, Reason :: term()}
Checks if there are any available updates for this package.
```

```
sync/2 :: (epm_pkg:pkg(), epm:cfg()) -> ok | {error, Reason :: term()}
Syncs the local copy of the package with any remote updates.o
```

```
status/2` :: (epm_pkg:pkg(), epm:cfg()) -> ok | stale | unknown
Check the current known state of the package - sideeffect free.
```

## env/config notes

**Note:** *don't worry to much about these, will be changed/removed or similar*

+ __opt:ignore_codepath__: Flag to tell backends to not change _codepath_,
  useful when only checking to see if there are updates (git fetch)
+ __env:dryrun__: Don't do any hard work, check should be implemented
  in backend private methods.
+ __env:autofetch__: Automatically fetch everything that's needed.
+ __env:cachedir__: The root cache directory
+ __env:libdir__: Where to store those precious libraries.
+ __env:verbosity__: What level of output to give

# Examples

## Usage (Erlang API)

### Lists all package versions

```erlang
1> {ok, Cfg} = epm:parse("."),
1> lists:usort(epm_pkg:map(fun(Pkg) -> epm_pkg:get([name, version], Pkg) end, epm_pkg:flatten(Cfg))).
[[<<"lager">>,<<"1.2.1">>],[<<"cowboy">>,<<"0.8.3">>],[<<"ranch">>,<<"0.8.1">>]]
```

### Sync all known dependencies

```erlang
%% epm:parse/1 is side-effect free, therefor a explicit call to fetch is required.
2> epm_pkg:foreach(fun(Pkg) -> epm_pkg:sync(Pkg, Cfg) end, epm_pkg:flatten(Cfg)).
ok
```

### Find conflicting versions of packages (the naive way)

The following example expands the dependencies to `[Name, Version]` which
can easily be used to lookup possible version conflicts.

```erlang
42> {ok, Cfg} = epm:parse("."),
42> Pkgs0 = epm_pkg:flatten(Cfg),
42> Pkgs1 = [epm_pkg:get([name, version], P) || P <- Pkgs0],
42> Pkgs = lists:usort(Pkgs1), % Remove identical duplicates
42> {_, Duplicates0} = lists:foldl(
42> 		fun([Name|_] = P, {Acc0, Acc1}) ->
42> 			case lists:keyfind(Name, 1, Acc0) of
42> 				{Name, Prev} -> {Acc0, [P,Prev | Acc1]};
42> 				false -> {[{Name, P} | Acc0], Acc1}
42> 			end
42> 		end, {[], []}, Pkgs),
42> lists:usort(Duplicates0).
[[<<"cowboy">>,<<"0.8.3">>],
 [<<"cowboy">>,<<"0.6.1">>]]
```

## Usage (CLI)

__Drop in replacement for Rebar:__

There is no need to write a new config file to use EPM, it supports
rebar out of the box. We can at any time print out the current known
configuration:

```bash
olav@nyx /tmp/riak » ~/src/epm/bin/epm deps print -v=info  
    [info] 22:13:45 -> agent:git: github.basho:lager_syslog=1.2.2 not checked out
    [info] 22:13:45 -> agent:git: github.basho:cluster_info=1.2.3 not checked out
    [info] 22:13:45 -> agent:git: github.basho:riak_kv=1.3.1 not checked out
    [info] 22:13:45 -> agent:git: github.basho:riak_search=1.3.1 not checked out
    [info] 22:13:45 -> agent:git: github.basho:riak_control=1.3.1 not checked out
    [info] 22:13:45 -> agent:git: github.basho:riaknostic=v1.1.0 not checked out
Catalogs (1):
= github.basho.https://github.com/basho (github: 118 packages)

Dependencies (6/6):
= github.basho:cluster_info=1.2.3
= github.basho:lager_syslog=1.2.2
= github.basho:riak_control=1.3.1
= github.basho:riak_kv=1.3.1
= github.basho:riak_search=1.3.1
= github.basho:riaknostic=v1.1.0
```

The `print` operation is sideeffect free - except for fetching the
initial catalog - therefor we need an explicit call to fetch our
dependencies (the `--rebar` flag sets `libdir` and `append_version` env variables):

```bash
olav@nyx /tmp/riak » epm deps sync -v=notice --rebar
  [info] 22:15:25 -> epm: setting rebar compatability
  [notice] 22:15:26 -> agent:git: syncing riak_pipe=1.3.1 (riak_pipe) from [<<"github.basho">>]
  [notice] 22:15:27 -> agent:git: syncing sext=1.1 (sext) from [<<"github.uwiger">>]
  [notice] 22:15:27 -> agent:git: syncing edown=HEAD (edown) from [<<"github.esl">>]
  [notice] 22:15:28 -> agent:git: syncing eleveldb=1.3.0 (eleveldb) from [<<"github.basho">>]
	...
  [notice] 22:16:47 -> agent:git: syncing lager=1.2.2 (lager) from [<<"github.basho">>]
  [notice] 22:16:48 -> agent:git: syncing meck=master (meck) from [<<"github.eproxus">>]
```

We can now see we filled up the `deps/` directory:

```bash
olav@nyx /tmp/riak » ls -l deps                                                                                                                                       1 ↵
drwxr-xr-x  6 olav users 240 Apr 21 22:15 basho_stats
drwxr-xr-x  4 olav users 160 Apr 21 22:15 bear
....
drwxr-xr-x  5 olav users 160 Apr 21 22:15 syslog
drwxr-xr-x 12 olav users 500 Apr 21 22:15 webmachine

```

A final call to print will now tell us a bit more about our project:

```bash
olav@nyx /tmp/riak » ~/src/epm/bin/epm deps print

Catalogs (5):
= github.basho.https://github.com/basho (github: 118 packages)
= github.boundary.https://github.com/boundary (github: 32 packages)
= github.eproxus.https://github.com/eproxus (github: 21 packages)
= github.evanmiller.https://github.com/evanmiller (github: 30 packages)
= github.jcomellas.https://github.com/jcomellas (github: 20 packages)

Dependencies (6/22):
= github.basho:cluster_info=1.2.3
= github.basho:lager_syslog=1.2.2
= github.basho:riak_control=1.3.1
  = github.evanmiller:erlydtl=c18f2a00
  = github.basho:riak_core=1.3.1
    = github.basho:basho_stats=1.0.3
    = github.basho:folsom=0.7.3p1
      = github.boundary:bear=0.1.2
      = github.eproxus:meck=0.7.2-2-gd6230ae
    = github.basho:lager=1.2.2
    = github.basho:poolboy=0.8.1-14-g0e15b5d
    = github.basho:protobuffs=0.8.0
      = github.eproxus:meck=master (defined previously)
    = github.basho:riak_sysmon=1.1.3
    = github.basho:webmachine=1.9.3
      = github.basho:mochiweb=1.5.1p3
  = github.basho:webmachine=1.9.3 (defined previously)
= github.basho:riak_kv=1.3.1
= github.basho:riak_search=1.3.1
  = github.basho:merge_index=1.3.0
  = github.basho:riak_api=1.3.1
  = github.basho:riak_kv=1.3.1 (defined previously)
  = github.basho:riak_pb=1.3.0
    = github.basho:protobuffs=0.8.0 (defined previously)
= github.basho:riaknostic=v1.1.0
  = github.jcomellas:getopt=v0.4.3
  = github.basho:lager=1.2.2 (defined previously)
  = github.eproxus:meck=master (defined previously)
```


## Configuration

The configuration very straight forward and tries to give you all
options you may need on just one line of configuration. If the
short-hand notation is not to your liking you can use a hash map
directly with a package option.

The syntax is simple, anything not starting with whitespace or a
lowercase letter is considered a comment and is disregarded by the
preparser.

There are 2 operations that can be performed on a target: `<-` and
`<<`, this _defines_ and _appends_ respectively. Currently there are
only 2 targets: `catalogs` and `dependencies`.

### Using your Github as a catalog
```epm
-- Define your github account as the available catalog
catalogs <-
	git://github.com/lafka

-- Append Basho's github account with the alias `basho`
catalogs <<
	basho <- git://github.com
```

Now all projects in your or Basho's can be resolved just by a keyword.

### Adding dependencies

_when multiple occurences of same package is found on the same level
the later will be used._

```epm
--- There are 3 short hand operators for dependencies:
--- # -> Use this specific ref (only applicable for pkgs with revision control)
--- = -> Checkout this specific version
--- @ -> Reference a catalog which can be searched for the pkg
---
--- Additionally a list of k/v options can be given by wrapping them
--- in brackets.
---
--- Gotchas: not all catalogs/agents support fetching a specific
--- version, this means in some cases (like git) you need to specify
--- a reference as well to be certain that the correct version is
--- checkout out
dependencies <-
	tavern @github.lafka
	riakc @basho [
		pkgname = "riak-erlang-client"
		version = "1.3.1.1"
		agent.ref = "1.3.1.1"]
```

#### Appending values

In some cases it's useful to update some setting in sub-dependencies,
we can do this by using the `~` operator. We can change tag used for
`riak_pb` to `1.4.0.3` without changing the `riakc` config:

```epm
dependencies <<
	~riakc/riak_pb [agent.ref = "1.4.0.3"]
```

The above will tell git to checkout the reference to "1.4.0.3"

### Environmental branches

One of my biggest annoyances with Rebar was managing multiple levels
of dependencies where I had do alot of manual work tagging and pushing
commits out to make them available for a test run. With branches you
can put up multiple versions and have 1 configuration for your development
machine and a different one for Jenkins, the correct one is selected
by using the `--env <env>` flag:

For instance we might want use a custom build of `protobuffs` for the
Riak erlang client:

```epm
dependencies :dev <<
	~riakc/riak_pb/protobuffs [
		agent.remote = "~/src/protobuffs"
		agent.ref = "lafka-test-branch"]
```

The above will checkout our local copy of protobuffs which shortens
down the save-compile-test-commit cycle.

