package Gestinanna::SchemaManager;

use File::Spec;
use Gestinanna::Exception;
use Gestinanna::SchemaManager::Schema;
use Gestinanna::Util qw(:hash);;
use XML::LibXML;
use Lingua::EN::Inflect;
use strict;

=begin testing

# BEGIN

use lib 't/lib';

mkdir 'alzabo' unless -d 'alzabo';
my $schemas_dir = File::Spec -> catdir(qw(alzabo schemas));
mkdir $schemas_dir unless -d $schemas_dir;

=end testing

=head1 NAME

Gestinanna::SchemaManager - Manages schema definitions

=begin testing

# INIT

use __PACKAGE__;
our $schema_manager = __PACKAGE__ -> new();
$schema_manager -> add_packages($package_manager);

$schema_manager -> _load_runtime;
$schema_manager -> _load_create;
$Alzabo::Config::CONFIG{'root_dir'} = 'alzabo';
mkdir 'alzabo' unless -d 'alzabo';
my $schemas_dir = File::Spec -> catdir(qw(alzabo schemas));
mkdir $schemas_dir unless -d $schemas_dir;

=end testing

=head1 SYNOPSIS

 use Gestinanna::SchemaManager;

 my $schema_manager = Gestinanna::SchemaManager -> new(
     path => $path_to_schema_files
 );

 my @files = $schema_manager -> files;

 my @schemas = $schema_manager -> available_schema_defs;

 my $schema = $schema_manager -> create_schema( %options );

 my $schema = $schema_manager -> add_schema($alzabo_schema, $schema_name, \%options);

=head1 DESCRIPTION

This module manages the schema definition files located in the path.  
These are XML files describing sets of tables that together can be 
used to create a schema.

=head1 METHODS

=head2 new

 $manager = Gestinanna::SchemaManager -> new(
      path => $path_to_schema_files
 );

=begin testing

# new


__OBJECT__ = __PACKAGE__ -> __METHOD__(
#    File::Spec -> catpath(schemas)
);

isa_ok(__OBJECT__, __PACKAGE__);

=end testing

=cut

sub new {
    my($class, %params);

    if(@_ % 2 == 1) {
        $class = shift;
    }

    %params = @_;

    $class = ref $class || $class;

    $class = __PACKAGE__ unless defined $class;

    my $self = bless { } => $class;

    if(defined $params{path} && -d $params{path}) {

        $self -> add_files($params{path});

    }

    return $self;
}

=begin testing

# add_files

__OBJECT__ = __PACKAGE__ -> new;

__OBJECT__ -> __METHOD__( 'schemas' );

ok(eq_set(__OBJECT__ -> {files}, [File::Spec -> catdir(qw(schemas base.xml))]));

my $schemas = __OBJECT__ -> {schemas};

ok(eq_set([keys %$schemas], [qw(
    repository-base
    document
    view
    xslt
    xsm
    workflow
    workflow-base
)]));

=end testing

=cut

sub add_files {
    my($self, $path) = @_;

    opendir my($dir), $path or return $self;

    push @{$self -> {path} ||= []}, $path;

    my @files = grep { !m{^\.} && m{\.xml$} } readdir($dir);

    closedir $dir;

    $self -> {files} ||= [ ];

    my $parser = XML::LibXML -> new;

    foreach my $file (@files) {
        my $filename = File::Spec -> catfile($path, $file);
        next unless -r $filename && -f _;
        open my $fh, "<", $filename or next;
        push @{$self -> {files}}, $filename;
        my $dom = $parser -> parse_fh($fh);
        close $fh;
        $self -> parse_schema($dom, $filename);
    }
}

=begin testing

# add_packages

=end testing

=cut

sub add_packages {
    my($self, $pkgmanager) = @_;

    my $packages = $pkgmanager -> packages('application');

    # only interested in applications atm

    my $parser = XML::LibXML -> new;

    foreach my $pkg (keys %$packages) {
        my $p = $pkgmanager -> load('application', $pkg, $packages->{$pkg});
        next unless $p;

        next unless $p -> has_file('conf/schema.xml');
        my $spec = $p -> get_content('conf/schema.xml');
        my $dom = $parser -> parse_string($spec);
        $self -> parse_schema($dom, "package:application/$pkg-$$packages{$pkg}");
    }
}

=begin testing

# parse_schema

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

__OBJECT__ -> __METHOD__($dom, 'internal_data');

my $schemas = __OBJECT__ -> {schemas};

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

=end testing

=cut

