# $Id: Request.pm,v 1.1 2004/02/24 18:41:02 jgsmith Exp $

package Gestinanna::Request;

use strict;
no strict 'refs';

#use Apache;
use Apache::Cookie;
use Apache::Constants qw(OK DECLINED NOT_FOUND SERVER_ERROR);
#use Apache::Request;
use Apache::Session::Flex;
use Digest::SHA1;


BEGIN {
    our $IN_MOD_PERL = $ENV{MOD_PERL};
    if($IN_MOD_PERL) {
        require Apache;
        require Apache::Log;
        require Apache::Request;
        @Gestinanna::Request::ISA = ('Apache::Request');
    }
    else {
        require Apache::FakeRequest;
        @Gestinanna::Request::ISA = ('Apache::FakeRequest');
    }
}

sub in_mod_perl { $Gestinanna::Request::IN_MOD_PERL; }

our $INSTANCE; # for non-apache environments

sub new {
    my $package = shift;
    $package = ref $package || $package;

    # need to see if we're in an Apache environment
    my $self;
    if($package -> in_mod_perl) {
        $self = Apache -> request -> pnotes($package);
    }
    else {
        $self = $INSTANCE;
    }
    return $self if defined $self;

    $self = bless { } => $package;
    
    if($self -> in_mod_perl) {
        my $r = @_ ? shift : Apache -> request;
        $self -> {_r} = Apache::Request -> instance(Apache -> request);

        $self -> {_gst} = Apache::Gestinanna -> retrieve;
    }

    #warn "Calling $self -> init\n";
    $self -> init;
    #warn "Returned from $self -> init\n";
    #warn "factory has following keys: ", join(", ", keys %{$self -> {factory}||{}}), "\n";

    if($self -> in_mod_perl) {
        Apache -> request -> pnotes($package, $self);
    }
    else {
        $INSTANCE = $self;
    }

    return $self;
}

sub instance { $_[0] -> new }

# need to handle file uploads -- Gestinanna::Upload

use AxKit;

use Gestinanna::POF;
use Gestinanna::Authz;
use Gestinanna::Schema;

use Storable ();

sub read_session {
    my($self, $config, $hash, $id) = @_;

    no strict 'refs';

    eval {
        local($SIG{__DIE__});
        tie %{$hash}, 'Apache::Session::Flex', $id, {
            Commit => 1,
            #%{$c -> session_option || {}},
            Store => $config -> {'session'} -> {'store'} -> {'store'},
            Lock  => $config -> {'session'} -> {'store'} -> {'lock'},
            Generate => $config -> {'session'} -> {'store'} -> {'generate'},
            Serialize => $config -> {'session'} -> {'store'} -> {'serialize'},
            Handle => $self -> {_dbh},
            LockHandle => $self -> {_dbh},
        };
    };
    if($@ || !tied(%$hash)) { # need to check for database errors so we don't thrash about here
        if($@ !~ m{Object does not exist in the data store}) {
            warn "$@\n";
            return undef 
        }
        # bad identifier... need to make a new one and start over
        eval {
            local($SIG{__DIE__});
            tie %{$hash}, 'Apache::Session::Flex', undef, {
                Commit => 1,
                #%{$c -> session_option || {}},
                Store => $config -> {'session'} -> {'store'} -> {'store'},
                Lock  => $config -> {'session'} -> {'store'} -> {'lock'},
                Generate => $config -> {'session'} -> {'store'} -> {'generate'},
                Serialize => $config -> {'session'} -> {'store'} -> {'serialize'},
                Handle => $self -> {_dbh},
                LockHandle => $self -> {_dbh},
            };
        };
        if($@ || !tied(%$hash)) {
            warn "$@\n";
            return;
        }
    }
    return $hash -> {_session_id};
}

sub do_redirect {
    my($self, $url) = @_;

    my $r = $self -> {_r};

    $r -> err_header_out("Location" => $url);

    my $message = <<EOF;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML>
  <HEAD>
    <TITLE>Redirecting...</TITLE>
    <META HTTP-EQUIV=Refresh CONTENT="0; URL=$url">
  </HEAD>
  <BODY>
    <H1>Redirecting...</H1>
    You are being redirected <A HREF="$url">here</A>.<P>
  </BODY>
</HTML>
EOF

    $r -> content_type("text/html");
    $r -> send_http_header;
    $r -> print($message);
    $r -> rflush;
}
    

