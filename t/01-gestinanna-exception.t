use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Exception;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Exception';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;


# method: bool

$builder -> begin_tests('bool');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 51 

eval {
    throw Gestinanna::Exception
    ;
};

my $e = $@;

ok($e);
isa_ok($e, 'Gestinanna::Exception');
is($e -> bool, 1);
is(($e ? 1 : 0), 1);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('bool');

# method: class

$builder -> begin_tests('class');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 11 

eval {
    throw Gestinanna::Exception
        -class => 'foo.bar'
    ;
};

my $e = $@;

ok($e);
isa_ok($e, 'Gestinanna::Exception');
ok($e -> class('foo'));
ok($e -> class('foo.bar'));
ok(!$e -> class('foo.bar.baz'));
ok(!$e -> class('foo.ba.'));
ok($e -> class('foo.'));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('class');

# method: exception

$builder -> begin_tests('exception');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 103 

eval {
    throw Gestinanna::Exception
        -e => 'THis',
    ;
};

my $e = $@;

ok($e);
isa_ok($e, 'Gestinanna::Exception');
is($e -> exception, 'THis');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('exception');

# method: to_string

$builder -> begin_tests('to_string');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 73 

eval {
    throw Gestinanna::Exception
        -text => 'This is %s much %s',
        -param => [qw(so fun)],
    ;
};

my $e = $@;

ok($e);
isa_ok($e, 'Gestinanna::Exception');
is($e -> to_string, q{This is so much fun});
is("".$e, q{This is so much fun});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('to_string');

# method: value

$builder -> begin_tests('value');


$builder -> end_tests('value');
# record test results for report
$builder -> record_test_details('Gestinanna::Exception');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
