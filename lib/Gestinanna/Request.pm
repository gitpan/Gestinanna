# $Id: Request.pm,v 1.3 2004/06/25 07:44:15 jgsmith Exp $

package Gestinanna::Request;

use strict;
no strict 'refs';

use Apache::Constants qw(OK DECLINED NOT_FOUND SERVER_ERROR);
use Apache::Cookie;
use Apache::Session::Flex;
use AxKit;
use Digest::SHA1;
use Gestinanna::Authz;
use Gestinanna::POF;
use Gestinanna::Schema;
use Gestinanna::SiteConfiguration;
use Gestinanna::Upload;
use Gestinanna::Util qw(:path);
use Storable ();

BEGIN {
    $__PACKAGE__::IN_MOD_PERL = $ENV{MOD_PERL} || 0;
    if($__PACKAGE__::IN_MOD_PERL) {
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

=begin testing

# in_mod_perl

is(__PACKAGE__:: __METHOD__, 0);

=end testing

=cut

sub in_mod_perl { $__PACKAGE__::IN_MOD_PERL; }

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
        $self -> {site} = $self -> {_gst} -> config;
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

=begin testing

# instance

is(__PACKAGE__ -> instance, __OBJECT__);

=end testing

=cut

sub instance { $_[0] -> new }

# need to handle file uploads -- Gestinanna::Upload

sub read_session {
    my($self, $hash, $id) = @_;

    no strict 'refs';
    my $dbh;
    if(UNIVERSAL::isa($self -> {_dbh}, 'Alzabo::Runtime::Schema')) {
        $dbh = $self -> {_dbh} -> driver -> handle;
    }
    else {
        $dbh = $self -> {_dbh};
    }

    eval {
        local($SIG{__DIE__});
        tie %{$hash}, 'Apache::Session::Flex', $id, {
            Commit => 1,
            %{$self -> {site} -> session_params},
            Handle => $dbh,
            LockHandle => $dbh,
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
                %{$self -> {site} -> session_params},
                Handle => $dbh,
                LockHandle => $dbh,
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

    delete @{$self}{qw(_dbh _content_provider _decline)};

    my($site, $pkg, $resources);
    $site = $self -> {site};

    $pkg = $site -> package if defined $site;

    # need to just get a factory and be happy...
    # then worry about which resources to use for mappings
    $resources = $self -> {_gst} -> resources if defined $self -> {_gst};

    $self -> {_dbh} = $resources -> {dbi} -> get() if defined $resources -> {dbi};

    if($resources -> {ldap}) {
        my $ldap = $resources -> {ldap} -> get();
        $self -> {_ldap} = $ldap;
        $self -> {_ldap_schema} = ${"${pkg}::ldap_schema"} ||= $ldap -> schema;
    }


    my $alzabo_schema;
    if(UNIVERSAL::isa($self -> {_dbh}, 'Alzabo::Runtime::Schema')) {
        $alzabo_schema = $self -> {_dbh};
    }
    else {
        $alzabo_schema = Gestinanna::Schema -> load_schema(
            name => $self -> {_gst} -> {schema},
            dbh => $self -> {_dbh},
        );
    }
    $self -> {_alzabo} = $alzabo_schema;
    $self -> {_authz} = Gestinanna::Authz -> new(alzabo_schema => $alzabo_schema);


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

    my $cookie = $site -> session_cookie($self -> {_r});#Apache::Cookie->fetch;
            
    #my $cookie = $cookies->{$config -> {'session'} -> {'cookie'} -> {'name'} || 'SESSIONID'};
    $cookie_session_id = $cookie -> value if defined $cookie;

    my $session = $pkg . "::session";

    if((defined($cookie_session_id) && defined($uri_session_id) && $cookie_session_id eq $uri_session_id)
       || (defined($cookie_session_id) && !defined($uri_session_id))
       || (defined($uri_session_id) && !defined($cookie_session_id))
    ) {
        my $session_id = $cookie_session_id || $uri_session_id;
        my $id = $self -> read_session($session, $session_id);
        return unless $id; # need to put up an error page
        if($id ne $session_id) {
            # need to do a redirect - check for cookies, etc.
            my $cookie = $site -> new_cookie($id);
            Apache ->
                request ->
                    err_header_out(
                        "Set-Cookie" => $cookie -> as_string,
                            #($config -> {'session'} -> {'cookie'} -> {'name'} || 'SESSIONID') . "=$id; Path=/;"
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
        my $id = $self -> read_session($session, undef);
        #warn "new id: $id\n";
        # do redirect
        my $cookie = $site -> new_cookie($id);
        Apache ->
            request ->
                err_header_out(
                    "Set-Cookie" => $cookie -> as_string,
        #                ($config -> {'session'} -> {'cookie'} -> {'name'} || 'SESSIONID') . "=$id; Path=/;"
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

    my $content_providers = $site -> content_providers;
    while(($uri = shift(@uris)) && !$content_provider_class) {
        ($content_type, $filename) = $self -> uri_to_filename($uri_map, $uri, $site, $content_providers);

        $content_provider_class = $content_providers -> {$content_type} -> {class};
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

    my $factory = $site -> factory(resources => $resources, authz => $self -> {_authz});

    my $actor;
    if($session -> {actor_id}) {
        $actor = $factory -> new(actor => (object_id => $session -> {actor_id}));
    }

    #warn "Session{actor_id}: " . $session -> {actor_id} . "\n";
    if($actor && $actor -> is_live) {
        $factory = $factory -> new(_factory => (
            %$factory,
            actor => $actor,
        ));
    }
    elsif(defined $site -> anonymous_id) { # set up guest actor
        $actor = $factory -> new(actor => (
            object_id => $site -> anonymous_id,
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
    my $alzabo_schema = $self -> {_alzabo};

    if($alzabo_schema -> has_table('Embedding_Map')) {
        my $embed_table = $alzabo_schema -> table('Embedding_Map');
        @embeddings = $self -> providers(
            filename => $self -> {filename},
            type => $self -> {type},
            %params,
            args => $self -> {args},
            uri => $self -> {base_uri},
            site => $self -> {site},
            theme => $self -> {site} -> default_theme,
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

sub config { $_[0] -> {site} ||= Gestinanna::SiteConfiguration -> new }

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

    #warn "$self -> get_content_provider() : ", Data::Dumper -> Dump([\%params]);
    return unless defined $params{type} && defined $params{filename};

    my $config = $self -> {site};

    my $content_provider_class = $config -> content_providers -> {$params{type}} -> {class};

    #warn "$params{type} => $content_provider_class\n";
    return unless defined $content_provider_class;

    #if($self -> apache_request -> path_info) { # subject to change
    #    $params{args}{'sys.path_info'} = $self -> apache_request -> path_info;
    #}

    return $content_provider_class -> init(
        %params,
        config => $config -> content_providers -> {$params{type}},
        request => $self,
    );
}

sub _get_url {
    my($self, $site, $type, $id, $path_info) = @_;

    my $table = $self -> {_alzabo} -> table('Uri_Map');
    my $url;

    #warn "_get_url($site, $type, $id, $path_info)\n";

    my $urls = $table -> rows_where(
        where => [
            [ $table -> column('type'), '=',  $type, ],
            [ $table -> column('file'), '=', $id, ],
            [ $table -> column('site'), '=', $site, ],
        ],
    );

    if($urls) {
        while($url = $urls -> next) {
            my $uri = $url -> select('uri');
            if($path_info ne '') {
                if($uri =~ m{/\*$}) {
                    #warn "Returning [$uri]\n";
                    return $uri;
                }
            }
            else {
                #warn "Returning [$uri]\n";
                return $uri;
            }
        }
    }

    $urls = $table -> rows_where(
        where => [
            [ $table -> column('type'), '=',  $type, ],
            [ $table -> column('file'), '=', $id, ],
            [ $table -> column('site'), '=', 0, ],
        ],
    );

    if($urls) {
        while($url = $urls -> next) {
            my $uri = $url -> select('uri');
            if($path_info ne '') {
                if($uri =~ m{/\*$}) {
                    #warn "Returning [$uri]\n";
                    return $uri;
                }
            }
            else {
                #warn "Returning [$uri]\n";
                return $uri;
            }
        }
    }
}

sub get_url {
    my($self, %params) = @_;

    return unless defined $params{type} && defined $params{filename};

    my $site = $self -> {site};

    # we need extra path information preserved

    #  /file-manager/* /sys/file-manager

    # if we hack off anything to create a path_info, then we expect * in the url
    my $path_info = '';
    my $type = $params{type};
    my $id = $params{filename};
    while($id) {
        my $url = $self -> _get_url($site, $type, $id, $path_info);
        #warn "$site:$type:$id:$path_info => $url\n";
        return "$url$path_info"
            if defined($url) && ( $path_info eq '' || $url =~ s{/\*$}{} );
        # remove a last component (/string);
        if($id =~ s{(/[^/]*)$}{}) {
            $path_info = "$1$path_info";
        }
        else {
            return; # nothing to remove
        }
    }
}

sub factory { $_[0] -> {factory} }

sub session { $_[0] -> {session} }

# returns _all_ providers, including last one
sub providers {
    my($self, %params) = @_;

    my $site_cfg = $params{site};
    my $site_path = $site_cfg -> site_path;

    my @embeddings;
    my %paths;
    foreach my $site (@{$site_path || []}) {
        my $cursor = $params{table} -> rows_where(
            where => [
                '(',
                  [ $params{table} -> column('site'), '=', $site ],
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
        while($row = $cursor -> next) {
            my($site, $theme, $path, $type, $filename) = $row -> select(qw(site theme path type file));
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
    }

    # now sort the paths...
    my @path_list = sort { path_cmp($a, $b) } grep { defined path_cmp($_, $params{uri}) } keys %paths;

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
    my($self, $uri_map, $uri, $site_cfg, $cfg) = @_;

    my($content_type, $filename);
    my $orig_uri = $uri;

    my $site_path = $site_cfg -> site_path;

    while($uri) {
        foreach my $site (@{$site_path || []}) {
            my $cursor = $uri_map -> rows_where(
                where => [
                    [ $uri_map -> column('uri'), '=', $uri ],
                    [ $uri_map -> column('site'), '=', $site ],
                ]
            );   
    
            my $file;
            while($file = $cursor -> next) {
                ($content_type, $filename) = $file -> select('type', 'file');
                last if defined $cfg -> {$content_type};
            }
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

    my $pkg = $self -> config -> package;

    #warn "Cleaning up session\n";
    if(defined $pkg) {
        untie %{$pkg . "::session"}; # save session
        undef %{$pkg . "::session"};
    }

    delete $self -> {_alzabo};

    return unless $self -> {_gst};
    
    $self -> {_gst} -> resources -> {dbi} -> free($self -> {_dbh}) if $self -> {_dbh};
    if($self -> {_ldap}) {
        $self -> {_gst} -> resources -> {ldap} -> free($self -> {_ldap});
    }
}

1;

__END__