sub init {
    no strict 'refs';

    local($SIG{__DIE__});

    my $self = shift;
#    $self->{data} = $_[0];
#    $self->{styles} = $_[1];

    delete @{$self}{qw(_dbh _cfg _content_provider _decline)};

    my $cfg = $self -> {_gst};

    $self -> {_cfg} = $cfg;

    my $config = $cfg -> config;

    my $pkg = $config -> {package};

    $self -> {_dbh} = $cfg -> resources -> {dbi} -> get();

    if($cfg -> resources -> {ldap}) {
        my $ldap = $cfg -> resources -> {ldap} -> get();
        $self -> {_ldap} = $ldap;
        $self -> {_ldap_schema} = ${"${pkg}::ldap_schema"} ||= $ldap -> schema;
    }


    my $alzabo_schema = Gestinanna::Schema -> load_schema(
        name => $config -> {schema},
        dbh => $self -> {_dbh},
    );


    # factory should already have classes configured
    my($content_type, $filename, $content_provider_class, $uri);

    # do uri -> filename conversion here
    #my $sth = $self -> {_dbh} -> prepare_cached("SELECT * FROM Uri_Map WHERE uri=? AND site=?");
    #my $res = $sth -> execute($self -> apache_request -> uri, $cfg -> config -> {site});
# may want to add support for virtual directories at some point

    my $uri_map = $alzabo_schema -> table('Uri_Map');
    return unless $uri_map;

    my $base_uri = $self -> uri;
    #warn "base uri: $base_uri\n";
    my($uri_session_id, $cookie_session_id);
    if($base_uri =~ s{^/([0-9a-f]{32})/}{/}) {
        $uri_session_id = $1;
        $self -> uri($base_uri);
    }
    #warn "base uri: $base_uri\n";

    my $cookies = Apache::Cookie->fetch;
            
    my $cookie = $cookies->{$config -> {'session'} -> {'cookie'} -> {'name'} || 'SESSIONID'};
    $cookie_session_id = $cookie -> value if defined $cookie;

    my $session = $pkg . "::session";

    if((defined($cookie_session_id) && defined($uri_session_id) && $cookie_session_id eq $uri_session_id)
       || (defined($cookie_session_id) && !defined($uri_session_id))
       || (defined($uri_session_id) && !defined($cookie_session_id))
    ) {
        my $session_id = $cookie_session_id || $uri_session_id;
        my $id = $self -> read_session($config, $session, $session_id);
        return unless $id; # need to put up an error page
        if($id ne $session_id) {
            # need to do a redirect - check for cookies, etc.
            Apache ->
                request ->
                    err_header_out(
                        "Set-Cookie" => 
                            ($config -> {'session'} -> {'cookie'} -> {'name'} || 'SESSIONID') . "=$id; Path=/;"
                    );
            $session -> {redirect_args} = { %{ $self -> parms } };
            $self -> do_redirect("/$id$base_uri");
            $self -> {_decline} = OK;
            return;
        }
        if(defined $uri_session_id && defined $cookie_session_id && $uri_session_id eq $cookie_session_id) {
            $session -> {redirect_args} = { %{ $self -> parms } };
            $self -> do_redirect($base_uri);
            $self -> {_decline} = OK;
            return;
        }
    }
    else {
        # no session id - need to set one and do a redirect to check cookies
        my $id = $self -> read_session($config, $session, undef);
        #warn "new id: $id\n";
        # do redirect
        Apache ->
            request ->
                err_header_out(
                    "Set-Cookie" => 
                        ($config -> {'session'} -> {'cookie'} -> {'name'} || 'SESSIONID') . "=$id; Path=/;"
                );
        # need to handle file uploads
        $session -> {redirect_args} = { %{ $self -> parms } };
        $self -> do_redirect("/$id$base_uri");
        $self -> {_decline} = OK;
        return;
    }

    $self -> {_session_id_location} = 'cookie';
    $self -> {_session_id_location} = 'url'
        if !defined($cookie_session_id) || defined($uri_session_id) && $uri_session_id ne $cookie_session_id;

    $self -> {base_uri} = $base_uri;

    my @uris = ($base_uri);

    push @uris, $base_uri . "index.xml" if $base_uri =~ m{/$};

    # need to check for virtual directory handlers

    while(($uri = shift(@uris)) && !$content_provider_class) {
        ($content_type, $filename) = $self -> uri_to_filename($uri_map, $uri, $cfg -> config -> {site}, $cfg -> config -> {'content-provider'});

        $content_provider_class = $cfg -> config -> {'content-provider'} -> {$content_type} -> {class};
        #warn "uri: $uri => $content_type : $filename implemented by $content_provider_class\n";
    }

    unless(defined $content_provider_class) {
        $self -> {_decline} = NOT_FOUND;
        return;
    }

    $self -> {filename} = $filename;
    $self -> {type} = $content_type;

    # need to check authorization and authentication

    my $args;
    # doesn't handle file uploads - just basic data
    if(defined $session -> {redirect_args}) {
        $args = delete $session -> {redirect_args};
    }
    else {
        my $table = $self -> parms;
        foreach my $k (keys %$table) {
            my @v = $table -> get($k);
            $args -> {$k} = @v > 1 ? \@v : $v[0];
        }
    }

    #warn "Client Args: ", Data::Dumper -> Dump([$args]);

    $self -> {args} = $args;

    if(0) {
    foreach my $k (keys %{$session -> {contexts}||{}}) {
        next if exists $args -> {"$k._context_id"};
        if($k =~ m{^_embedded(\._embedded)*$}) {
            if($session -> {contexts} -> {$k} -> {uri} eq $base_uri) {
                $args -> {"$k._context_id"} = $session -> {contexts} -> {$k} -> {ctx};
            }
        }
        else {
            $args -> {"$k._context_id"} = $session -> {contexts} -> {$k};
        }
    }
    delete $session -> {contexts};
    }

    my $factory_class = $pkg . "::POF";
    #warn "Creating factory from $factory_class\n";
    my $factory = $self -> {factory} = $factory_class -> new(_factory => (
        alzabo_schema => $alzabo_schema,
        site => $config -> {site},
        tag_path => $config -> {'tag-path'},
        ($self -> {_ldap} ? (ldap => $self -> {_ldap}) : ()),
        ($self -> {_ldap_schema} ? (ldap_schema => $self -> {_ldap_schema}) : ()),
        authz => Gestinanna::Authz -> new(alzabo_schema => $alzabo_schema),
    ));
    #warn "factory has following keys: ", join(", ", keys %{$self -> {factory}||{}}), "\n";

    my $actor;
    if($session -> {actor_id}) {
        $actor = $factory -> new(actor => (object_id => $session -> {actor_id}));
    }
    #elsif($config -> {'auth-provider'} -> {class}) {
    #    # check for authentication credentials
    #    my $auth_class = $config -> {'auth-provider'} -> {class};
    #    # should have been loaded at server startup
    #    my $res = $auth_class -> authenticate(
    #        config => $config -> {'auth-provider'},
    #        factory => $factory,
    #        #args => $args,
    #        username => $args -> {$config -> {'auth-provider'} -> {'fields'} -> {'username'}},
    #        password => $args -> {$config -> {'auth-provider'} -> {'fields'} -> {'password'}},
    #    );
    #    if($res >= 100) {  # HTTP response code
    #        $self -> {_decline} = $res;
    #        return;
    #    }
#
#        $actor = $factory -> new(actor => (
#            $config -> {'auth-provider'} -> {'actor-id'} => $args -> {$config -> {'auth-provider'} -> {'fields'} -> {'username'}}
#        )) if $res;
#    }

    #warn "Session{actor_id}: " . $session -> {actor_id} . "\n";
    if($actor && $actor -> is_live) {
        $factory = $factory -> new(_factory => (
            %$factory,
            actor => $actor,
        ));
    }
    elsif(defined $config -> {'anonymous'}) { # set up guest actor
        $actor = $factory -> new(actor => (
            object_id => $config -> {'anonymous'}
        ));
        $factory = $factory -> new(_factory => (
            %$factory,
            actor => $actor,
        ));
        $actor = undef;
        delete $session -> {actor_id};
    }
    else {
        $actor = undef;
        delete $session -> {actor_id};
    }

    # at least, if the content requires authorization beyond anonymous user
    # then check authorization of non-anonymous user

    $self -> {factory} = $factory;
    #warn "factory has following keys: ", join(", ", keys %{$self -> {factory}||{}}), "\n";
    $self -> {session} = \%$session;
    #warn "session: ", tied %{$$self{session}}, "\n";
}

