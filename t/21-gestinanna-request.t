use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Request;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Request';
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
$builder -> begin_tests('new');
eval {
    $objects{'_default'} = Gestinanna::Request -> new();
};
ok(!$@);
isa_ok($objects{'_default'}, 'Gestinanna::Request');



$builder -> end_tests('new');
$builder -> begin_tests('new');
eval {
    $objects{'instance'} = Gestinanna::Request -> new();
};
ok(!$@);
isa_ok($objects{'instance'}, 'Gestinanna::Request');



$builder -> end_tests('new');
my @ids = qw(_default instance);


# method: config

$builder -> begin_tests('config');


$builder -> end_tests('config');

# method: do_redirect

$builder -> begin_tests('do_redirect');


$builder -> end_tests('do_redirect');

# method: embeddings

$builder -> begin_tests('embeddings');


$builder -> end_tests('embeddings');

# method: error

$builder -> begin_tests('error');


$builder -> end_tests('error');

# method: factory

$builder -> begin_tests('factory');


$builder -> end_tests('factory');

# method: get_url

$builder -> begin_tests('get_url');


$builder -> end_tests('get_url');

# method: in_mod_perl

$builder -> begin_tests('in_mod_perl');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 36 

is(Gestinanna::Request:: in_mod_perl, 0);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('in_mod_perl');

# method: init

$builder -> begin_tests('init');


$builder -> end_tests('init');

# method: instance

$builder -> begin_tests('instance');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 90 

is(Gestinanna::Request -> instance, $objects{'_default'});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('instance');

# method: new

$builder -> begin_tests('new');


$builder -> end_tests('new');

# method: path2regex

$builder -> begin_tests('path2regex');


$builder -> end_tests('path2regex');

# method: path_cmp

$builder -> begin_tests('path_cmp');


$builder -> end_tests('path_cmp');

# method: providers

$builder -> begin_tests('providers');


$builder -> end_tests('providers');

# method: read_session

$builder -> begin_tests('read_session');


$builder -> end_tests('read_session');

# method: session

$builder -> begin_tests('session');


$builder -> end_tests('session');

# method: upload

$builder -> begin_tests('upload');


$builder -> end_tests('upload');

# method: uri_to_filename

$builder -> begin_tests('uri_to_filename');


$builder -> end_tests('uri_to_filename');

# method: get_content_provider

$builder -> begin_tests('get_content_provider');


$builder -> end_tests('get_content_provider');

# method: error_provider

$builder -> begin_tests('error_provider');


$builder -> end_tests('error_provider');
# record test results for report
$builder -> record_test_details('Gestinanna::Request');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
