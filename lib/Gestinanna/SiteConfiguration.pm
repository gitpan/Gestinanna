package Gestinanna::SiteConfiguration;

use Storable ();
use XML::LibXML;
use Gestinanna::POF;
use Gestinanna::Request;
use Gestinanna::Workflow::Factory;

use strict;

=begin testing

# new

__OBJECT__ = __PACKAGE__ -> __METHOD__;

isa_ok(__OBJECT__, '__PACKAGE__');

=end testing

=cut

sub new {
    my $class = shift;

    return bless { @_ } => $class;
}

=begin testing

# parse_config

__OBJECT__ -> parse_config(<<'EOXML');
<configuration
  package="__PACKAGE__::Test"
>
  <tagpath>
    <production>
      <tag>test-1.0</tag>
    </production>
    <pre-production>
      <tag>testing-1.1</tag>
    </pre-production>
    <test>
      <tag>testinging-1.2</tag>
    </test>
  </tagpath>

  <themes default="_default">
    <theme name="_default">
    </theme>
  </themes>

  <session>
    <cookie name="SESSION_ID"/>
  </session>
  <content-provider
    type="document"
    class="Gestinanna::ContentProvider::Document"
  />
  <content-provider
    type="xslt"
    class="Gestinanna::ContentProvider::Document"
  />

  <content-provider
    type="xsm"
    class="Gestinanna::ContentProvider::XSM"
    view-type="view"
    context-type="context"
  > 
    <config>
      <cache dir="/data/gestinanna/${schema_name}/site_${site_number}"/>
      <taglib>Gestinanna::XSM::Auth</taglib>
      <taglib>Gestinanna::XSM::Authz</taglib>
      <taglib>Gestinanna::XSM::ContentProvider</taglib>
      <taglib>Gestinanna::XSM::Diff</taglib>
      <taglib>Gestinanna::XSM::Digest</taglib>
      <taglib>Gestinanna::XSM::Gestinanna</taglib>
      <taglib>Gestinanna::XSM::POF</taglib>
      <taglib>Gestinanna::XSM::SMTP</taglib>
    </config>
  </content-provider>

  <content-provider
    type="view"
    class="Gestinanna::ContentProvider::TT2"
  />
  
  <content-provider
    type="portal"
    class="Gestinanna::ContentProvider::Portal"
  />

  <data-type id="alzabo" class="Gestinanna::POF::Alzabo"/>
  <data-type id="ldap"   class="Gestinanna::POF::LDAP"/>
  <data-type id="repository" class="Gestinanna::POF::Repository"/>

  <security-type id="read-write" class="Gestinanna::POF::Secure::Gestinanna"/>
  <security-type id="read-only" class="Gestinanna::POF::Secure::ReadOnly"/>

  <content-type id="tt2" class="Gestinanna::ContentProvider::TT2"/>
  <content-type id="xsm" class="Gestinanna::ContentProvider::XSM"/>
  <content-type id="portal" class="Gestinanna::ContentProvider::Portal"/>
  <content-type id="document" class="Gestinanna::ContentProvider::Document"/>

  <data-provider
    type="xsm"
    data-type="repository"
    repository="XSM"
    description="eXtensible State Machine"
    security="read-write"
  />
  <data-provider
    type="document"
    data-type="repository"
    repository="Document"
    description="Document"
    security="read-write"
  />
  <data-provider
    type="portal"
    data-type="repository"
    repository="Portal"
    description="Portal"
    security="read-write"
  />
  <data-provider
    type="view"
    data-type="repository"
    repository="View"
    description="View"
    security="read-write"
  />
  <data-provider
    type="site"
    data-type="alzabo"
    table="Site"
  />
  <data-provider
    type="uri-map" 
    data-type="alzabo"
    table="Uri_Map"
  />
  <data-provider
    type="user"
    data-type="alzabo"
    table="User"
    security="read-write"
  />
  <!-- an actor is a read-only user object, basicly -->
  <data-provider
    type="actor"
    data-type="alzabo"
    table="User"
    security="read-only"
  />
    
  <data-provider
    type="username"
    data-type="alzabo"
    table="Username"
    security="read-write" 
  />
  <data-provider
    type="xslt" 
    data-type="repository"
    repository="XSLT"
    description="XSLT" 
    security="read-write"
  />
  <data-provider
    type="folder"
    data-type="alzabo"
    table="Folder"
    security="read-write"
  />