sub parse_schema {
    my($self, $dom, $filename) = @_;

    my $root = $dom -> documentElement;

    my $schemas = $root -> findnodes('schema');

    foreach my $schema ($root -> findnodes('schema')) {
        my $name = $schema -> getAttribute('name');
        if(defined $self -> {schemas} -> {$name}) {
            warn "Schema '$name' is defined in ", $self -> {schemas} -> {name} -> {file}, " and is extended in $filename\n";
            next;
        }
        else {
            $self -> {schemas} -> {$name} -> {file} = $filename;
        }

        my $schema_data = $self -> {schemas} -> {$name};

        foreach my $p ($schema -> findnodes('inherit')) {
            push @{$schema_data -> {parent} ||= []}, [ $p -> getAttribute('from'), {(
                map { $_ -> getAttribute('name') => $_ -> getAttribute('value') }
                    $p -> findnodes('with-param')
            )} ];
        }

        foreach my $t ($schema -> findnodes('table')) {
            my($t_name) = $t -> getAttribute('name');
            foreach my $c ($t -> findnodes('column')) {
                my $c_name = $c -> getAttribute('name');
                push @{$schema_data -> {tables} -> {$t_name} -> {column_order}||=[]}, $c_name 
                    unless defined $schema_data -> {tables} -> {$t_name} -> {columns} -> {$c_name};

                my $a;
                $a = $c -> getAttribute('type');
                $schema_data -> {tables} -> {$t_name} -> {columns} -> {$c_name} -> {'type'} = $a if $a ne '';
                $a = $c -> getAttribute('primary-key'); $a = 'no' unless defined $a;
                $schema_data -> {tables} -> {$t_name} -> {columns} -> {$c_name} -> {'primary_key'} = $a eq 'yes';
                $a = $c -> getAttribute('sequenced'); $a = 'no' unless defined $a;
                $schema_data -> {tables} -> {$t_name} -> {columns} -> {$c_name} -> {'sequenced'} = $a eq 'yes';
                $a = $c -> getAttribute('nullable'); $a = 'no' unless defined $a;
                $schema_data -> {tables} -> {$t_name} -> {columns} -> {$c_name} -> {'nullable'} = $a eq 'yes';
                $a = $c -> getAttribute('length');
                $schema_data -> {tables} -> {$t_name} -> {columns} -> {$c_name} -> {'length'} = $a if defined $a && $a ne '';
            }
            foreach my $i ($t -> findnodes('index')) {
                my $index = { };
                $index->{'unique'} = 1 if( ($i -> getAttribute('unique') || 'no') eq 'yes');
                $index->{'columns'} = [ ];
                foreach my $c ($i -> findnodes('column')) {
                    my $l = $c -> getAttribute('length') || '';
                    my $n = $c -> getAttribute('name');
                    next unless defined $n;
                    if($l ne '') {
                        push @{$index -> {'columns'} ||= []}, [ $n, $l ];
                    }
                    else {
                        push @{$index -> {'columns'}}, $n;
                    }
                }
                push @{$schema_data -> {tables} -> {$t_name} -> {indices} ||= []}, $index;
            }
        }

        foreach my $r ($schema -> findnodes('relation')) {
            my $relation = { };
            my $c = $r -> getAttribute('cardinality');
            my($f, $t) = split(/[^1n]/, $c, 2);
            $relation -> {'cardinality'} = [ $f, $t ];
            ($f) = $r -> findnodes('from');
            ($t) = $r -> findnodes('to');
            $relation -> {'from_is_dependent'} = ($f -> getAttribute('dependent') eq 'yes' ? 1 : 0);
            $relation -> {'to_is_dependent'} = ($t -> getAttribute('dependent') eq 'yes' ? 1 : 0);
            my(@f_c) = $f -> findnodes('column');
            my(@t_c) = $t -> findnodes('column');
            $relation -> {'table_from'} = $f -> getAttribute('table');
            $relation -> {'table_to'} = $t -> getAttribute('table');
            if(@f_c || @t_c) {
                $relation -> {'columns_from'} = [ map { $_ -> getAttribute('name') } @f_c ];
                $relation -> {'columns_to'} = [ map { $_ -> getAttribute('name') } @t_c ];
            }
            push @{$schema_data -> {relations} ||= []}, $relation;
        }
    }
}

=head2 available_schema_defs

=begin testing

# available_schema_defs

ok(eq_set([__OBJECT__ -> __METHOD__], [qw(
    repository-base
    document
    view
    xslt
    xsm
    workflow  
    workflow-base
)]));


=end testing

=cut

sub available_schema_defs {
    my($self) = @_;

    return grep { defined $self -> {schemas} -> {$_} } keys %{$self -> {schemas}};
}

=head2 parents

=begin testing

# parents

is(__OBJECT__ -> __METHOD__('view'), 'repository-base');
is(__OBJECT__ -> __METHOD__('repository-base'), undef);

=end testing

=cut

sub parents {
    my($self, $schema) = @_;

    if(@{$self -> {schemas} -> {$schema} -> {parent} || []}) {
        return $self -> {schemas} -> {$schema} -> {parent} -> [0] -> [0];
    }
    return;
}

=head2 define_schema

 push @schemas, $manager -> define_schema($name, %params);

=begin testing

# define_schema

my $schema = __OBJECT__ -> __METHOD__( 'view' );

isa_ok($schema, 'HASH');

ok(eq_set([keys %$schema], [qw(tables relations)]));

=end testing

=cut

