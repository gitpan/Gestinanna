use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Util;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Util';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;


# method: deep_merge_hash

$builder -> begin_tests('deep_merge_hash');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 367 

is_deeply(Gestinanna::Util::deep_merge_hash(
    { foo => 2, bar => 3 }, { baz => 5 }
), { foo => 2, bar => 3, baz => 5 });

is_deeply(Gestinanna::Util::deep_merge_hash(
    { foo => [ 1, 2 ] }, { foo => [ 3, 4 ] }
), { foo => [1, 2, 3, 4] });

is_deeply(Gestinanna::Util::deep_merge_hash(
    { foo => 2, bar => [ { baz => 2 }, [ 3, 4 ] ] },
    { fud => 5, bar => [ 5, [ 6, 7] ] }
), {
    foo => 2,
    bar => [ { baz => 2 }, [ 3, 4 ], 5, [6, 7] ],
    fud => 5
});

is_deeply(Gestinanna::Util::deep_merge_hash(
    { foo => undef, bar => 2 }
), { bar => 2 });

is_deeply(Gestinanna::Util::deep_merge_hash(
    { foo => { bar => 3 } }, { foo => { baz => 4 } },
), { foo => { bar => 3, baz => 4 } });

is_deeply(Gestinanna::Util::deep_merge_hash(
    { foo => 1, bar => [ ] }
), { foo => 1 });


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('deep_merge_hash');

# method: path2regex

$builder -> begin_tests('path2regex');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 187 

my %paths = (
    '/' => q{\/},
    '/this' => q{\/this},
    '/*' => q{\/([^\/\@\|\&]+)},
    '//*' => q{\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+)},
    '//*@*' => q{\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+)\@([^\/\@\|\&]+)},
    '//*@name' => q{\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+)\@name},
    '//* & //name' => q{(?(?=\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+))(?:\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*name))},
);

foreach my $path (sort keys %paths) {
    is(Gestinanna::Util::path2regex($path), $paths{$path}, "path2regex($path)");
}

is(Gestinanna::Util::path2regex('//*'), $paths{'//*'}, "Cached path2regex(//*)");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('path2regex');

# method: path_cmp

$builder -> begin_tests('path_cmp');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 277 

my @paths = (
    [ qw(a a), 1 ],
    [ qw(/this /that), undef ],
    [ qw(/this /that), undef ],
    [ '', '', 1 ],
    [ qw(/this /*), -1 ],
    [ qw(/* /this),  1 ],
    [ q(//foo | //bar), q(//foo | //baz), 0 ],
    [ qw(//*@* //*@name),  1 ],
    [ qw(//*@* //*@name),  1 ],
    [ qw(//*@name //*@*), -1 ],
    [ qw(//foo //bar), undef ],
    [ qw(/foo/bar/baz //bar), undef ],
    [ qw(/foo/bag //bar), undef ],
    [ qw(//bar /foo/bag), undef ],
    [ '/this | /that', '', 1 ],
    [ '', '/this | /that', -1 ],
    [ '/this', '/this | /that', -1 ],
    [ '//bar//* & //foo//*', '/baz/foo/bar/fob', 1],
);

foreach my $path (@paths) {
    is(Gestinanna::Util::path_cmp($path->[0], $path->[1]), $path->[2], "Gestinanna::Util::path_cmp($$path[0], $$path[1])");
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('path_cmp');
# record test results for report
$builder -> record_test_details('Gestinanna::Util');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