</configuration>
EOXML

is(__OBJECT__ -> package, "__PACKAGE__::Test");

=end testing

=cut

sub parse_config {
    my($self, $conf) = @_;

    return unless $conf !~ m{^\s*$};

    my $parser = XML::LibXML -> new;
    my $doc = $parser -> parse_string($conf);

    my $root = $doc -> getDocumentElement;

    my %conf;
    $self -> {config} = \%conf;

    $conf{package} = $root -> getAttribute('package');

    $conf{anonymous_id} = $root -> getAttribute('anonymous-id');

    # <tagpath/>
    my $tagpath = $root -> findnodes('tagpath/*');

    # have <tagpath><test><tag></test><pre-production/><production/></tagpath>
    my %tagpaths = (
        test => [ ],
        'pre-production' => [ ],
        production => [ ],
    );
    foreach my $part ($tagpath -> get_nodelist) {
        my $type = $part -> nodeName;
        next unless exists $tagpaths{$type};
        push @{$tagpaths{$type}},
             map { $_ -> textContent } $part -> findnodes('tag');
    }

    $conf{tagpaths} = \%tagpaths;

    # <themes/>

    $conf{default_theme} = $root -> findvalue('themes/@default');
    my $themes = $root -> findnodes('themes/theme');

    my %themes;
    foreach my $theme ($themes -> get_nodelist) {
        my $xml = join("\n", map { $_ -> toString} ($theme -> childNodes));
        $xml =~ s{^\s*}{};
        $xml =~ s{\s*$}{};
        $themes{$theme -> findvalue('@id')} = $xml;
    }

    $conf{themes} = \%themes;

    foreach my $type (qw(data content security)) {
        my $dts = $root -> findnodes($type . '-type');
        my %types;
        foreach my $dt ($dts -> get_nodelist) {
            $types{$dt -> getAttribute('id')}
                = $dt -> getAttribute('class');
        }
        $conf{$type . '_types'} = \%types;
    }

    foreach my $provider (qw(data content)) {
        my %providers;

        my $dps = $root -> findnodes($provider.'-provider');
        $self -> {parsing_provider_type} = $provider;

        foreach my $dp ($dps -> get_nodelist) {
            my $type = $dp -> getAttribute('type');
            my $config = $self -> parse_provider_config($dp);
            $providers{$type} = $config if $config;
        }

        $conf{$provider . "_provider"} = \%providers;
        delete $self -> {parsing_provider_type};
    }

    $conf{session} = {
        cookie => {
            map { $_ => $root -> findvalue("session/cookie/\@$_") }
            qw( name secure expires )
        },
        store => {
            map { $_ => $root -> findvalue("session/store/\@$_") }
            qw( store lock generate serialize )
        },
    };

    my($dp) = $root -> findnodes('workflow');
    if($dp) {
        foreach my $attr (@Gestinanna::Workflow::Factory::XML_ATTRIBUTES) {
            $conf{workflow}{params}{$attr} = $dp -> getAttribute($attr);
        }

        $conf{workflow}{config} = Gestinanna::Workflow::Factory -> parse_config(
            site => $self,
            params => $conf{workflow}{params},
            nodes => [ ($dp -> childNodes) ]
        );
    }
    warn "Workflow config: ", Data::Dumper -> Dump([$conf{workflow}]);

#    $self -> {config} = \%conf;
}

