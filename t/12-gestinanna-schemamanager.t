use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::SchemaManager;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::SchemaManager';
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

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 12 

use lib 't/lib';

mkdir 'alzabo' unless -d 'alzabo';
my $schemas_dir = File::Spec -> catdir(qw(alzabo schemas));
mkdir $schemas_dir unless -d $schemas_dir;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

}
$builder -> begin_tests('new');
eval {
    $objects{'_default'} = Gestinanna::SchemaManager -> new();
};
ok(!$@);
isa_ok($objects{'_default'}, 'Gestinanna::SchemaManager');

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 75 


$objects{'_default'} = Gestinanna::SchemaManager -> new(
#    File::Spec -> catpath(schemas)
);

isa_ok($objects{'_default'}, Gestinanna::SchemaManager);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');
my @ids = qw(_default);


# method: _load_create

$builder -> begin_tests('_load_create');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 561 
eval { Gestinanna::SchemaManager::_load_create };
local($Alzabo::Config::CONFIG{'root_dir'}) = 'alzabo';

my $e = $@;

if($e) {
    diag $e unless ref $e;
    ok(UNIVERSAL::isa($e, 'Gestinanna::Exception'));
    ok($e -> class('load.module'));
}
else {
    my $file = File::Spec -> catfile(qw(Alzabo Create.pm));
    ok(defined $INC{$file});
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_load_create');

# method: _load_runtime

$builder -> begin_tests('_load_runtime');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 594 

eval { Gestinanna::SchemaManager::_load_runtime };
local($Alzabo::Config::CONFIG{'root_dir'}) = 'alzabo';

my $e = $@;

if($e) {
    diag $e unless ref $e;
    ok(UNIVERSAL::isa($e, 'Gestinanna::Exception'));
    ok($e -> class('load.module'));
}
else {
    my $file = File::Spec -> catfile(qw(Alzabo Runtime.pm));
    ok(defined $INC{$file});
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_load_runtime');

# method: _process

$builder -> begin_tests('_process');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 502 

is_deeply($objects{'_default'} -> _process({
    foo => '${bean}',
    '${far}' => 'baz',
}, {
    bean => 'there',
    far => 'away'
}),
    {
        foo => 'there',
        'away' => 'baz',
});

is_deeply($objects{'_default'} -> _process({
    foo => { 'bar' => '${boo}' },
},
    { boo => 'baz' }
), {
    foo => { bar => 'baz' }
});

is_deeply($objects{'_default'} -> _process({
    foo => [qw(${bar} wuzzy ${baz})]
}, { bar => 'fuzzy', baz => 'was' }),
{ foo => [qw(fuzzy wuzzy was)] }
);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_process');

# method: available_schemas

$builder -> begin_tests('available_schemas');


$builder -> end_tests('available_schemas');

# method: create_schema

$builder -> begin_tests('create_schema');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 628 

my $s = $objects{'_default'} -> create_schema( rdbms => 'SQLite', name => "testing" );

isa_ok($s, "Gestinanna::SchemaManager::Schema");

isa_ok($s -> {s}, "Alzabo::Create::Schema");

isa_ok($s -> {manager}, "Gestinanna::SchemaManager");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('create_schema');

# method: load_schema

$builder -> begin_tests('load_schema');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 667 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('load_schema');

# method: new

$builder -> begin_tests('new');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 75 


$objects{'_default'} = Gestinanna::SchemaManager -> new(
#    File::Spec -> catpath(schemas)
);

isa_ok($objects{'_default'}, Gestinanna::SchemaManager);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');

# method: parse_schema

$builder -> begin_tests('parse_schema');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 194 

my $parser = XML::LibXML -> new;

my $dom = $parser -> parse_string(<<'EOXML');
<schemas>
  <schema name="repository-base">
    <table name="Folder">
      <column
        name="name"
        type="char"
        length="${id_len}"
        primary-key="yes"
      />   
      <column
        name="description"
        type="text"
      />
    </table>

    <table name="${prefix}">
      <column
        name="name"
        type="char"
        length="${id_len}"
        primary-key="yes"
      />
      <column
        name="revision"
        type="char"
        length="${id_len}"
        primary-key="yes"
      />
      <column
        name="modify_timestamp"
        type="timestamp"
        nullable="yes"
      />
      <column
        name="user_type"
        type="char"
        length="${type_len}"
      />
      <column
        name="user_id"
        type="char"
        length="${id_len}"
      />
      <column
        name="log"
        type="text"
      />
      <index unique="yes">
        <column name="name"/>
        <column name="revision"/>
      </index>
    </table>
  </schema>
  <schema name="foo">
    <inherit from="repository-base">
      <with-param name="prefix" value="foo"/>
    </inherit>
  </schema>
</schemas>
EOXML

$objects{'_default'} -> parse_schema($dom, 'internal_data');

my $schemas = $objects{'_default'} -> {schemas};

ok(eq_set([keys %$schemas], [qw(repository-base foo)]));
ok(eq_set([keys %{$schemas -> {'repository-base'}}], [qw(tables file)]));
is($schemas -> {'repository-base'}{file}, 'internal_data');
ok(eq_set([keys %{$schemas -> {'repository-base'}{tables}}], [qw(Folder ${prefix})]));
ok(eq_set([keys %{$schemas -> {'repository-base'}{tables}{Folder}}], [qw(columns column_order)]));
ok(eq_set([keys %{$schemas -> {'repository-base'}{tables}{'${prefix}'}}], [qw(columns column_order indices)]));
ok(eq_set([keys %{$schemas -> {'repository-base'}{tables}{Folder}{columns}}], $schemas -> {'repository-base'}{tables}{Folder}{column_order}));
is_deeply($schemas -> {'repository-base'}{tables}{Folder}{column_order}, [qw(name description)]);
ok(eq_set([keys %{$schemas -> {'repository-base'}{tables}{'${prefix}'}{columns}}], $schemas -> {'repository-base'}{tables}{'${prefix}'}{column_order}));
is_deeply($schemas -> {'repository-base'}{tables}{'${prefix}'}{column_order}, [qw(name revision modify_timestamp user_type user_id log)]);

ok(eq_set([keys %{$schemas -> {foo}}], [qw(parent file)]));
is_deeply($schemas -> {foo} -> {parent}, [ [q(repository-base), { prefix => foo }] ]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('parse_schema');

# method: add_files

$builder -> begin_tests('add_files');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 114 

$objects{'_default'} = Gestinanna::SchemaManager -> new;

$objects{'_default'} -> add_files( 'schemas' );

ok(eq_set($objects{'_default'} -> {files}, [File::Spec -> catdir(qw(schemas base.xml))]));

my $schemas = $objects{'_default'} -> {schemas};

ok(eq_set([keys %$schemas], [qw(
    repository-base
    document
    view
    xslt
    xsm
    workflow
    workflow-base
)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('add_files');

# method: add_packages

$builder -> begin_tests('add_packages');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 166 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('add_packages');

# method: available_schema_defs

$builder -> begin_tests('available_schema_defs');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 372 

ok(eq_set([$objects{'_default'} -> available_schema_defs], [qw(
    repository-base
    document
    view
    xslt
    xsm
    workflow  
    workflow-base
)]));



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('available_schema_defs');

# method: parents

$builder -> begin_tests('parents');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 399 

is($objects{'_default'} -> parents('view'), 'repository-base');
is($objects{'_default'} -> parents('repository-base'), undef);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('parents');

# method: define_schema

$builder -> begin_tests('define_schema');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 423 

my $schema = $objects{'_default'} -> define_schema( 'view' );

isa_ok($schema, 'HASH');

ok(eq_set([keys %$schema], [qw(tables relations)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('define_schema');
# record test results for report
$builder -> record_test_details('Gestinanna::SchemaManager');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
