use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::XSM::Digest;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::XSM::Digest';
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

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 10 

$objects{'_default'} = bless { } => Gestinanna::XSM::Digest;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

}

# method: characters

$builder -> begin_tests('characters');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 80 

$objects{'_default'} -> set_state('text', '');

is($objects{'_default'} -> characters('text text'), '');

is($objects{'_default'} -> state('text'), 'text text');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('characters');

# method: comment

$builder -> begin_tests('comment');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 52 

is(Gestinanna::XSM::Digest::comment, '');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('comment');

# method: end_document

$builder -> begin_tests('end_document');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 38 

is(Gestinanna::XSM::Digest::end_document, '');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('end_document');

# method: end_element

$builder -> begin_tests('end_element');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 118 

is($objects{'_default'} -> end_element({ Name => 'name', Attributes => [] }), '');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('end_element');

# method: processing_instruction

$builder -> begin_tests('processing_instruction');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 66 

is(Gestinanna::XSM::Digest::processing_instruction, '');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('processing_instruction');

# method: start_document

$builder -> begin_tests('start_document');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 24 

is(Gestinanna::XSM::Digest::start_document, "#initialize digest namespace\n");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('start_document');

# method: start_element

$builder -> begin_tests('start_element');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 104 

is($objects{'_default'} -> start_element({ Name => 'name', Attributes => [] }), '');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('start_element');

# method: xsm_digests

$builder -> begin_tests('xsm_digests');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 153 

my %DIGESTS = map { $_ => Gestinanna::XSM::Digest::xsm_has_digest({ }, $_) } qw(
    MD5
    SHA1
);

ok(eq_set([ Gestinanna::XSM::Digest::xsm_digests({ }) ], [ grep { 1 == $DIGESTS{$_} } keys %DIGESTS ]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_digests');

# method: xsm_has_digest

$builder -> begin_tests('xsm_has_digest');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 134 

#main::diag(Data::Dumper -> Dump([\%Gestinanna::XSM::Digest::])); # -> {"Gestinanna::"}->{"XSM::"}->{"Digest::"}]));
#main::diag(Data::Dumper -> Dump([\%Gestinanna::XSM::Digest::]));
#main::diag(Data::Dumper -> Dump([\%Gestinanna::XSM::Digest::DIGESTS]));

is(Gestinanna::XSM::Digest::xsm_has_digest({ }, 'md5'), (defined(&Gestinanna::XSM::Digest::xsm_md5) ? 1 : 0));
is(Gestinanna::XSM::Digest::xsm_has_digest({ }, 'sha1'), (defined(&Gestinanna::XSM::Digest::xsm_sha1) ? 1 : 0));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_has_digest');

# method: xsm_md5

$builder -> begin_tests('xsm_md5');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 189 

if(Gestinanna::XSM::Digest::xsm_has_digest({ }, 'md5')) {
    is(Gestinanna::XSM::Digest::xsm_md5({ }, 'some text'), Digest::MD5::md5('some text'));
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_md5');

# method: xsm_md5_hex

$builder -> begin_tests('xsm_md5_hex');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 175 

if(Gestinanna::XSM::Digest::xsm_has_digest({ }, 'md5')) {
    is(Gestinanna::XSM::Digest::xsm_md5_hex({ }, 'some text'), Digest::MD5::md5_hex('some text'));
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_md5_hex');

# method: xsm_sha1

$builder -> begin_tests('xsm_sha1');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 223 
     
if(Gestinanna::XSM::Digest::xsm_has_digest({ }, 'sha1')) {   
    is(Gestinanna::XSM::Digest::xsm_sha1({ }, 'some text'), Digest::SHA1::sha1('some text'));
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_sha1');

# method: xsm_sha1_hex

$builder -> begin_tests('xsm_sha1_hex');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 209 

if(Gestinanna::XSM::Digest::xsm_has_digest({ }, 'sha1')) {
    is(Gestinanna::XSM::Digest::xsm_sha1_hex({ }, 'some text'), Digest::SHA1::sha1_hex('some text'));
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_sha1_hex');
# record test results for report
$builder -> record_test_details('Gestinanna::XSM::Digest');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
