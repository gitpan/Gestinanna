use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::SchemaManager::Schema;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::SchemaManager::Schema';
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


}

# method: schema

$builder -> begin_tests('schema');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 64 

my $schema = $schema_manager -> create_schema(name => 'schema_test', rdbms => 'SQLite');

isa_ok($schema, Gestinanna::SchemaManager::Schema);

isa_ok($schema -> schema, 'Alzabo::Create::Schema');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('schema');

# method: add_schema

$builder -> begin_tests('add_schema');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 80 

my $schema = $schema_manager -> create_schema(name => 'schema_test', rdbms => 'SQLite');

# we should have the base package available at this point

ok(grep { $_ eq 'site' } $schema_manager -> available_schema_defs);

my @r;
eval {
    @r = $schema -> add_schema('site');
};

my $e = $@;
ok(!$e);
diag($e) if $e;

ok(!@r);

my $s = $schema -> schema;

ok(eq_set([ map { $_ -> name } $s -> tables ], [qw(Site Uri_Map)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('add_schema');

# method: make_live

$builder -> begin_tests('make_live');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 282 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('make_live');

# method: add_relations

$builder -> begin_tests('add_relations');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 203 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('add_relations');

# method: drop

$builder -> begin_tests('drop');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 300 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('drop');

# method: delete

$builder -> begin_tests('delete');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 316 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('delete');
# record test results for report
$builder -> record_test_details('Gestinanna::SchemaManager::Schema');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