sub upload {
    my($self) = shift;

    return unless defined wantarray;

    unless($self -> {_uploads}) {
        # move each upload to the database and create a Gestinanna::Upload object
        my @uploads = $self -> SUPER::upload;
        my %newups;
        $self -> {_uuid} ||= Data::UUID -> new;
        my($id, $ob);
        local($/);
        foreach my $file (@uploads) {
            my $fh = $file -> fh;
            my $content = <$fh>;
            my $hash = Digest::SHA1::sha1_hex(<$content>);

            my $cursor = $self -> factory -> find(upload => (
                where => [ 'hash', '=', $hash ],
            ) );

            unless($id = $cursor -> next_id) {
                $id = $self -> {_uuid} -> create_str();
                $ob = $self -> factory -> new(upload => object_id => $id);
                while($ob -> is_live) {
                    $id = $self -> {_uuid} -> create_str();
                    $ob = $self -> factory -> new(upload => object_id => $id);
                }
                $ob -> type($file -> type);
                $ob -> size($file -> size);
                $ob -> content($content);
                $ob -> save;
            }
            else {
                $ob = $self -> factory -> new(upload => object_id => $id);
            }

            $cursor -> discard;

            $newups{$ob -> name} = Gestinanna::Upload -> new(
                filename => $file -> filename,
                type => $ob -> type,
                id => $ob -> object_id,
                size => $ob -> size,
                hash => $ob -> hash,
            );
        }
        $self -> {_uploads} = \%newups;
    }

    if(wantarray) {
        # return array of all uploads
        return values %{$self -> {_uploads}};
    }
    if(@_) {
        return $self -> {_uploads} -> {$_[0]};
    }
    my($k, $v) = each %{$self -> {_uploads}};
    return $v;
}