sub store_config {
    my($self) = @_;

    my $parser = XML::LibXML -> new;
    my $dom = $parser -> createDocument( "1.0", "UTF8" );
    my $config = $self -> {config};

    my $root = $dom -> createElement( 'configuration' );
    $root -> setAttribute(package => $config -> {package})
        if defined $config -> {package};
    $root -> setAttribute('anonymous-id' => $config -> {anonymous_id})
        if defined $config -> {anonymous_id};

    $dom -> setDocumentElement( $root );

    my $session = $dom -> createElement( 'session' );
    foreach my $part (qw(cookie store)) {
        my $node = $dom -> createElement( $part );
        foreach my $attr (keys %{$config -> {session} -> {$part}||{}}) {
            $node -> setAttribute($attr => $config -> {session} -> {$part} -> {$attr})
                if defined $config -> {session} -> {$part} -> {$attr};
        }
        $session -> appendChild( $node );
    }
    $root -> appendChild( $session );

    my $tagpath = $dom -> createElement( 'tagpath' );
    foreach my $type (keys %{$config -> {tagpaths} || {}}) {
        my $parent_node = $dom -> createElement( $type );
        foreach my $tag (@{$config -> {tagpaths} -> {$type} || []}) {
            $parent_node -> appendTextChild( 'tag', $tag );
        }
        $tagpath -> appendChild($parent_node);
    }

    $root -> appendChild( $tagpath );

    my $themes = $dom -> createElement( 'themes' );
    $themes -> setAttribute(default => $config -> {default_theme})
        if defined $config -> {default_theme};

    foreach my $theme (keys %{$config -> {themes} || {}}) {
        my $theme_node = $dom -> createElement( 'theme' );
        $theme_node -> setAttribute(id => $theme);
        if($config -> {themes} -> {$theme}) {
            my $fragment = $parser->parse_xml_chunk($config -> {themes} -> {$theme});
            $theme_node -> appendChild( $_ ) for $fragment -> childNodes;
        }
        $themes -> appendChild( $theme_node );
    }

    $root -> appendChild($themes);

    foreach my $provider (qw(data content security)) {
        foreach my $id (keys %{$config -> {$provider . '_types'} || {}}) {
            my $node = $dom -> createElement( $provider . '-type' );
            $node -> setAttribute( id => $id );
            $node -> setAttribute( class => $config -> {$provider . '_types'} -> {$id} );
            $root -> appendChild( $node );
        }

        foreach my $dp (keys %{$config -> {"${provider}_provider"} || {}}) {
            my $dp_root = $dom -> createElement( "${provider}-provider" );
            $self -> {storing_provider_type} = $provider;
            $self -> store_provider_config(
                 $dp_root, 
                 $config -> {"${provider}_provider"} -> {$dp}
            );
            $dp_root -> setAttribute( type => $dp );
            $root -> appendChild( $dp_root );
            delete $self -> {storing_provider_type};
        }
    }

    return $dom -> toString(1);
}

sub parse_provider_config {
    my($self, $dp) = @_;

    my $type = $self -> {parsing_provider_type} . '_types';
    my $type_attr = $self -> {parsing_provider_type} . '-type';
    my $types = $self -> _types($self -> {parsing_provider_type});
    my $data_type = $dp -> getAttribute($type_attr);

    my $class = $types -> {$data_type};

    eval { eval "require $class;" };
    return if $@;
    my %params;

    no strict 'refs';

    foreach my $attr (@{"${class}::XML_ATTRIBUTES"}, 'resource') {
        $params{$attr} = $dp -> getAttribute($attr);
    }

    my $config = { };
    $config = $class -> parse_config(
        site => $self,
        params => \%params,
        nodes => [ ($dp -> childNodes) ]
    ) if $class && $class -> can('parse_config');

    return {
        params => \%params,
        class => $class,
        type => $data_type,
        config => $config,
    };
}

sub store_provider_config {
    my($self, $root, $config) = @_;

    my $type = $self -> {storing_provider_type} . "_types";
    my $attr = $self -> {storing_provider_type} . "-type";
    my $types = $self -> {$type};

    my $class = $types -> {$config->{type}};
        
    eval { eval "require $class;" };
    return if $@;

    $class -> store_config(
        site => $self,
        params => $config -> {params},
        config => $config -> {config},
        root => $root,
    ) if $class -> can('store_config');

    foreach my $attr (@{"${class}::XML_ATTRIBUTES"}) {
        $root -> setAttribute($attr, $config -> {params} -> {$attr})
            if defined $config -> {params} -> {$attr};
    }
}

