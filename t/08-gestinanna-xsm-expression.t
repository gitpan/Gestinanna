use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::XSM::Expression;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::XSM::Expression';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;


# method: axis_attribute

$builder -> begin_tests('axis_attribute');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 249 

is_deeply( [ Gestinanna::XSM::Expression::axis_attribute('File::Spec', 'isa') ], [ Class::ISA::self_and_super_path('File::Spec') ] );

is_deeply( [ Gestinanna::XSM::Expression::axis_attribute('File::Spec', 'version') ], [ File::Spec -> VERSION ] );

sub My::Testing::Dummy::s { };

is_deeply( [ sort { $a cmp $b } Gestinanna::XSM::Expression::axis_attribute('My::Testing::Dummy', 'can') ] , [ sort { $a cmp $b } qw(s VERSION isa can import) ] );


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_attribute');

# method: axis_child

$builder -> begin_tests('axis_child');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 58 

is_deeply([Gestinanna::XSM::Expression::axis_child([ qw(1 2 3 4) ], 2)], [ 3 ]);
is_deeply([Gestinanna::XSM::Expression::axis_child({ foo => 'bar', baz => 'foo' }, 'baz')], ['foo']);

is_deeply([ Gestinanna::XSM::Expression::axis_child([qw(1 2 3 4)], '*') ], [qw(1 2 3 4)]);
ok(eq_set([ Gestinanna::XSM::Expression::axis_child({ foo => 'bar', baz => 'foo' }, '*') ], [qw(bar foo)]));

use File::Spec;
my $foo = bless { } => File::Spec;

is_deeply([Gestinanna::XSM::Expression::axis_child($foo, 'curdir')], [File::Spec -> curdir]);

my $root = { foo => { bar => 'foo' } };

is_deeply([ Gestinanna::XSM::Expression::axis_child($root, 'foo') ], [ $root->{'foo'} ]);

is_deeply([ Gestinanna::XSM::Expression::axis_child({ baz => 'buzz' }, 'baz') ], [ 'buzz' ]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_child');

# method: axis_child_or_self

$builder -> begin_tests('axis_child_or_self');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 124 

is_deeply([ Gestinanna::XSM::Expression::axis_child_or_self([qw(1 2 3)], '*') ], [ [qw(1 2 3)], qw(1 2 3) ]);

my $root = { foo => { bar => 'foo' } };
is_deeply([ Gestinanna::XSM::Expression::axis_child_or_self($root, 'foo') ],
          [ $root, $root -> {'foo'} ]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_child_or_self');

# method: axis_descendent

$builder -> begin_tests('axis_descendent');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 142 

is_deeply([ Gestinanna::XSM::Expression::axis_descendent({ foo => 'bar' }, 'foo') ], [ 'bar' ]);

is_deeply([ Gestinanna::XSM::Expression::axis_descendent({ foo => { bar => 'baz' } }, 'bar') ], [ 'baz' ]);

is_deeply([ Gestinanna::XSM::Expression::axis_descendent({ foo => { bar => { baz => 'buzz' } } }, 'baz')], [ 'buzz' ]);

ok(eq_set([ Gestinanna::XSM::Expression::axis_descendent({ foo => { bar => [ { baz => 'buzz' }, { baz => 'ing' } ] } }, 'baz') ],
          [ qw(buzz ing) ]));

my $fs = bless { } => File::Spec;

ok(eq_set([ Gestinanna::XSM::Expression::axis_descendent({ foo => { curdir => 'curdir', bar => $fs } }, 'curdir') ], ['curdir', $fs -> curdir ]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_descendent');

# method: axis_descendent_or_self

$builder -> begin_tests('axis_descendent_or_self');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 180 

my $root = { foo => { bar => { baz => 'buzz' } } };
is_deeply([ Gestinanna::XSM::Expression::axis_descendent_or_self($root, 'baz')], [ $root, 'buzz' ]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_descendent_or_self');

# method: axis_method

$builder -> begin_tests('axis_method');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 195 

is(Gestinanna::XSM::Expression::axis_method('File::Spec', 'curdir'), File::Spec -> curdir);

is_deeply([ Gestinanna::XSM::Expression::axis_method('File::Spec', 'curdir') ], [ File::Spec -> curdir ]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_method');

# method: axis_self

$builder -> begin_tests('axis_self');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 35 

ok(Gestinanna::XSM::Expression::axis_self('root') eq 'root');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('axis_self');

# method: set_element

$builder -> begin_tests('set_element');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 285 

my $root = { };

Gestinanna::XSM::Expression::set_element($root, [qw( foo )], 'bar');

is($root -> {foo}, 'bar');

Gestinanna::XSM::Expression::set_element($root, [qw( baz 2 )], 'boo');

isa_ok($root -> {baz}, 'ARRAY');

is($root -> {baz} -> [2], 'boo');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('set_element');

# method: xsm_cmp

$builder -> begin_tests('xsm_cmp');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 356 

is(Gestinanna::XSM::Expression::xsm_cmp([10], [10]), 0);
is(Gestinanna::XSM::Expression::xsm_cmp([10], [12]), 10 <=> 12);
is(Gestinanna::XSM::Expression::xsm_cmp([12], [10]), 12 <=> 10);
is(Gestinanna::XSM::Expression::xsm_cmp(['a'],[10]), -1);
is(Gestinanna::XSM::Expression::xsm_cmp([10], ['a']), 1);
is(Gestinanna::XSM::Expression::xsm_cmp(['a'], ['b']), 'a' cmp 'b');
is(Gestinanna::XSM::Expression::xsm_cmp([qw(a b c)], ['a']), 0);
is(Gestinanna::XSM::Expression::xsm_cmp([qw(a b c)], ['d']), 3 <=> 1);
is(Gestinanna::XSM::Expression::xsm_cmp(['a'], [qw(a b c)]), 0);
is(Gestinanna::XSM::Expression::xsm_cmp(['d'], [qw(a b c)]), 1 <=> 3);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_cmp');

# method: xsm_range

$builder -> begin_tests('xsm_range');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 400 

is_deeply([ Gestinanna::XSM::Expression::xsm_range(0, 10) ], [ 0 .. 10 ]);
is_deeply([ Gestinanna::XSM::Expression::xsm_range(10, 0) ], [ reverse 0 .. 10 ]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('xsm_range');
# record test results for report
$builder -> record_test_details('Gestinanna::XSM::Expression');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