sub embeddings {
    my($self, %params) = @_;
    # we want to track down the embedding chain here and get each content provider in turn

    my @embeddings; # list of content provider objects - build from top-down, use bottom-up
    my $alzabo_schema = $self -> {factory} -> {alzabo_schema};

    #warn "looking for embeddings:\n  filename: $$self{filename}\n  type: $$self{type}\n  uri: $$self{base_uri}\n";

    if($alzabo_schema -> has_table('Embedding_Map')) {
        my $embed_table = $alzabo_schema -> table('Embedding_Map');
        @embeddings = $self -> providers(
            filename => $self -> {filename},
            type => $self -> {type},
            %params,
            args => $self -> {args},
            uri => $self -> {base_uri},
            site => $self -> config -> {site},
            theme => '',
            table => $embed_table,
            session => $self -> {session},
        );
    }
    else {
    # actual request
        @embeddings = grep { defined } (
            $self -> get_content_provider(
                filename => $self -> {filename},
                type => $self -> {type},
                %params,
                args => $self -> {args},
            )
        );
    }

    #warn "Embeddings:\n  " , join("\n  ", @embeddings), "\n";

    return unless @embeddings;

    my $i = 0;
    $i++ while exists $embeddings[$i] && defined $embeddings[$i] && $embeddings[$i] -> may_exec;
    unless($i == @embeddings) {
        $#embeddings = $i;
        my $cp = $self -> error_provider(error => 'privileges', args => { uri => $self -> {base_uri} });

        unless(defined $cp) {
            $self -> {_decline} = SERVER_ERROR;
            return;
        }

        push @embeddings, $cp;
    }
    #warn "content provider: $cp\n";
    return \@embeddings;
}

sub config { $_[0] -> {_cfg} ? $_[0] -> {_cfg} -> config : { } }

sub error { shift -> error_provider(@_); } # for now

