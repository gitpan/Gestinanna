use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Authz;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Authz';
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


}
$builder -> begin_tests('new');
eval {
    $objects{'_default'} = Gestinanna::Authz -> new();
};
ok(!$@);
isa_ok($objects{'_default'}, 'Gestinanna::Authz');

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 101 

our $schema;

$objects{'_default'} = $objects{'_default'} -> new(
    alzabo_schema => $schema
);

isa_ok($objects{'_default'}, Gestinanna::Authz);

$objects{'_default'} = Gestinanna::Authz -> new(
    alzabo_schema => $schema
);

isa_ok($objects{'_default'}, Gestinanna::Authz);

$objects{'_default'} = Gestinanna::Authz::new(
    alzabo_schema => $schema
);

isa_ok($objects{'_default'}, Gestinanna::Authz);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');
my @ids = qw(_default);


# method: _attr_and_eq

$builder -> begin_tests('_attr_and_eq');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 625 

is($objects{'_default'} -> _attr_and_eq( [ 'read', 'write' ], { read => 1, write => 0 } ), 0);
is($objects{'_default'} -> _attr_and_eq( [ 'read', 'write' ], { read => 1, write => 1 } ), 1);
is($objects{'_default'} -> _attr_and_eq( [ 'read', [ 'write' ] ], { write => 1, read => 1 } ), 1);
is($objects{'_default'} -> _attr_and_eq( [ 'read', [ 'write', 'exec' ] ], { write => 1, read => 1, exec => 0 } ), 1);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_attr_and_eq');

# method: _attr_or_eq

$builder -> begin_tests('_attr_or_eq');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 583 

is($objects{'_default'} -> _attr_or_eq( [ 'read', 'write' ], { read => 1 } ), 1);
is($objects{'_default'} -> _attr_or_eq( [ 'read', [ 'write' ] ], { write => 1 } ), 1);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_attr_or_eq');

# method: fetch_groups

$builder -> begin_tests('fetch_groups');


$builder -> end_tests('fetch_groups');

# method: fetch_resource_groups

$builder -> begin_tests('fetch_resource_groups');


$builder -> end_tests('fetch_resource_groups');

# method: new

$builder -> begin_tests('new');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 101 

our $schema;

$objects{'_default'} = $objects{'_default'} -> new(
    alzabo_schema => $schema
);

isa_ok($objects{'_default'}, Gestinanna::Authz);

$objects{'_default'} = Gestinanna::Authz -> new(
    alzabo_schema => $schema
);

isa_ok($objects{'_default'}, Gestinanna::Authz);

$objects{'_default'} = Gestinanna::Authz::new(
    alzabo_schema => $schema
);

isa_ok($objects{'_default'}, Gestinanna::Authz);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');

# method: set_point_attributes

$builder -> begin_tests('set_point_attributes');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 669 

$objects{'_default'} -> set_point_attributes([actor => '1'], ['*' => '/* | //* | /*@* | //*@*'], { admin => 1 }, [actor => 1]);
$objects{'_default'} -> set_point_attributes([actor => '*'], [$_ => '/home/SELF//* | /home/SELF//*@*'], { admin => 1 }, [actor => 1])
    for qw(xsm view xslt document portal);
$objects{'_default'} -> set_point_attributes([actor => '*'], [$_ => '/sys//* | /sys//*@*'], { read => 1, exec => 1 }, [actor => 1])
    for qw(xsm view xslt document portal);
$objects{'_default'} -> set_point_attributes([actor => '1'], [$_ => '/sys//* | /sys//*@*'], { read => 3 }, [actor => 1])
    for qw(xsm view xslt document portal);

my $table = $objects{'_default'} -> {alzabo_schema} -> table('Attribute');

my $cursor = $table -> all_rows;
my %attrs;

while(my $row = $cursor -> next) {
    my($user_type, $user_id, $r_type, $r_id, $attr, $v, $granter_type, $granter_id) =
        $row -> select(qw(user_type user_id resource_type resource_id attribute value granter_type granter_id));

    $attrs{join(":", $user_type, $user_id, $r_type, $r_id, $granter_type, $granter_id)} -> {$attr} = $v;
}

ok($attrs{join(":", actor => 1, '*' => '/* | //* | /*@* | //*@*', actor => 1)}->{admin} == 1);
ok($attrs{join(":", actor => '*', $_ => '/home/SELF//* | /home/SELF//*@*', actor => 1)}->{admin} == 1)
    for qw(xsm view xslt document portal);
ok($attrs{join(":", actor => '*', $_ => '/sys//* | /sys//*@*', actor => 1)}->{read} == 1
   && $attrs{join(":", actor => '*', $_ => '/sys//* | /sys//*@*', actor => 1)}->{exec} == 1
   && $attrs{join(":", actor => '1', $_ => '/sys//* | /sys//*@*', actor => 1)}->{read} == 3
) for qw(xsm view xslt document portal);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('set_point_attributes');

# method: fetch_acls

$builder -> begin_tests('fetch_acls');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 159 

my $acls;