sub build_object_class {
    my($self, %params) = @_;

    my($package, $config) = @params{qw(class config)};

    # passes it along to the right perl class
    my $class = $self -> {data_types} -> {$config -> {'data-type'}};
    eval { eval "require $class;" };
    return if $@;
    $class -> build_object_class(
        site => $self,
        class => $package,
        config => $config -> {config},
        params => $config -> {params},
    );
}

###
### accessors
###

# these need to reference both the global and local configs

sub parent { $_[0] -> {parent} }

sub anonymous_id {
    return $_[0] -> {config} -> {anonymous_id}
        if $_[0] -> {config} -> {anonymous_id} ne '';
    return $_[0] -> {parent} -> anonymous_id
        if defined $_[0] -> {parent};
}

sub new_cookie {  # returns an Apache::Cookie object
    my $self = shift;
    my $r;
    $r = shift if ref $_[0];

    my $config = $self -> {config};
    my $parent = $self -> {parent};
    my $cookie;

    if($parent) {
        $cookie = $parent -> new_cookie($r);
    }
    else {
        if($r) {
            require Apache::Cookie;
            $cookie = Apache::Cookie -> new($r);
        }
        else {
            require CGI::Cookie;
            $cookie = CGI::Cookie -> new;
        }
    }

    # allow override of parent if we went to parent
    foreach my $field (qw(name expires secure)) {
        my $v = $self -> session_cookie_field($field);
        $cookie -> $field($v) if defined($v) && $v ne '';
    }

    $cookie -> value($_[0]) if @_;

    return $cookie;
}

sub session_cookie_field {
    my($self, $field) = @_;

    return $self -> {config} -> {session} -> {cookie} -> {$field}
        if $self -> {config} -> {session} -> {cookie} -> {$field} ne '';
    return $self -> {parent} -> session_cookie_field($field)
        if $self -> {parent};
}

sub session_cookie {
    my $self = shift;
    my $name = $self -> session_cookie_field('name');

    return unless defined $name && $name ne '';

    my $cookies;
    if(Gestinanna::Request -> in_mod_perl) {
        $cookies = Apache::Cookie -> fetch;
    }
    else {
        $cookies = CGI::Cookie -> fetch;
    }

    return $cookies -> {$name};
}

sub session_params {
    my $self = shift;

    my $config = $self -> {config};
    my $parent = $self -> {parent};

    my $params = { };

    $params = $parent -> session_params if $parent;

    foreach my $p (qw(store lock generate serialize)) {
        $params -> {ucfirst $p} = $config -> {session} -> {store} -> {$p}
            if $config -> {session} -> {store} -> {$p};
    }

    return $params;
}

=begin testing

# package

is(__OBJECT__ -> package, "__PACKAGE__::Test");

=end testing

=cut

sub package {
    my $self = shift;

    my $global_package;

    if($self -> {parent}) {
        $global_package = $self -> {parent} -> package;
    }
    if(defined $global_package && $global_package =~ m{::$}) {
        return $global_package . $self -> {config} -> {package};
    }
    return $self -> {config} -> {package} if defined $self -> {config} -> {package};
    return $global_package;
}

sub default_theme {
    my $self = shift;

    return $self -> {config} -> {default_theme}
        if defined $self -> {config} -> {default_theme}
           && $self -> {config} -> {default_theme} ne '';

    return $self -> {parent} -> default_theme
       if defined $self -> {parent};
}

foreach my $type (qw(data content)) {
   eval qq{
       sub ${type}_providers { \$_[0] -> _providers('@{[$type]}') }
   };
}

