-module(mongoose_user_stats).

-author('aleksander.lisiecki@erlang-solutions.com').

% TODO replace tid to official ESL one
-define(URL_BASE, "https://www.google-analytics.com/collect?v=1&tid=UA-151110014-1&t=event").

-export([report_user_stats/0]).

report_user_stats() ->
    IsAllowed = ejabberd_config:get_local_option_or_default(is_report_user_stats_allowed, true),
    report_user_stats(IsAllowed).

% Functions are spawned and not linked, as MongooseIM should not care if they fail or not.
% Moreover the MongooseIM's start should not be blocked.
report_user_stats(true) ->
    % Data used for more then one report
    Hosts = ejabberd_config:get_global_option(hosts),
    Reports = [
        fun() -> report_number_of_hosts(Hosts) end,
        fun() -> report_used_modules(Hosts) end
    ],
    lists:foreach(
        fun(Fun) ->
            spawn(Fun)
        end, Reports);
report_user_stats(_) -> ok.

report_number_of_hosts(Hosts) ->
    Len = length(Hosts),
    report(hosts_count, Len).

report_used_modules(Hosts) ->
    ModulesWithOpts = lists:flatten(
        lists:map(fun gen_mod:loaded_modules_with_opts/1, Hosts)),
    lists:foreach(
        fun({Module, Opts}) ->
            Backend = proplists:get_value(backend, Opts, none),
            report(modules, Module, Backend)
        end, ModulesWithOpts).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% HELPERS %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

report(EventCategory, EventAction) ->
    report(EventCategory, EventAction, empty).

report(EventCategory, EventAction, EventLabel) ->
    MaybeLabel = case EventLabel of
        empty ->
            [];
        AnyEventLabel ->
            LstEventLabel = term_to_string(AnyEventLabel),
            ["&el=", LstEventLabel]
    end,
    LstClientId = term_to_string(client_id()),
    LstEventCategory = term_to_string(EventCategory),
    LstEventAction = term_to_string(EventAction),
    ListUrl = [
        ?URL_BASE,
        "&cid=", LstClientId,
        "&ec=", LstEventCategory,
        "&ea=", LstEventAction
        ] ++ MaybeLabel,
    URL = string:join(ListUrl, ""),
    lager:debug("~p reported = ~p", [?MODULE, URL]),
    httpc:request(URL).

term_to_string(Term) ->
    R= io_lib:format("~p",[Term]),
    lists:flatten(R).

client_id() ->
    % TODO in the later implementation store client's ID in eg mnesia table and report stats with the same ID for the same client
    rand:uniform(1000 * 1000 * 1000 * 1000 * 1000).