$acls = $objects{'_default'} -> fetch_acls([ actor => 1 ], [ xsm => '/sys/std/log-manager' ]);

is_deeply($acls, {
    1 => { 
        '/* | //* | /*@* | //*@*' => { admin => 1 },
        '/sys//* | /sys//*@*' => { read => 3 },
    },
    '*' => { 
        '/sys//* | /sys//*@*' => { read => 1, exec => 1 },
        '/home/SELF//* | /home/SELF//*@*' => { admin => 1 },
    },
});

$acls = $objects{'_default'} -> fetch_acls([ actor => 2 ], [ xsm => '/sys/std/log-manager' ]);

is_deeply($acls, {
    1 => { 
        '/* | //* | /*@* | //*@*' => { admin => 1 },
        '/sys//* | /sys//*@*' => { read => 3 },
    },
    '*' => { 
        '/sys//* | /sys//*@*' => { read => 1, exec => 1 },
        '/home/SELF//* | /home/SELF//*@*' => { admin => 1 },
    },
});

$acls = $objects{'_default'} -> fetch_acls([ actor => 2 ], [ foo => '/bar' ]);

is_deeply($acls, { 
    1 => { 
        '/* | //* | /*@* | //*@*' => { admin => 1 },
    },
});

$acls = $objects{'_default'} -> fetch_acls([ app => 'deadbeef' ], [ xsm => '/sys/std/log-manager' ]);

is_deeply($acls, { });


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('fetch_acls');

# method: query_acls

$builder -> begin_tests('query_acls');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 316 

my $acls;

$acls = $objects{'_default'} -> query_acls([actor => 1], [xsm => '/sys/std/log-manager']);

is_deeply($acls, [
    {
        '*' => {
            '/sys//* | /sys//*@*' => { read => 1, exec => 1 }
        },
    },
    undef, undef,
    {
        '1' => {
            '/* | //* | /*@* | //*@*' => { admin => 1 },
            '/sys//* | /sys//*@*' => { read => 3 },
        },
    }
]);

$acls = $objects{'_default'} -> query_acls([actor => 2], [xsm => '/sys/std/log-manager']);

is_deeply($acls, [
    {
        '*' => {
            '/sys//* | /sys//*@*' => { read => 1, exec => 1 }
        },
    },
    undef, undef, 
    undef,
]);

$acls = $objects{'_default'} -> query_acls([actor => 2], [foo => 'bar']);

is_deeply($acls, [ undef, undef, undef, undef ]);



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('query_acls');

# method: query_attributes

$builder -> begin_tests('query_attributes');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 424 

my $attrs;

$attrs = $objects{'_default'} -> query_attributes([actor => 1], [xsm => '/sys/std/login-manager']);

is_deeply($attrs, {
    admin => 1,
    read => 3,
    exec => 1,
});

$attrs = $objects{'_default'} -> query_attributes([actor => 2], [xsm => '/sys/std/login-manager']);

is_deeply($attrs, {
    exec => 1,
    read => 1,
});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('query_attributes');

# method: query_point_attributes

$builder -> begin_tests('query_point_attributes');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 260 

my $attrs;

$attrs = $objects{'_default'} -> query_point_attributes([actor => '1'], ['*' => '/* | //* | /*@* | //*@*']);
is_deeply($attrs, { admin => 1 });

for my $type (qw(xsm view xslt document portal)) {
    $attrs = $objects{'_default'} -> query_point_attributes([actor => '*'], [$type => '/home/SELF//* | /home/SELF//*@*']);
    is_deeply($attrs, { admin => 1 });
    $attrs = $objects{'_default'} -> query_point_attributes([actor => '*'], [$type => '/sys//* | /sys//*@*']);
    is_deeply($attrs, { read => 1, exec => 1 });
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('query_point_attributes');

# method: can_grant

$builder -> begin_tests('can_grant');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 769 

ok($objects{'_default'} -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 1}));
ok($objects{'_default'} -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 2}));
ok(!$objects{'_default'} -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 3}));
ok(!$objects{'_default'} -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 4}));
ok(!$objects{'_default'} -> can_grant([actor => 2], [actor => 3], [ xsm => '/sys/std/log-manager' ], { exec => 1}));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('can_grant');

# method: grant

$builder -> begin_tests('grant');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 824 

ok(!$objects{'_default'} -> has_attribute([actor => 2], [xsm => '/home/1/std/log-manager'], [ 'read' ]));
ok($objects{'_default'} -> grant([actor => 1], [actor => 2], [xsm => '/home/1/std/log-manager'], {read => 1}));
ok($objects{'_default'} -> has_attribute([actor => 2], [xsm => '/home/1/std/log-manager'], [ 'read' ]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('grant');

# method: has_attribute

$builder -> begin_tests('has_attribute');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 548 

ok($objects{'_default'} -> has_attribute([actor => 1], [xsm => '/home/1/std/log-manager'], [ 'read' ]));
ok($objects{'_default'} -> has_attribute([actor => 2], [xsm => '/home/2/std/log-manager'], [ 'admin' ]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('has_attribute');
# record test results for report
$builder -> record_test_details('Gestinanna::Authz');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
