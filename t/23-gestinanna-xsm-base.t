use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::XSM::Base;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::XSM::Base';
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
    $objects{'_default'} = Gestinanna::XSM::Base -> new();
};
ok(!$@);
isa_ok($objects{'_default'}, 'Gestinanna::XSM::Base');



$builder -> end_tests('new');
my @ids = qw(_default);


# method: _flatten_hash

$builder -> begin_tests('_flatten_hash');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 756 

is_deeply(Gestinanna::XSM::Base::_flatten_hash({
   foo => 2, bar => 3
}), { foo => 2, bar => 3 });

is_deeply(Gestinanna::XSM::Base::_flatten_hash({
    foo => { baz => 2 }, bar => 3, fud => { food => { flood => 5 }, flaunt => 6 }
}), { qw(
    foo.baz 2
    bar     3
    fud.food.flood  5
    fud.flaunt      6
)});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_flatten_hash');

# method: _make_can_code

$builder -> begin_tests('_make_can_code');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 181 

my($a, $b) = (0, 0);

my $code = Gestinanna::XSM::Base::_make_can_code(undef, undef);
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);

$code = Gestinanna::XSM::Base::_make_can_code(sub { $a = 1 }, undef );
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok($a && !$b);

$a = $b = 0;

$code = Gestinanna::XSM::Base::_make_can_code(sub { $a = 1 }, sub { $b = 1} );
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok($a && $b);

$a = $b = 0;

$code = Gestinanna::XSM::Base::_make_can_code(sub { $b = 1} );
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok(!$a && $b);

my $i = 0;
my @t = ( 0, 0 );

$code = Gestinanna::XSM::Base::_make_can_code(sub { $t[$i++] = 1; }, sub { $t[$i++] = 2; });
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok($t[0] == 2 && $t[1] == 1);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_make_can_code');

# method: _make_hasa_can_code

$builder -> begin_tests('_make_hasa_can_code');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 275 

my $a = '';
my @args = ( );

my $code = Gestinanna::XSM::Base -> _make_hasa_can_code('My::Test::XSM', 'test', sub {
    my $self = shift;
    $a = ref $self;
    @args = @_;
});

ok(UNIVERSAL::isa($code, 'CODE'));

my $self = bless { } => Gestinanna::XSM::Base;

$code -> ($self, qw(1 2 3));

is($a, 'My::Test::XSM');
is_deeply([@args], [qw(1 2 3)]);
is(ref $self, q(Gestinanna::XSM::Base));

$code = Gestinanna::XSM::Base -> _make_hasa_can_code('My::Test::XSM', 'test', sub {
    die "Help!\n";
});

eval { $code -> ($self, qw(1 2 3)) };
ok($@ eq "Help!\n");