sub define_schema {
    my($self, $name, %params) = @_;

    # goes through and does any substitutions necessary
    # this is the more difficult part, I think...

    # look for keys/values with ${name} pattern

    # first do any inheritance
    my $schema;

    # only support single inheritance atm
    my $def = $self -> {schemas} -> {$name};

    return { } unless defined $def;

    if(@{$def -> {parent} || []}) {
        my($parent_name, $lparams) = @{$def -> {parent} -> [0] || []};
        my %rparams;
        my($k, $v);
        while(($k, $v) = each %$lparams) {
            $k =~ s{\${(.*?)}}{$params{$1}}eg;
            $v =~ s{\${(.*?)}}{$params{$1}}eg;
            $rparams{$k} = $v;
        }
        $schema = $self -> define_schema($parent_name, %rparams);
    }
    else {
        $schema = { };
    }

    $params{'id_len'} ||= 150;
    $params{'type_len'} ||= 16;

    $def = $self -> _process($def, \%params);

    my $new_schema = { };
    $new_schema -> {tables} = deep_merge_hash($def -> {tables}, $schema -> {tables});

    foreach my $t (values %{$new_schema -> {tables}}) {
        foreach my $c (values %{$t -> {columns} || {}}) {
            foreach my $k (keys %$c) {
                $c -> {$k} = $c -> {$k} -> [0] if ref $c -> {$k};
            }
        }
        delete $t -> {indices};
    }

    foreach my $t (keys %{$new_schema -> {tables}}) {
        $new_schema -> {tables} -> {$t} -> {indices} = [
            @{$schema -> {tables} -> {$t} -> {indices} || []},
            @{$def    -> {tables} -> {$t} -> {indices} || []},
        ];
    }

    $new_schema -> {relations} = [
        @{$schema -> {relations} || []},
        @{$def -> {relations} || []}
    ];

    return $new_schema;
}

=begin testing

# _process

is_deeply(__OBJECT__ -> __METHOD__({
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

is_deeply(__OBJECT__ -> __METHOD__({
    foo => { 'bar' => '${boo}' },
},
    { boo => 'baz' }
), {
    foo => { bar => 'baz' }
});

is_deeply(__OBJECT__ -> __METHOD__({
    foo => [qw(${bar} wuzzy ${baz})]
}, { bar => 'fuzzy', baz => 'was' }),
{ foo => [qw(fuzzy wuzzy was)] }
);

=end testing

=cut

sub _process {
    my($self, $orig, $params) = @_;
    local($_);

    my $new;

    if(UNIVERSAL::isa($orig, 'HASH')) {
        my($k, $v);
        $new = { };
        while(($k, $v) = each %$orig) {
            $k =~ s{\${(.*?)}}{$$params{$1}}eg;
            $new -> {$k} = $self -> _process($v, $params);
        }
    }
    elsif(UNIVERSAL::isa($orig, 'ARRAY')) {
        $new = [ map { $self -> _process($_, $params) } @$orig ];
    }
    else {
        $new = $orig;
        $new =~ s{\${(.*?)}}{$$params{$1}}eg;
    }

    return $new;
}

=begin testing

# _load_create
eval { __PACKAGE__::__METHOD__ };
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

=end testing

=cut

sub _load_create {
    eval { require Alzabo::Create; };

    throw Gestinanna::Exception (
            -class => 'load.module',
            -text => 'Unable to load %s',
            -param => ['Alzabo::Create'],
            -e => $@,
    ) if $@;
}

=begin testing

# _load_runtime

eval { __PACKAGE__::__METHOD__ };
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

=end testing

=cut

sub _load_runtime {
    eval { require Alzabo::Runtime; };

    throw Gestinanna::Exception (
        -class => 'load.module',
        -text => 'Unable to load %s',
        -param => ['Alzabo::Runtime'],
        -e => $@,
    ) if $@;
}

=begin testing

# create_schema

my $s = __OBJECT__ -> __METHOD__( rdbms => 'SQLite', name => "testing" );

isa_ok($s, "__PACKAGE__::Schema");

isa_ok($s -> {s}, "Alzabo::Create::Schema");

isa_ok($s -> {manager}, "__PACKAGE__");

=end testing

=cut

sub create_schema {
    my($self, %params) = @_;

    $self -> _load_create; 

    my $s;

    eval {
        $s = Alzabo::Create::Schema->load_from_file( 
            name => $params{name},
        );
    };

    if($@) {
        $s = Alzabo::Create::Schema -> new(
            name => $params{name},
            rdbms => $params{rdbms},
        );
    }

    return bless { s => $s, manager => $self } => __PACKAGE__."::Schema";
}

=begin testing

# load_schema

=end testing

=cut

sub load_schema {
    my($self, %args) = @_;

    $self -> _load_runtime;

    my $s = Alzabo::Runtime::Schema->load_from_file(
        name => $args{name} 
    );

    $s -> set_user($args{user}) if $args{user};
    $s -> set_password($args{password}) if $args{password};
    $s -> set_host($args{host}) if $args{host};
    $s -> set_port($args{port}) if $args{port};
 
    $s -> driver -> handle($args{dbh}) if $args{dbh};
    $s -> driver -> handle($args{handle}) if $args{handle};

    eval { $s -> connect };
    warn "Schema connect errors: $@\n" if $@;

    $s -> set_referential_integrity(1);

    return $s;
}

1;

__END__
