use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::PackageManager;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::PackageManager';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;


# method: new

$builder -> begin_tests('new');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 31 

$objects{'_default'} = Gestinanna::PackageManager -> new( directory => 'packages' );

isa_ok($objects{'_default'}, 'Gestinanna::PackageManager');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');

# method: store

$builder -> begin_tests('store');


$builder -> end_tests('store');

# method: types

$builder -> begin_tests('types');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 51 

ok(eq_set([ $objects{'_default'} -> types ], [qw(application)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('types');

# method: write

$builder -> begin_tests('write');


$builder -> end_tests('write');

# method: packages

$builder -> begin_tests('packages');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 73 

is_deeply($objects{'_default'} -> packages('application'),
    {
        base => '0.04'
    }
);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('packages');

# method: load

$builder -> begin_tests('load');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 121 

my $pkg = $objects{'_default'} -> load(application => 'base');

isa_ok($pkg, 'Gestinanna::Package');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('load');
# record test results for report
$builder -> record_test_details('Gestinanna::PackageManager');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
