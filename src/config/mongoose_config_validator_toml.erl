-module(mongoose_config_validator_toml).

-export([validate/2]).

-include("mongoose.hrl").
-include("ejabberd_config.hrl").

-define(HOST, 'HOST').

-spec validate(mongoose_config_parser_toml:path(),
               mongoose_config_parser_toml:option() | mongoose_config_parser_toml:config_list()) ->
          any().
validate(Path, [F]) when is_function(F, 1) ->
    validate(Path, F(?HOST));

%% general
validate([<<"loglevel">>, <<"general">>],
         [#local_config{value = Val}]) -> validate_loglevel(Val);
validate([item, <<"hosts">>, <<"general">>],
         [Value]) ->
    validate_non_empty_binary(Value);
validate([<<"hosts">>, <<"general">>],
         [#config{value = Val}]) ->
    validate_hosts(Val);
validate([<<"registration_timeout">>, <<"general">>],
         [#local_config{value = Val}]) ->
    validate_timeout(Val);
validate([<<"language">>, <<"general">>],
         [#config{value = Value}]) ->
    validate_non_empty_binary(Value);
validate([<<"all_metrics_are_global">>, <<"general">>],
         [#local_config{value = Val}]) ->
    validate_boolean(Val);
validate([<<"sm_backend">>, <<"general">>],
         [#config{value = {Backend, []}}]) ->
    validate_module(list_to_atom("ejabberd_sm_" ++ atom_to_list(Backend)));
validate([<<"max_fsm_queue">>, <<"general">>],
         [#local_config{value = Value}]) ->
    validate_positive_integer(Value);
validate([<<"rdbms_server_type">>, <<"general">>],
         [#local_config{value = Value}]) ->
    validate_enum(Value, [mssql, pgsql]);
validate([item, <<"override">>, <<"general">>],
         [{override, Value}]) ->
    validate_enum(Value, [local, global, acls]);
validate([<<"override">>, <<"general">>],
         Items) ->
    validate_unique_items(Items);
validate([<<"pgsql_users_number_estimate">>, <<"general">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_boolean(Value);
validate([<<"route_subdomains">>, <<"general">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_enum(Value, [s2s]);
validate([item, <<"routing_modules">>, <<"general">>],
         [Value]) ->
    validate_module(Value);
validate([<<"replaced_wait_timeout">>, <<"general">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_positive_integer(Value);
validate([<<"hide_service_name">>, <<"general">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_boolean(Value);

%% listen
validate([item, _Type, <<"listen">>],
         [{{Port, _IPT, _Proto}, _Module, _Opts}]) ->
    validate_port(Port);
validate([<<"backlog">>, item, _Type, <<"listen">>],
         [{backlog, Value}]) ->
    validate_non_negative_integer(Value);
validate([<<"proxy_protocol">>, item, _Type, <<"listen">>],
         [{proxy_protocol, Value}]) ->
    validate_boolean(Value);
validate([<<"access">>, item, _Type, <<"listen">>],
         [{access, Value}]) ->
    validate_non_empty_atom(Value);
validate([<<"shaper">>, item, _Type, <<"listen">>],
         [{shaper, Value}]) ->
    validate_non_empty_atom(Value);
validate([<<"shaper_rule">>, item, <<"service">>, <<"listen">>],
         [{shaper_rule, Value}]) ->
    validate_non_empty_atom(Value);
validate([<<"xml_socket">>, item, <<"c2s">>, <<"listen">>],
         [{xml_socket, Value}]) ->
    validate_boolean(Value);
validate([<<"zlib">>, item, <<"c2s">>, <<"listen">>],
         [{zlib, Value}]) ->
    validate_positive_integer(Value);
validate([<<"hibernate_after">>, item, <<"c2s">>, <<"listen">>],
         [{hibernate_after, Value}]) ->
    validate_non_negative_integer(Value);
validate([<<"mode">>, {tls, _}, item, <<"c2s">>, <<"listen">>],
         [Value]) ->
    validate_enum(Value, [tls, starttls, starttls_required]);
validate([<<"verify_mode">>, {tls, just_tls}, item, <<"c2s">>, <<"listen">>],
         Value) ->
    validate_enum(Value, [peer, selfsigned_peer, none]);
validate([<<"disconnect_on_failure">>, {tls, just_tls}, item, <<"c2s">>, <<"listen">>],
         Value) ->
    validate_boolean(Value);
validate([FileType, _TLS, item, _Type, <<"listen">>],
         [{_, Value}]) when FileType =:= <<"certfile">>;
                            FileType =:= <<"cacertfile">>;
                            FileType =:= <<"dhfile">> ->
    validate_non_empty_string(Value);
validate([<<"max_stanza_size">>, item, _Type, <<"listen">>],
         [{max_stanza_size, Value}]) ->
    validate_positive_integer(Value);
validate([<<"check_from">>, item, <<"service">>, <<"listen">>],
         [{service_check_from, Value}]) ->
    validate_boolean(Value);
validate([<<"hidden_components">>, item, <<"service">>, <<"listen">>],
         [{hidden_components, Value}]) ->
    validate_boolean(Value);
validate([<<"conflict_behaviour">>, item, <<"service">>, <<"listen">>],
         [{conflict_behaviour, Value}]) ->
    validate_enum(Value, [kick_old, disconnect]);
validate([<<"password">>, item, <<"service">>, <<"listen">>],
         [{password, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"verify_mode">>, <<"tls">>, item, <<"http">>, <<"listen">>],
         [{verify_mode, Value}]) ->
    validate_enum(Value, [peer, selfsigned_peer, none]);
validate([<<"num_acceptors">>, <<"transport">>, item, <<"http">>, <<"listen">>],
         [{num_acceptors, Value}]) ->
    validate_positive_integer(Value);
validate([<<"max_connections">>, <<"transport">>, item, <<"http">>, <<"listen">>],
         [{max_connections, Value}]) ->
    validate_non_negative_integer_or_infinity(Value);
validate([<<"compress">>, <<"protocol">>, item, <<"http">>, <<"listen">>],
         [{compress, Value}]) ->
    validate_boolean(Value);
validate([item, <<"lasse_handler">>, <<"handlers">>, item, <<"http">>, <<"listen">>],
         [{Host, _Path, lasse_handler, Opts}]) ->
    validate_non_empty_string(Host),
    [Module] = Opts,
    validate_module(Module);
validate([item, <<"handlers">>,
          item, <<"mongoose_api">>, <<"handlers">>, item, <<"http">>, <<"listen">>],
         [Value]) ->
    validate_module(Value);
validate([item, _TypeBin, <<"handlers">>, item, <<"http">>, <<"listen">>],
         [{Host, _Path, Type, _Opts}]) ->
    validate_non_empty_string(Host),
    validate_module(Type);

%% auth
validate([item, <<"methods">>, <<"auth">>|Path],
         [Value]) ->
    validate_root_or_host_config(Path),
    validate_module(list_to_atom("ejabberd_auth_" ++ atom_to_list(Value)));
validate([<<"password">>, <<"auth">>|Path],
         [{password_format, Value}]) ->
    validate_root_or_host_config(Path),
    validate_password_format(Value);
validate([item, <<"hash">>, <<"password">>, <<"auth">>|Path],
         [Value]) ->
    validate_root_or_host_config(Path),
    validate_enum(Value, [sha, sha224, sha256, sha384, sha512]);
validate([<<"scram_iterations">>, <<"auth">>|Path],
         [{scram_iterations, Value}]) ->
    validate_root_or_host_config(Path),
    validate_positive_integer(Value);
validate([item, <<"cyrsasl_external">>, <<"auth">>|Path],
         [{mod, Module}]) ->
    validate_root_or_host_config(Path),
    validate_module(Module);
validate([<<"allow_multiple_connections">>, <<"auth">>|Path],
         [{allow_multiple_connections, Value}]) ->
    validate_root_or_host_config(Path),
    validate_boolean(Value);
validate([<<"anonymous_protocol">>, <<"auth">>|Path],
         [{anonymous_protocol, Value}]) ->
    validate_root_or_host_config(Path),
    validate_enum(Value, [sasl_anon, login_anon, both]);
validate([Pool, <<"ldap">>, <<"auth">>|Path],
         [{_, Value}]) when Pool =:= <<"pool_tag">>;
                            Pool =:= <<"bind_pool_tag">> ->
    validate_root_or_host_config(Path),
    validate_non_empty_atom(Value);
validate([<<"operation">>, <<"local_filter">>, <<"ldap">>, <<"auth">>|Path],
         [{operation, Value}]) ->
    validate_root_or_host_config(Path),
    validate_enum(Value, [equal, not_equal]);
validate([<<"attribute">>, <<"local_filter">>, <<"ldap">>, <<"auth">>|Path],
         [{attribute, Value}]) ->
    validate_root_or_host_config(Path),
    validate_non_empty_string(Value);
validate([<<"values">>, <<"local_filter">>, <<"ldap">>, <<"auth">>|Path],
         [{values, Value}]) ->
    validate_root_or_host_config(Path),
    validate_non_empty_list(Value);
validate([<<"deref">>, <<"ldap">>, <<"auth">>|Path],
         [{ldap_deref, Value}]) ->
    validate_root_or_host_config(Path),
    validate_enum(Value, [never, always, finding, searching]);
validate([item, <<"sasl_mechanisms">>, <<"auth">>|Path],
         [Value]) ->
    validate_root_or_host_config(Path),
    validate_module(Value);
validate([<<"extauth_instances">>, <<"auth">>|Path],
         [{extauth_instances, Value}]) ->
    validate_root_or_host_config(Path),
    validate_positive_integer(Value);

%% outgoing_pools
validate([_Tag, _Type, <<"outgoing_pools">>],
         [{TypeAtom, Scope, TagAtom, _Options, _ConnectionOptions}]) ->
    validate_enum(TypeAtom, [redis, riak, http, rdbms, cassandra, elastic, generic, rabbit, ldap]),
    validate_pool_scope(Scope),
    validate_non_empty_atom(TagAtom);
validate([<<"workers">>, _Tag, _Type, <<"outgoing_pools">>],
         [{workers, Value}]) ->
    validate_positive_integer(Value);
validate([<<"strategy">>, _Tag, _Type, <<"outgoing_pools">>],
         [{strategy, Value}]) ->
    validate_enum(Value, [best_worker, random_worker, next_worker,
                          available_worker, next_available_worker]);
validate([<<"call_timeout">>, _Tag, _Type, <<"outgoing_pools">>],
         [{call_timeout, Value}]) ->
    validate_positive_integer(Value);
validate([<<"keepalive_interval">>, _Conn, _Tag, <<"rdbms">>, <<"outgoing_pools">>],
         [{keepalive_interval, Value}]) ->
    validate_positive_integer(Value);
validate([{connection, Driver}, _Tag, <<"rdbms">>, <<"outgoing_pools">>],
         [_Value]) ->
    validate_enum(Driver, [odbc, pgsql, mysql]);
validate([Key, {connection, _}, _Tag, <<"rdbms">>, <<"outgoing_pools">>],
         [{_, Value}]) when Key =:= <<"host">>;
                            Key =:= <<"database">>;
                            Key =:= <<"username">>;
                            Key =:= <<"password">> ->
    validate_non_empty_string(Value);
validate([<<"port">>, {connection, _}, _Tag, <<"rdbms">>, <<"outgoing_pools">>],
         [{port, Value}]) ->
    validate_port(Value);
validate([<<"host">>, _Conn, _Tag, <<"http">>, <<"outgoing_pools">>],
         [{server, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"path_prefix">>, _Conn, _Tag, <<"http">>, <<"outgoing_pools">>],
         [{path_prefix, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"request_timeout">>, _Conn, _Tag, <<"http">>, <<"outgoing_pools">>],
         [{request_timeout, Value}]) ->
    validate_non_negative_integer(Value);
validate([<<"http_opts">>, _Conn, _Tag, <<"http">>, <<"outgoing_pools">>],
         [{http_opts, Value}]) ->
    validate_map(Value),
    [validate_enum(Key, [retry, retry_timeout]) || Key <- maps:keys(Value)],
    validate_non_negative_integer(maps:get(retry, Value, 1)),
    validate_positive_integer(maps:get(retry_timeout, Value, 1));
validate([<<"host">>, _Conn, _Tag, <<"redis">>, <<"outgoing_pools">>],
         [{host, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"port">>, _Conn, _Tag, <<"redis">>, <<"outgoing_pools">>],
         [{port, Value}]) ->
    validate_port(Value);
validate([<<"database">>, _Conn, _Tag, <<"redis">>, <<"outgoing_pools">>],
         [{database, Value}]) ->
    validate_non_negative_integer(Value);
validate([<<"password">>, _Conn, _Tag, <<"redis">>, <<"outgoing_pools">>],
         [{host, Value}]) ->
    validate_list(Value);
validate([<<"address">>, _Conn, _Tag, <<"riak">>, <<"outgoing_pools">>],
         [{address, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"port">>, _Conn, _Tag, <<"riak">>, <<"outgoing_pools">>],
         [{port, Value}]) ->
    validate_port(Value);
validate([<<"credentials">>, _Conn, _Tag, <<"riak">>, <<"outgoing_pools">>],
         [{credentials, User, Password}]) ->
    validate_non_empty_string(User),
    validate_non_empty_string(Password);
validate([<<"cacertfile">>, _Conn, _Tag, <<"riak">>, <<"outgoing_pools">>],
         [{cacertfile, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"servers">>, _Conn, _Tag, <<"cassandra">>, <<"outgoing_pools">>],
         [{servers, Value}]) ->
    [{validate_non_empty_string(Host), validate_port(Port)} || {Host, Port} <- Value];
validate([<<"keyspace">>, _Conn, _Tag, <<"cassandra">>, <<"outgoing_pools">>],
         [{keyspace, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"host">>, _Conn, _Tag, <<"elastic">>, <<"outgoing_pools">>],
         [{host, Value}]) ->
    validate_non_empty_string(Value);
validate([<<"port">>, _Conn, _Tag, <<"elastic">>, <<"outgoing_pools">>],
         [{host, Value}]) ->
    validate_port(Value);

%% shaper
validate([_, <<"shaper">>|Path],
         [#config{value = {maxrate, Value}}]) ->
    validate_root_or_host_config(Path),
    validate_positive_integer(Value);

%% s2s
validate([<<"timeout">>, <<"dns">>, <<"s2s">>],
         [{timeout, Value}]) ->
    validate_positive_integer(Value);
validate([<<"retries">>, <<"dns">>, <<"s2s">>],
         [{retries, Value}]) ->
    validate_positive_integer(Value);
validate([<<"port">>, <<"outgoing">>, <<"s2s">>],
         [#local_config{value = Value}]) ->
    validate_port(Value);
validate([<<"ip_versions">>, <<"outgoing">>, <<"s2s">>],
         [#local_config{value = Value}]) ->
    validate_non_empty_list(Value);
validate([<<"connection_timeout">>, <<"outgoing">>, <<"s2s">>],
         [#local_config{value = Value}]) ->
    validate_timeout(Value);
validate([<<"use_starttls">>, <<"s2s">>],
         [#local_config{value = Value}]) ->
    validate_enum(Value, [false, optional, required, required_trusted]);
validate([<<"certfile">>, <<"s2s">>],
         [#local_config{value = Value}]) ->
    validate_non_empty_string(Value);
validate([<<"default_policy">>, <<"s2s">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_enum(Value, [allow, deny]);
validate([<<"host">>, item, <<"address">>, <<"s2s">>],
         [{host, Value}]) ->
    validate_non_empty_binary(Value);
validate([<<"ip_address">>, item, <<"address">>, <<"s2s">>],
         [{ip_address, Value}]) ->
    validate_ip_address(Value);
validate([<<"port">>, item, <<"address">>, <<"s2s">>],
         [{port, Value}]) ->
    validate_port(Value);
validate([item, <<"domain_certfile">>, <<"s2s">>],
         [#local_config{key = {domain_certfile, Domain}, value = Certfile}]) ->
    validate_non_empty_string(Domain),
    validate_non_empty_string(Certfile);
validate([<<"shared">>, <<"s2s">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_non_empty_binary(Value);
validate([<<"max_retry_delay">>, <<"s2s">>|Path],
         [#local_config{value = Value}]) ->
    validate_root_or_host_config(Path),
    validate_positive_integer(Value);

validate(_, _) ->
    ok.

%% helpers

validate_loglevel(Level) ->
    mongoose_logs:loglevel_number_keyword(Level).

validate_non_empty_binary(Value) when is_binary(Value), Value =/= <<>> -> ok.

validate_hosts(Hosts = [_|_]) ->
    validate_unique_items(Hosts).

validate_unique_items(Items) ->
    L = sets:size(sets:from_list(Items)),
    L = length(Items).

validate_timeout(infinity) -> ok;
validate_timeout(Timeout) when is_integer(Timeout), Timeout > 0 -> ok.

validate_boolean(Value) when is_boolean(Value) -> ok.

validate_module(Mod) ->
    {module, _} = code:ensure_loaded(Mod).

validate_positive_integer(Value) when is_integer(Value), Value > 0 -> ok.

validate_non_negative_integer(Value) when is_integer(Value), Value >= 0 -> ok.

validate_non_negative_integer_or_infinity(Value) when is_integer(Value), Value >= 0 -> ok;
validate_non_negative_integer_or_infinity(infinity) -> ok.

validate_enum(Value, Values) ->
    true = lists:member(Value, Values).

validate_ip_address(Value) ->
    {ok, _} = inet:parse_address(Value).

validate_port(Value) when is_integer(Value), Value >= 0, Value =< 65535 -> ok.

validate_non_empty_atom(Value) when is_atom(Value), Value =/= '' -> ok.

validate_non_empty_string(Value) when is_list(Value), Value =/= "" -> ok.

validate_non_empty_list(Value) when is_list(Value), Value =/= [] -> ok.

validate_password_format({scram, [_|_]}) -> ok;
validate_password_format(Value) -> validate_enum(Value, [scram, plain]).

validate_pool_scope(Value) when is_binary(Value) -> validate_non_empty_binary(Value);
validate_pool_scope(Value) -> validate_enum(Value, [host, global]).

validate_root_or_host_config([]) -> ok;
validate_root_or_host_config([{host, _}, <<"host_config">>]) -> ok.

validate_map(Value) when is_map(Value) -> ok.
validate_list(Value) when is_list(Value) -> ok.
