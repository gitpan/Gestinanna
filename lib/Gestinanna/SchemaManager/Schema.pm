package Gestinanna::SchemaManager::Schema;

=begin testing

# INIT

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

=end testing

=cut

#

=begin testing

# CLEANUP

use Gestinanna::SchemaManager;

Gestinanna::SchemaManager -> _load_runtime;
Gestinanna::SchemaManager -> _load_create;
$Alzabo::Config::CONFIG{'root_dir'} = 'alzabo';

eval {
    my $schema = Gestinanna::SchemaManager -> new -> create_schema(name => 'test', rdbms => 'SQLite');
    $schema -> drop;
    $schema -> delete;
};

=end testing

=cut

#

=begin testing

# schema

my $schema = $schema_manager -> create_schema(name => 'schema_test', rdbms => 'SQLite');

isa_ok($schema, __PACKAGE__);

isa_ok($schema -> __METHOD__, 'Alzabo::Create::Schema');

=end testing

=cut

sub schema { $_[0] -> {s} }

=begin testing

# add_schema

my $schema = $schema_manager -> create_schema(name => 'schema_test', rdbms => 'SQLite');

# we should have the base package available at this point

ok(grep { $_ eq 'site' } $schema_manager -> available_schema_defs);

my @r;
eval {
    @r = $schema -> __METHOD__('site');
};

my $e = $@;
ok(!$e);
diag($e) if $e;

ok(!@r);

my $s = $schema -> schema;

ok(eq_set([ map { $_ -> name } $s -> tables ], [qw(Site Uri_Map)]));

=end testing

=cut

sub add_schema {
    my($self, $schema, %params) = @_;

    my $s = $self -> {s};
    my $manager = $self -> {manager};

    my $def = $manager -> define_schema($schema, %params);

    throw Gestinanna::Exception (
        -class => 'schema.undef',
        -text => 'Undefined schema: %s',
        -param => [ $schema ],
    ) unless ref $def && keys %$def;

    foreach my $table (keys %{$def -> {tables} || {}}) {
        my $t_def;
        if($s -> has_table($table)) {
            # upgrade table
            $t_def = $s -> table($table);
        }
        else {
            # add table
            $t_def = $s -> make_table(name => $table);
        }

        my %seen;
        foreach my $c (
            @{$def -> {tables} -> {$table} -> {column_order}|| []}, 
            keys %{$def -> {tables} -> {$table} -> {columns}||{}}
        ) {
            next if $seen{$c}++;
            my $c_def;
            my $new_c_def = $def -> {tables} -> {$table} -> {columns} -> {$c};

            my $old_name = $new_c_def -> {'old-name'};

            if(defined $old_name && $t_def -> has_column($old_name)) {
                $c_def = $t_def -> column($old_name);
                $c_def -> set_name($c);
                $c_def -> set_nullable($new_c_def -> {nullable}) if defined $new_c_def -> {nullable};
                $c_def -> set_sequenced($new_c_def -> {sequenced}) if defined $new_c_def -> {sequenced};
            }
            elsif($t_def -> has_column($c)) {
                $c_def = $t_def -> column($c);
                $c_def -> set_nullable($new_c_def -> {nullable} || 0) if defined $new_c_def -> {nullable};
                $c_def -> set_sequenced($new_c_def -> {sequenced} || 0) if defined $new_c_def -> {sequenced};
            }
            else {
                $c_def = $t_def -> make_column(
                    name => $c,
                    primary_key => $new_c_def -> {primary_key},
                    type => $new_c_def -> {type},
                    nullable => ($new_c_def -> {nullable} || 0),
                    sequenced => ($new_c_def -> {sequenced} || 0),
                    (defined $new_c_def -> {length} ? (length => $new_c_def -> {length}) : ( ) ),
                );
            }

            if($new_c_def -> {primary_key} && !$c_def -> is_primary_key) {
                $t_def -> add_primary_key($c_def);
            }
            elsif(!$new_c_def -> {primary_key} && $c_def -> is_primary_key) {
                $t_def -> remove_primary_key($c_def);
            }

            #$c_def -> set_length($new_c_def -> {length}) if defined $new_c_def -> {length};
            $c_def -> set_default($new_c_def -> {default});
            #$c_def -> set_type($new_c_def -> {type});
        }

        foreach my $c (map { $_ -> name } $t_def -> columns) {
            next if $seen{$c};
            $t_def -> delete_column($c);
        }

        # now make sure indices are created, if needed
        if(exists $def -> {indices}) {
            foreach my $i (@{$def -> {indices}}) {
                $t_def -> make_index( %$i, columns => [
                    map { +{ column => $t_def->column($_) } } @{$i->{columns}}
                ] );
            }
        }
    }

    # now look at relations
    # if they fail, no big deal -- return them so they can be tried again later

    my @failed;
    @failed = $self -> add_relations(@{$def -> {relations}}) if $def -> {relations};

    return @failed;
}

=begin testing

# add_relations

=end testing

=cut

sub add_relations {
    my($self, @relations) = @_;

    my $s = $self -> {s};
    my @failed;

    RELATION: foreach my $r (@relations) {
        my %R = (
          cardinality => $r -> {cardinality},
          from_is_dependent => $r -> {from_is_dependent},
          to_is_dependent => $r -> {to_is_dependent},
        );
        if($r -> {table_from} && !$s -> has_table($r -> {table_from})
           || $r -> {table_to} && !$s -> has_table($r -> {table_to})) {
            push @failed, $r;
            next RELATION;
        }

        my($table_from, $table_to);
        if($r -> {table_from}) {
            if(!$s -> has_table($r -> {table_from})) { 
                push @failed, $r;
                next RELATION;
            }
            $R{table_from} = $table_from = $s -> table($r -> {table_from});
        }

        if($r -> {table_to}) {
            if(!$s -> has_table($r -> {table_to})) { 
                push @failed, $r;
                next RELATION;
            }
            $R{table_to} = $table_to = $s -> table($r -> {table_to});
        }

        DIRECTION: foreach my $direction (qw(from to)) {
            next DIRECTION unless $r -> {"table_$direction"} && $r -> {"columns_$direction"};
            my @cs = ( );
            foreach my $c (@{$r -> {"columns_$direction"} || []}) {
                if(UNIVERSAL::isa($c, 'ARRAY')) {
                    unless($s -> has_table($c -> [0])) {
                        push @failed, $r;
                        next RELATION;
                    }
                    my $t = $s -> table($c -> [0]);
                    unless($t -> has_column($c -> [1])) {
                        push @failed, $r;
                        next RELATION;
                    }
                    push @cs, $t -> column($c -> [1]);
                }
                else {
                    unless($R{"table_$direction"} -> has_column($c)) {
                        push @failed, $r;
                        next RELATION;
                    }
                    push @cs, $R{"table_$direction"} -> column($c);
                }
            }
            $R{"columns_$direction"} = \@cs;
        }
            
        eval {
            $s -> add_relation(%R);
        };
        push @failed, $r if $@;
    }

    return @failed;
}

=begin testing

# make_live

=end testing

=cut

sub make_live {
    my($self) = shift;

    my $s = $self -> {s};

    $s -> create(@_);

    $s -> save_to_file;
}

=begin testing

# drop

=end testing

=cut

sub drop {
    my($self) = shift;

    return unless $self -> {s} && $self -> {s} -> instantiated;

    $self -> {s} -> drop(@_);
}

=begin testing

# delete

=end testing

=cut

sub delete {
    my($self) = shift;

    return unless $self -> {s} && $self -> {s} -> is_saved;

    $self -> {s} -> delete;
}

1;

__END__