sub _providers {
    my($self, $type) = @_;

    my $providers = { };

    $providers = $self -> {parent} -> _providers($type) if $self -> {parent};

    my $local = $self -> {config} -> {"${type}_provider"};
    foreach my $id (keys %$local) {
        $providers -> {$id} = Storable::dclone($local -> {$id});
    }

    return $providers;
}

foreach my $type (qw(data content security)) {
   eval qq{
       sub ${type}_types { \$_[0] -> _types('@{[$type]}') }
   };
}

sub _types {
    my($self, $type) = @_;

    my $types = { };

    $types = $self -> {parent} -> _types($type) if $self -> {parent};

    my $local = $self -> {config} -> {"${type}_types"};
    @{$types}{keys %$local} = values %$local;

    return $types;
}

sub site_path {
    my $self = shift;

    return $self -> {_site_path} if ref $self -> {_site_path};

    return $self -> {_site_path} = [ $self -> {site}, @{$self -> {parent} -> site_path} ]
        if $self -> {parent};
    return $self -> {_site_path} = [ $self -> {site} ];
}

=begin testing

# tag_path

is_deeply([ __OBJECT__ -> tag_path('production') ], [q(test-1.0)]);
is_deeply([ __OBJECT__ -> tag_path('pre-production') ], [q(testing-1.1)]);
is_deeply([ __OBJECT__ -> tag_path('test') ], [q(testinging-1.2)]);

=end testing

=cut

sub tag_path {
    my($self, $type) = @_;

    my @tags = @{$self -> {config} -> {tagpaths} -> {$type} || []};
    push @tags, $self -> {parent} -> tag_path($type) if $self -> {parent};

    return @tags;
}

=begin testing

# factory_class

is(__OBJECT__ -> __METHOD__, "__PACKAGE__::Test::POF");

=end testing

=cut

sub factory_class { $_[0] -> package . "::POF" };

=begin testing

# workflow_factory_class

is(__OBJECT__ -> __METHOD__, "__PACKAGE__::Test::Workflows");

=end testing

=cut

sub workflow_factory_class { $_[0] -> package . "::Workflows" };

=begin testing

# provider_class

is(__OBJECT__ -> __METHOD__(data => 'view'), "__PACKAGE__::Test::DataProvider::view");

=end testing

=cut

sub provider_class { 
    my $type = $_[2];
    $type =~ s{[^A-Za-z0-9_]}{_}g;
    return( ($_[0] -> package) . "::" . ucfirst($_[1]) . "Provider::$type");
};

=begin testing

# factory

my $factory = __OBJECT__ -> factory(
    tag_path => 'test',
);

is_deeply($factory -> {tag_path}, [qw(
    testinging-1.2
    testing-1.1
    test-1.0
)]);

=end testing

=cut

sub factory {
    my($self, %params) = @_;

    my $factory_class = $self -> factory_class;

    # need to populate factory classes and match resources, etc. ...
    # a lot of this will need to be taken from the Apache::Gestinanna stuff, probably
    my @tags = ( );
    my $tag_level = 0;
    $tag_level |= 1 if $params{tag_path} eq 'pre-production';
    $tag_level |= 2 if $params{tag_path} eq 'test';
    $tag_level |= 4 if $params{actor} && $params{tag_path} eq 'personal';

    push @tags, $params{actor} -> object_id if $tag_level >= 4;
    push @tags, $self -> tag_path('test')  if $tag_level >= 2;
    push @tags, $self -> tag_path('pre-production') if $tag_level >= 1;
    push @tags, $self -> tag_path('production');

    my %tag_seen;
    @tags = grep { !$tag_seen{$_}++ } @tags;

    return $factory_class -> new(
        _factory => (
            _resources => $params{resources},
            site => $self,
            tag_path => \@tags,
            ($params{actor} ? ( actor => $params{actor} ) : ( ) ),
        )
    );
}

=begin testing

# workflow_factory

=end testing

=cut

