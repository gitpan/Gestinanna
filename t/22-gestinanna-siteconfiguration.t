use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::SiteConfiguration;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::SiteConfiguration';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;

BEGIN {
use Gestinanna::PackageManager;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 13 

use Gestinanna::PackageManager;

our $package_manager = Gestinanna::PackageManager -> new( directory => 'packages' );


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::PackageManager;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 13 

use Gestinanna::PackageManager;

our $package_manager = Gestinanna::PackageManager -> new( directory => 'packages' );


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::SchemaManager;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 28 

use Gestinanna::SchemaManager;
our $schema_manager = Gestinanna::SchemaManager -> new();
$schema_manager -> add_packages($package_manager);

$schema_manager -> _load_runtime;
$schema_manager -> _load_create;
$Alzabo::Config::CONFIG{'root_dir'} = 'alzabo';
mkdir 'alzabo' unless -d 'alzabo';
my $schemas_dir = File::Spec -> catdir(qw(alzabo schemas));
mkdir $schemas_dir unless -d $schemas_dir;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::SchemaManager;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 28 

use Gestinanna::SchemaManager;
our $schema_manager = Gestinanna::SchemaManager -> new();
$schema_manager -> add_packages($package_manager);

$schema_manager -> _load_runtime;
$schema_manager -> _load_create;
$Alzabo::Config::CONFIG{'root_dir'} = 'alzabo';
mkdir 'alzabo' unless -d 'alzabo';
my $schemas_dir = File::Spec -> catdir(qw(alzabo schemas));
mkdir $schemas_dir unless -d $schemas_dir;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::SchemaManager::Schema;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 4 

our $schema;
eval {
    $schema = $schema_manager -> load_schema(name => 'test');
};

if($@ || !$schema) {
    my $s = $schema_manager -> create_schema(name => 'test', rdbms => 'SQLite');
    $s -> add_schema('site');
    foreach my $prefix (qw(
        View
        XSLT
        XSM
        Document
        Portal
        WorkflowDef
    )) {
        $s -> add_schema('repository', prefix => $prefix);
    }

    $s -> add_schema('workflow', prefix => 'Workflow');

    $s -> add_schema('authorization'); # adds Authz stuff and bare user accounts

    $s -> make_live;

    $schema = $schema_manager -> load_schema(name => 'test');
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::SchemaManager::Schema;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 4 

our $schema;
eval {
    $schema = $schema_manager -> load_schema(name => 'test');
};

if($@ || !$schema) {
    my $s = $schema_manager -> create_schema(name => 'test', rdbms => 'SQLite');
    $s -> add_schema('site');
    foreach my $prefix (qw(
        View
        XSLT
        XSM
        Document
        Portal
        WorkflowDef
    )) {
        $s -> add_schema('repository', prefix => $prefix);
    }

    $s -> add_schema('workflow', prefix => 'Workflow');

    $s -> add_schema('authorization'); # adds Authz stuff and bare user accounts

    $s -> make_live;

    $schema = $schema_manager -> load_schema(name => 'test');
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::Authz;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 15 

our $schema;
our $authz;

$authz = Gestinanna::Authz -> new(
    alzabo_schema => $schema
);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


}

# method: anonymous_id

$builder -> begin_tests('anonymous_id');


$builder -> end_tests('anonymous_id');

# method: build_object_class

$builder -> begin_tests('build_object_class');


$builder -> end_tests('build_object_class');

# method: new

$builder -> begin_tests('new');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 11 

$objects{'_default'} = Gestinanna::SiteConfiguration -> new;

isa_ok($objects{'_default'}, 'Gestinanna::SiteConfiguration');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');

# method: parse_config

$builder -> begin_tests('parse_config');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 29 

$objects{'_default'} -> parse_config(<<'EOXML');
<configuration
  package="Gestinanna::SiteConfiguration::Test"
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
  <content-type id="document" class="Gestinanna::ContentProvider::document"/>

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

is($objects{'_default'} -> package, "Gestinanna::SiteConfiguration::Test");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('parse_config');

# method: parse_provider_config

$builder -> begin_tests('parse_provider_config');


$builder -> end_tests('parse_provider_config');

# method: provider_class

$builder -> begin_tests('provider_class');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 633 

is($objects{'_default'} -> provider_class(data => 'view'), "Gestinanna::SiteConfiguration::Test::DataProvider::view");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('provider_class');

# method: session_cookie

$builder -> begin_tests('session_cookie');


$builder -> end_tests('session_cookie');

# method: store_config

$builder -> begin_tests('store_config');


$builder -> end_tests('store_config');

# method: store_provider_config

$builder -> begin_tests('store_provider_config');


$builder -> end_tests('store_provider_config');

# method: parent

$builder -> begin_tests('parent');


$builder -> end_tests('parent');

# method: security_types

$builder -> begin_tests('security_types');


$builder -> end_tests('security_types');

# method: session_cookie_field

$builder -> begin_tests('session_cookie_field');


$builder -> end_tests('session_cookie_field');

# method: session_params

$builder -> begin_tests('session_params');


$builder -> end_tests('session_params');

# method: site_path

$builder -> begin_tests('site_path');


$builder -> end_tests('site_path');

# method: tag_path

$builder -> begin_tests('tag_path');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 600 

is_deeply([ $objects{'_default'} -> tag_path('production') ], [q(test-1.0)]);
is_deeply([ $objects{'_default'} -> tag_path('pre-production') ], [q(testing-1.1)]);
is_deeply([ $objects{'_default'} -> tag_path('test') ], [q(testinging-1.2)]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('tag_path');

# method: content_providers

$builder -> begin_tests('content_providers');


$builder -> end_tests('content_providers');

# method: content_types

$builder -> begin_tests('content_types');


$builder -> end_tests('content_types');

# method: data_providers

$builder -> begin_tests('data_providers');


$builder -> end_tests('data_providers');

# method: data_types

$builder -> begin_tests('data_types');


$builder -> end_tests('data_types');

# method: new_cookie

$builder -> begin_tests('new_cookie');


$builder -> end_tests('new_cookie');

# method: package

$builder -> begin_tests('package');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 525 

is($objects{'_default'} -> package, "Gestinanna::SiteConfiguration::Test");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('package');

# method: factory_class

$builder -> begin_tests('factory_class');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 621 

is($objects{'_default'} -> factory_class, "Gestinanna::SiteConfiguration::Test::POF");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('factory_class');

# method: build_factory

$builder -> begin_tests('build_factory');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 698 

$objects{'_default'} -> build_factory;

my $factory = $objects{'_default'} -> factory_class;
my $f_class;
my $class;

foreach my $type (qw(
    xsm document portal view site uri-map user actor username xslt folder
)) {
    $class = $objects{'_default'} -> provider_class(data => $type);

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


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('build_factory');

# method: factory

$builder -> begin_tests('factory');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 649 

my $factory = $objects{'_default'} -> factory(
    tag_path => 'test',
);

is_deeply($factory -> {tag_path}, [qw(
    testinging-1.2
    testing-1.1
    test-1.0
)]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('factory');
# record test results for report
$builder -> record_test_details('Gestinanna::SiteConfiguration');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