sub error_provider {
    my($self, %params) = @_;

    my $config = $self -> config;

    my($content_type, $filename, $content_provider_class, $cp);

    my @bits = split('.', $params{error});

    my @configs = ($config -> {'error'});

    foreach my $bit (@bits) {
        push @configs, $configs[$#configs] -> {$bit};
        if(!defined $configs[$#configs]) {
            pop @configs;
            last;
        }
    }

    while(@configs && !$cp) {
        my($content_type, $filename) = @{(pop @configs)||{}}{qw(type file)};

        $cp = $self -> get_content_provider(
            args => $params{args},
            filename => $filename,
            type => $content_type,
        );
    }

    return $cp;
}

sub get_content_provider {
    my($self, %params) = @_;

    return unless defined $params{type} && defined $params{filename};

    my $config = $self -> {_cfg} -> config;

    my $content_provider_class = $config -> {'content-provider'} -> {$params{type}} -> {class};

    return unless defined $content_provider_class;

    #if($self -> apache_request -> path_info) { # subject to change
    #    $params{args}{'sys.path_info'} = $self -> apache_request -> path_info;
    #}

    return $content_provider_class -> init(
        %params,
        config => $config -> {'content-provider'} -> {$params{type}},
        request => $self,
    );
}

sub factory { $_[0] -> {factory} }

sub session { $_[0] -> {session} }

# returns _all_ providers, including last one
sub providers {
    my($self, %params) = @_;

    my @embeddings;
    my $cursor = $params{table} -> rows_where(
        where => [
            '(',
              [ $params{table} -> column('site'), '=', $params{site} ],
                'or',
              [ $params{table} -> column('site'), '=', 0, ],
            ')',
            'and',
            '(',
              [ $params{table} -> column('theme'), '=', $params{theme} ],
                'or',
              [ $params{table} -> column('theme'), '=', '' ],
            ')',
        ]
    );

    my $row;
    my %paths;
    while($row = $cursor -> next) {
        my($site, $theme, $path, $type, $filename) = $row -> select(qw(site theme path type file));
        #warn "Considering $site:$theme:$path:$type:$filename\n";
        if(defined($paths{$path})
           && ($site && $theme 
               || $site && !$paths{$path}{site}
               || $theme && !$paths{$path}{site} && !$paths{$path}{theme}
               || !$site && !$theme && !$paths{$path}{site} && !$paths{$path}{theme}
           )
           || !defined($paths{$path})
        ) {
            $paths{$path} = { 
                site => $site, 
                theme => $theme, 
                type => $type, 
                filename => $filename 
            };
        }
    }

    # now sort the paths...
    my $cmp_cache = bless { } => __PACKAGE__;

    my @path_list = sort { $cmp_cache -> path_cmp($a, $b) } grep { defined $cmp_cache -> path_cmp($_, $params{uri}) } keys %paths;

    #warn "uri: $params{uri}\n";
    #warn "Path list: ", join(", ", @path_list), "\n";

    my @cps;
    my $startover = 1;
    my $old_args;

    my $session = $params{session};

    my $count = 0;
    my $context_replacements = { };
    while($startover && $count < 3) {
        $count++;
        $startover = 0;
        $old_args = { %{$params{args} || {}} };
        foreach my $k (keys %{$session -> {contexts}||{}}) {
            next if exists $old_args -> {"$k._context_id"};
            if($k =~ m{^_embedded(\._embedded)*$}) {
                if($session -> {contexts} -> {$k} -> {uri} eq $params{uri}) { 
                    $old_args -> {"$k._context_id"} = $session -> {contexts} -> {$k} -> {ctx};
                }
            }
            else {
                $old_args -> {"$k._context_id"} = $session -> {contexts} -> {$k};
            }
        }
        foreach my $k (keys %{$context_replacements}) {
            $old_args -> {"$k._context_id"} = $context_replacements -> {$k};
        }

        my $arg_path = '';
        foreach my $path (@path_list) {
            my($type, $filename) = @{$paths{$path}}{qw(type filename)};

            my $args = {
                map { $_ => $old_args -> {"_embedded.$_"} }
                    map { my $a = $_; $a =~ s{^_embedded\.}{}; $a }
                        grep { m{^_embedded\.} } keys %{$old_args}
            };
            delete @{$old_args}{grep { m{^_embedded\.} } keys %{$old_args}};
            my $cp;
            eval {
                $cp = $self -> get_content_provider(
                    type => $type,
                    filename => $filename,
                    args => $old_args,
                );
            };
            if($@ && UNIVERSAL::isa($@, 'Gestinanna::XSM::Op')) {
                my $e = $@;
                if($e -> op eq 'startover') {
                    #warn "Starting over...\n";
                    $startover = 1;
                    #warn "Keys in args: ", join(", ", keys %{$params{args}||{}}), "\n";
                    #warn "Keys in session contexts: ", join(", ", keys %{$params{session}->{contexts}||{}}), "\n";
                    delete @{$params{args}||{}}{grep { m{^_embedded(\._embedded)*\._context_id$} } keys %{$params{args}||{}} };
                    delete $session->{contexts} -> {$_} for grep { m{^_embedded(\._embedded)*$} } keys %{$session->{contexts}||{}};
                    my $ctxs = $e -> arg('contexts') || {};
                    foreach my $ctx ( keys %{$ctxs} ) {
                        #warn "replacing context for $arg_path$ctx with $$ctxs{$ctx}\n";
                        if($ctx eq '') {
                            my $a = $arg_path; $a =~ s{\.$}{};
                            $context_replacements -> {$a} = $ctxs -> {$ctx};
                        }
                        else {
                            $context_replacements -> {$arg_path . $ctx} = $ctxs -> {$ctx};
                        }
                    }
                }
            }
            else {
                warn "$@\n";
            }
            last if $startover;

            push @cps, $cp if $cp; # probably should be an error if $cp is undef
    
            $old_args = $args; # on to next one
            $arg_path .= '_embedded.';
        }
    }
    delete $session -> {contexts};

    $old_args -> {'sys.path_info'} = $self -> path_info;
    push @cps, $self -> get_content_provider(
        type => $params{type},
        filename => $params{filename},
        args => $old_args,
    );

    return @cps;
}

# match '/some/uri' or '/some/*'
# the * gets replaced with the remainder of the url, so a kind-of virtual directory, but not quite
# uri => with * means virtual directory
# filename => with * means replace * with remainder of url
sub uri_to_filename {
    my($self, $uri_map, $uri, $site, $cfg) = @_;

    my($content_type, $filename);
    my $orig_uri = $uri;

    while($uri) {
        #warn "Looking for uri [$uri] in site [$site]\n";
        my $cursor = $uri_map -> rows_where(
            where => [
                [ $uri_map -> column('uri'), '=', $uri ],
                [ $uri_map -> column('site'), '=', $site ],
            ]
        );   

        my $file;
        while($file = $cursor -> next) {
            ($content_type, $filename) = $file -> select('type', 'file');
            #warn "Got: [$content_type:$filename]\n";
            last if defined $cfg -> {$content_type};
        }

        if($content_type) {
            if($filename =~ m{/\*$}) {
                $uri =~ s{\*$}{};
                $filename =~ s{\*$}{};
                $orig_uri =~ s{^\Q$uri\E}{};
                $filename .= $orig_uri;
            }
            else {
                $uri =~ s{(.*)/\*$}{$1};
                $orig_uri =~ s{^\Q$uri\E}{};
                #warn "Path info: $orig_uri\n";
                $self -> path_info($orig_uri);
            }
            return($content_type, $filename);
        }
        #return if $uri eq '/*';

        #warn "uri (before /* subs): $uri\n";
        $uri =~ s{(.*)/\*$}{$1};
        $uri =~ s{(.*)/.*?$}{$1/*};
        #warn "uri (after /* subs): $uri\n";
    }
}

sub DESTROY {
    my $self = shift;

    no strict 'refs';

    my $pkg = $self -> config -> {package};

    #warn "Cleaning up session\n";
    if(defined $pkg) {
        untie %{$pkg . "::session"}; # save session
        undef %{$pkg . "::session"};
    }

    return unless $self -> {_cfg};
    
    $self -> {_cfg} -> resources -> {dbi} -> free($self -> {_dbh});
    if($self -> {_ldap}) {
        $self -> {_cfg} -> resources -> {ldap} -> free($self -> {_ldap});
    }
}

my $component = qr{[^\/\@\|\&]+};
        
sub path2regex ($) {
    my $self;
    $self = shift if @_ > 1;
    my $path = shift;
        
    return $self -> {_path_regexen} -> {$path}
        if $self && exists $self -> {_path_regexen} -> {$path};
        
    my @bits; #= split(/\|/, $path);
    foreach my $bit (split(/\s*\|\s*/, $path)) {
        my @xbits = split(/\s*\&\s*/, $bit);
    
        my $t;
        foreach (reverse @xbits) {
            $_ = "\Q$_\E";
            s{^(?:\\!\\!)+(.*)$}{$1};
            s{^\\!(?:\\!\\!)*(.*)$}{(?:(?!$1)|(?:!$1))};
            s{\\/(\\/)+}{\\\/+\((?:$component\\\/+)*\)(?:\\\/)*}g;
            s{\\\*}{\($component\)}g;
            s{\\/}{\\\/}g;
            if($t eq '') {
                $t = $_;
            }
            else {
                $t = "(?(?=$_)(?:$t))"; # hint: regex equiv of ?:
            }
        }
        push @bits, $t;
    }
        
    my $tpath = join(")|(?:", @bits);
        
    $tpath = qr{(?:$tpath)};
        
    return $tpath unless $self;
        
    return $self -> {_path_regexen}->{$path} = $tpath;
}

my $is_regex = qr{^!|//+|\*|\||\&};

sub path_cmp ($$) {
    my $self;

    if(@_ > 2) {
        $self = shift;
    }
    else {
        $self = bless { } => __PACKAGE__;
    }
    

    my($a, $b) = @_;
 
    return 1 if $a eq $b;

    return $self -> {_cmp_cache} -> {$a} -> {$b}
        if exists $self -> {_cmp_cache} -> {$a} -> {$b};
    
    if($a !~ m{$is_regex}) {
        return $self -> {_cmp_cache} -> {$a} -> {$b} = ($a cmp $b ? undef : 1) unless $b =~ m{$is_regex};

        my $bb = $self -> path2regex($b);
        #main::diag("b: $b => $bb");
        return $self -> {_cmp_cache} -> {$a} -> {$b} = -1 if $a =~ m{^$bb$};
        return $self -> {_cmp_cache} -> {$a} -> {$b} = undef unless $a =~ m{^$bb};
        #return $self -> {_cmp_cache} -> {$a} -> {$b} = $b =~ m{\&} ? undef : 1;
    }
    else {
        unless($b =~ m{$is_regex}) {
            my $aa = $self -> path2regex($a);
            #main::diag("a: $a => $aa");
            return $self -> {_cmp_cache} -> {$a} -> {$b} = 1 if $b =~ m{^$aa$};
            return $self -> {_cmp_cache} -> {$a} -> {$b} = undef unless $b =~ m{^$aa};
            #return $self -> {_cmp_cache} -> {$a} -> {$b} = ($a =~ m{\&} ? undef : -1);
        }
            
        my %abits = map { $_ => undef } split(/\s*\|\s*/, $a);
        my %bbits = map { $_ => undef } split(/\s*\|\s*/, $b);
        my $alla = scalar keys %abits;
        my $allb = scalar keys %bbits;
                
        return $self -> {_cmp_cache} -> {$a} -> {$b} = 1 unless $alla || $allb;
         
        return $self -> {_cmp_cache} -> {$a} -> {$b} = 1  if  $alla && !$allb;
        return $self -> {_cmp_cache} -> {$a} -> {$b} = -1 if !$alla &&  $allb;

        my $aa = $self -> path2regex(join("|", keys %abits));
        my $bb = $self -> path2regex(join("|", keys %bbits));
    
        # if a =~ B, then a <= B
        #main::diag("b: $bb");
        foreach my $p (keys %abits) {
            $abits{$p} = $p =~ m{^$bb$};
            #main::diag("a: $p => $abits{$p}");
        }
        #main::diag("a: $aa");
        foreach my $p (keys %bbits) {
            $bbits{$p} = $p =~ m{^$aa$};
            #main::diag("b: $p => $bbits{$p}");
        }
    
        my $numa = scalar(grep { $_ } values %abits);
        my $numb = scalar(grep { $_ } values %bbits);
    
        #main::diag("$a <=> $b: ($numa/$alla : $numb/$allb)");
     
        return $self -> {_cmp_cache} -> {$a} -> {$b} = undef if $numa == 0 && $numb == 0;   # disjoint

        return $self -> {_cmp_cache} -> {$a} -> {$b} = 1 if $numa <= $alla && $numb == $allb;  # A <= B

        return $self -> {_cmp_cache} -> {$a} -> {$b} = -1 if $numa == $alla && $numb < $allb;  # B < A

        return $self -> {_cmp_cache} -> {$a} -> {$b} = 0;  # overlap
    }
}

package Gestinanna::Upload;

sub new {
    my $class = shift;
    $class = ref $class || $class;

    return bless {
        @_
    } => $class;
}

sub name { $_[0] -> {name} }

sub filename { $_[0] -> {filename} }

sub fh { 
    my $self = shift;  # return IO::String object
    my $R = Gestinanna::Request -> instance;

    my $ob = $R -> factory(upload => object_id => $self -> {id});
    return IO::String -> new($ob -> content);
}

sub content {
    my $self = shift;  # return IO::String object
    my $R = Gestinanna::Request -> instance;

    my $ob = $R -> factory(upload => object_id => $self -> {id});
    return \($ob -> content);
}

sub size { $_[0] -> {size} }

sub info { @_ > 1 ? undef : { } }

sub type { $_[0] -> {type} }

sub hash { $_[0] -> {hash} }


1;