sub workflow_factory {
    my($self, %params) = @_;

    if($self -> {config} -> {workflow}) {
        my $class = $self -> workflow_factory_class;

        if(!UNIVERSAL::isa($class, "Gestinanna::Workflow::Factory")) {
            no strict 'refs';
            require Gestinanna::Workflow::Factory;
            push @{"${class}::ISA"}, 'Gestinanna::Workflow::Factory';
            $class -> instance -> config($self -> {config} -> {workflow});
            $class -> instance -> add_config(
                persister => {
                    name => 'default',
                    class => 'Gestinanna::Workflow::Persister',
                    source => $params{'workflow-store-provider'},
                },
            );
        }

        return $class -> instance;
    }
    if($self -> {parent}) {
        return $self -> {parent} -> workflow_factory(%params);
    }
}

=begin testing

# build_factory

__OBJECT__ -> build_factory;

my $factory = __OBJECT__ -> factory_class;
my $f_class;
my $class;

foreach my $type (qw(
    xsm document portal view site uri-map user actor username xslt folder
)) {
    $class = __OBJECT__ -> provider_class(data => $type);

    $f_class = undef;

    eval {
        $f_class = $factory -> get_factory_class($type);
    };

    ok(!$@, "Data provider exists for type $type");

    if($f_class =~ m{::Object$}) {
        is($f_class, "${class}::Object", "Data provider for type $type is a class");
        ok(UNIVERSAL::VERSION("${class}::Tag"), "${class}::Tag is defined");
        ok(UNIVERSAL::VERSION("${class}::Description"), "${class}::Description is defined");
    }
    else {
        is($f_class, $class, "Data provider for type $type is a class");
    }

    ok(UNIVERSAL::VERSION($class), "$class is defined");
}

=end testing

=cut

sub build_factory {
    my $self = shift;

    no strict 'refs';

    my $factory_class = $self -> factory_class;

    @{"${factory_class}::ISA"} = qw(Gestinanna::POF);

    my $data_providers = $self -> data_providers;

    foreach my $type (keys %{$data_providers}) {
        my $provider_class = $self -> provider_class(data => $type);
        my $class = $data_providers -> {$type} -> {class};

        #eval "require $provider_class;";

        next unless $class -> can('build_object_class');
        $class -> build_object_class(
            params => $data_providers -> {$type} -> {params},
            class => $provider_class,
            config => $data_providers -> {$type} -> {config},
            site => $self,
        ) or next;

        my $file = $provider_class;
        $file =~ s{::}{/}g;
        $INC{$file . ".pm"} = 1;
        @{"${provider_class}::VERSION"} = 1;


        if(UNIVERSAL::can($provider_class, 'add_factory_types')) {
            $provider_class -> add_factory_types($factory_class, $type);
            my $method;
            $provider_class -> $method(
                type => $type, 
                factory => $factory_class,
                params => $data_providers -> {$type} -> {params},
                config => $data_providers -> {$type} -> {config},
                site => $self,
            ) if $method = $provider_class -> can('set_factory_resources');
        }
        else {
            $factory_class -> add_factory_type($type => $provider_class);
            $factory_class -> set_resources($type => $provider_class -> resource_requirements(
                params => $data_providers -> {$type} -> {params},
                config => $data_providers -> {$type} -> {config},
                site => $self,
            ) ) if $provider_class -> can('resource_requirements');
        }
    }
}

1;

__END__

=head1 NAME

Gestinanna::SiteConfiguration - Site configuration information manager

=head1 SYNOPSIS

 my $site = Gestinanna::SiteConfiguration -> new( 
     parent => $parent_site_config 
 );

 $site -> parse_config( $xml_string );

 $cookie = $site -> new_cookie; # session cookie
 $factory = $site -> factory( $resources );
 $package = $site -> package
 $params = $site -> session_params;

Questionable:

 $content_provider = $site -> get_content_provider( $type , ... )
 $data_provider = $site -> get_data_provider( $type, ... )

=head1 DESCRIPTION

This package manages the configuration information for a single site.  
The constructor can take a site configuration object for the global 
configuration, which provides information that may be overridden by 
the site-specific configuration.