$code = Gestinanna::XSM::Base -> _make_hasa_can_code('My::Test::XSM', 'test', sub {
    throw StateMachine::Gestinanna::Exception(
        -state => 'ing',
        -data => [ @_[1 .. $#_] ],
    )
});

eval { $code -> ($self, qw(1 2 3)) };
my $e = $@;
ok(UNIVERSAL::isa($e, 'StateMachine::Gestinanna::Exception'));
is($e -> state, 'test_ing');
is_deeply($e -> data, [qw(1 2 3)]);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_make_hasa_can_code');

# method: _merge_state_defs

$builder -> begin_tests('_merge_state_defs');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 1342 

is_deeply(Gestinanna::XSM::Base::_merge_state_defs([qw(ALL)],
   { a => { b => 2 }, b => { a => 1 } },
   { a => { b => 3 }, b => { c => 2 } },
   { c => { a => 2 } },
), {
    a => { b => [3, 2] },
    b => { a => 1, c => 2 },
    c => { a => 2 }
});

is_deeply(Gestinanna::XSM::Base::_merge_state_defs([qw(SUPER)],
   { a => { b => 2 }, b => { a => 1 } },
   { a => { b => 3 }, b => { c => 2 } },
   { c => { a => 2 } },
), {
    a => { b => [3, 2] },
    b => { a => 1, c => 2 },
    c => { a => 2 }
});

is_deeply(Gestinanna::XSM::Base::_merge_state_defs([qw(NONE)],
   { a => { b => 2 }, b => { a => 1 } },
   { a => { b => 3 }, b => { c => 2 } },
   { c => { a => 2 } },
), {
    a => { b => 2 },
    b => { a => 1 },
    c => { a => 2 },
});



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_merge_state_defs');

# method: alias_state

$builder -> begin_tests('alias_state');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 477 

%My::Test::XSM::ALIASES = %My::Test::XSM::ALIASES = (
   '_begin' => 'start',
);
@My::Test::XSM::ISA = @My::Test::XSM::ISA = qw(Gestinanna::XSM::Base);

is(Gestinanna::XSM::Base::alias_state('My::Test::XSM', '_begin'), 'start');
is(Gestinanna::XSM::Base::alias_state('My::Test::XSM', '_end'), '_end');

my $self = bless { } => 'My::Test::XSM';

is($self -> alias_state('_begin'), 'start');
is($self -> alias_state('_end'), '_end');

is(Gestinanna::XSM::Base::alias_state(undef, ''), undef);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('alias_state');

# method: filename

$builder -> begin_tests('filename');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 97 

$My::XSM::Test::FILENAME = $My::XSM::Test::FILENAME = 'filename';

@My::XSM::Test::ISA = qw(Gestinanna::XSM::Base);

is(Gestinanna::XSM::Base::filename('My::XSM::Test'), 'filename');

my $o = bless { } => 'My::XSM::Test';

is($o -> filename, 'filename');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('filename');

# method: get_super_path

$builder -> begin_tests('get_super_path');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 797 

%My::get_super_path::Test::EDGES_CACHE = %My::get_super_path::Test::EDGES_CACHE = (
    test_state => { super_path => [ qw(1 2 3) ] },
);

ok(eq_set([Gestinanna::XSM::Base::get_super_path('My::get_super_path::Test', 'test_state')], [qw(1 2 3)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('get_super_path');

# method: log

$builder -> begin_tests('log');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 67 

$objects{'_default'} -> log(debug => 'debug');

is($objects{'_default'} -> log, 'debug');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('log');

# method: state

$builder -> begin_tests('state');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 511 

my $self = bless { } => 'My::Test::XSM';

$self -> state('_begin');
is($self -> state, 'start');

my $old = $self -> state('_end');
is($old, 'start');

is($self -> state, '_end');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('state');

# method: _can_hasa

$builder -> begin_tests('_can_hasa');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 233 

@My::Had::XSM::ISA = qw(Gestinanna::XSM::Base);
@My::Has::XSM::ISA = qw(Gestinanna::XSM::Base);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_can_hasa');

# method: _generate_states

$builder -> begin_tests('_generate_states');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 1045 

{ package My::_generate_states::Test1;
  our @ISA = Gestinanna::XSM::Base;

  our %EDGES = (
    state1 => {
        state2 => {
            required => [qw(one two)],
            optional => [qw(three)],
        },
    },
    state2 => {
        state1 => {
            required => [qw(four five)],
        }
    }
  );
}

{ package My::_generate_states::Test_ALL;
  our @ISA = qw(My::_generate_states::Test1);

  our %EDGES = (
    _INHERIT => 'ALL',
    state1 => {
      state3 => {
          required => [qw(six)],
      },
      state2 => {
          required => [qw(three)],
      }
    },
  );
}

{ package My::_generate_states::Test_SUPER;
  our @ISA = qw(My::_generate_states::Test1);

  our %EDGES = (
    _INHERIT => 'SUPER',
    state1 => {
      state3 => {
          required => [qw(six)],
      },
      state2 => {
          required => [qw(three)],
      }
    },
  );
}

{ package My::_generate_states::Test_NONE;
  our @ISA = qw(My::_generate_states::Test1);

  our %EDGES = (
    _INHERIT => 'NONE',
    state1 => {
      state3 => {
          required => [qw(six)],
      },
      state2 => {
          required => [qw(three)],
      }
    },
  );
}

My::_generate_states::Test_ALL -> _generate_states;

#diag(Data::Dumper -> Dump([\%My::_generate_states::Test_ALL::EDGES_CACHE]));

is_deeply(\%My::_generate_states::Test_ALL::EDGES_CACHE, {
  state1 => { 
    profile => {
      state2 => {
        required => [qw(three one two)],
        optional => q(three),
      },
      state3 => {
        required => q(six),
      },
    },
    overrides => { 
      state2 => { },
      state3 => { },
    },
    super_path => [
      [ 'My::_generate_states::Test1', 'state1' ],
    ],
  },
  state2 => { 
    profile => {
      state1 => {
        required => [qw(four five)],
      }
    },
    overrides => { 
      state1 => { },
    },
    super_path => [
      [ 'My::_generate_states::Test1', 'state2' ],
    ],
  },
});

My::_generate_states::Test_SUPER -> _generate_states;

is_deeply(\%My::_generate_states::Test_SUPER::EDGES_CACHE, {
  state1 => {
    profile => {
      state2 => {
        required => [qw(three one two)],
        optional => q(three),
      },
      state3 => {
        required => q(six),
      },
    },
    overrides => {
      state2 => { },
      state3 => { },
    },
    super_path => [
      [ 'My::_generate_states::Test1', 'state1' ],
    ],
  },
  state2 => {
    profile => {
      state1 => {
        required => [qw(four five)],
      }
    },
    overrides => {
      state1 => { },
    },
    super_path => [
      [ 'My::_generate_states::Test1', 'state2' ],
    ],
  },
});

My::_generate_states::Test_NONE -> _generate_states;

is_deeply(\%My::_generate_states::Test_NONE::EDGES_CACHE, {
  state1 => {
    profile => {
      state2 => {
        required => q(three),
      },
      state3 => {
        required => q(six),
      },
    },
    overrides => {
      state2 => { },
      state3 => { },
    },
    super_path => [
    ],
  },
  state2 => {
    profile => { },
    overrides => { },
  },
});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_generate_states');

# method: can

$builder -> begin_tests('can');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 123 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('can');

# method: generate_validators

$builder -> begin_tests('generate_validators');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 991 

{ package My::generate_validators::Test1;
  our @ISA = Gestinanna::XSM::Base;
                    
  our %EDGES = (
    state1 => {     
        state2 => {
            required => [qw(one two)],
            optional => [qw(three)],
        },          
    },
    state2 => {
        state1 => {
            required => [qw(four five)],
        }   
    }
  );    
}

My::generate_validators::Test1 -> generate_validators;

my $vs = \%My::generate_validators::Test1::VALIDATORS;

ok(eq_set([keys %$vs], [qw(state1 state2)]));

isa_ok($vs -> {'state1'}, 'Data::FormValidator');
isa_ok($vs -> {'state2'}, 'Data::FormValidator');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('generate_validators');

# method: new

$builder -> begin_tests('new');


$builder -> end_tests('new');

# method: _transit

$builder -> begin_tests('_transit');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 343 

my($a, $b);

{ package My::_transit::SM;
  our @ISA = qw(Gestinanna::XSM::Base);

  sub pre_a { $a = 'pre' };
  sub post_a { $a = 'post' };
  sub pre_b { $b = 'pre' };
  sub post_b { $b = 'post' };
  sub a_to_b { $a = 'from'; $b = 'to' };
  sub b_to_a { $a = 'to'; $b = 'from' };
}

my $sm = My::_transit::SM -> new;

$sm -> _transit(qw(a b));
ok($a eq 'from' && $b eq 'to');

$sm -> _transit(qw(b a));
ok($a eq 'to' && $b eq 'from');

$sm -> _transit(qw(a c));
ok($a eq 'post');

$sm -> _transit(qw(c a));
ok($a eq 'pre');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('_transit');

# method: add_data

$builder -> begin_tests('add_data');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 648 

{ package My::add_data::SM;
  our @ISA = qw(Gestinanna::XSM::Base);
}

my $sm = My::add_data::SM -> new;

$sm -> clear_data;

$sm -> add_data('in', {
    foo => 'bar'
});

is($sm -> {context} -> {data} -> {in} -> {foo}, 'bar');

$sm -> add_data('in.baz', {
    foo => 'bar'
});

is($sm -> {context} -> {data} -> {in} -> {baz} -> {foo}, 'bar');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('add_data');

# method: clear_context

$builder -> begin_tests('clear_context');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 1420 

{ package My::clear_context::SM;
  our @ISA = qw(Gestinanna::XSM::Base);
  our %EDGES = ( );
}

my $sm = My::clear_context::SM -> new;

$sm -> clear_context;

is_deeply($sm -> {context}, {
    data => {
      in => { }, out => { },
    },
    saved_context => undef,
});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('clear_context');

# method: clear_data

$builder -> begin_tests('clear_data');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 600 

{ package My::clear_data::SM;
  our @ISA = qw(Gestinanna::XSM::Base);
}

my $sm = My::clear_data::SM -> new;

$sm -> clear_data;

is_deeply($sm -> {context} -> {data}, {
    in => { }, out => { },
});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('clear_data');

# method: context

$builder -> begin_tests('context');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 1456 

my $sm = bless { } => Gestinanna::XSM::Base;

my $context = {
    in => { a => 'b' },
    out => { foo => 'bar' },
};

$sm -> context(Storable::nfreeze($context));
is_deeply(Storable::thaw($sm -> context), $context);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('context');

# method: data

$builder -> begin_tests('data');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 552 

{ package My::data::SM;
  our @ISA = qw(Gestinanna::XSM::Base);
}

my $sm = My::data::SM -> new;

$sm -> add_data('in', { foo => 'bar' } );
$sm -> add_data('in.baz', { bar => 'foo' } );
$sm -> add_data('in.baz.foo', { bar => 2 } );

is_deeply($sm -> data('in'), {
    foo => 'bar',
    baz => {
      bar => 'foo',
      foo => { bar => 2 },
    },
});

is_deeply($sm -> data('in.baz'), {
    bar => 'foo',
    foo => { bar => 2 },
});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('data');

# method: select_state

$builder -> begin_tests('select_state');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 822 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('select_state');

# method: transit

$builder -> begin_tests('transit');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 401 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('transit');

# method: process

$builder -> begin_tests('process');


$builder -> end_tests('process');

# method: transitioned

$builder -> begin_tests('transitioned');


$builder -> end_tests('transitioned');

# method: unknown

$builder -> begin_tests('unknown');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 971 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('unknown');

# method: view

$builder -> begin_tests('view');


$builder -> end_tests('view');

# method: invalid

$builder -> begin_tests('invalid');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 961 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('invalid');

# method: is_not_terminal_state

$builder -> begin_tests('is_not_terminal_state');


$builder -> end_tests('is_not_terminal_state');

# method: messages

$builder -> begin_tests('messages');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 981 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('messages');

# method: missing

$builder -> begin_tests('missing');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 951 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('missing');

# method: selected_state

$builder -> begin_tests('selected_state');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 941 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('selected_state');
# record test results for report
$builder -> record_test_details('Gestinanna::XSM::Base');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
