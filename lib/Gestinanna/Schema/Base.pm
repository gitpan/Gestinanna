package Gestinanna::Schema::Base;

use Gestinanna::Exception;
use Gestinanna::Schema;
use strict;
no strict 'refs';

# these constants are used for various lengths in the schema
use constant ID_LEN => 196;  # used for resource names
use constant TYPE_LEN => 16;  # used for resource types

use vars qw(@ISA @OBSOLETE @TABLES @RELATIONS);

sub q_tables { my $class = ref $_[0] || $_[0]; return \@{"${class}::TABLES"}; }
sub q_obsolete { my $class = ref $_[0] || $_[0]; return \@{"${class}::OBSOLETE"}; }
sub q_relations { my $class = ref $_[0] || $_[0]; return \@{"${class}::RELATIONS"}; }


sub import {
    my($class, @constants) = @_;

    my $pkg = caller;
    foreach my $constant (@constants) {
        eval {
            *{"${pkg}::${constant}"} = \&{"${class}::${constant}"};
        };
        warn "Unable to import $constant into $pkg: $@\n" if $@;
    }
}

sub init_schema {
    my($class, %desc) = @_;

    defined $desc{schema} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'schema' not present"
    );

    # we need to follow the ISA trail...
    my %tables = ();
    %tables = (%tables,
               %{$_ -> init_schema(%desc)||{}}
              )
        foreach grep { $_ -> can("init_schema") } @{"${class}::ISA"};

    %tables = (%tables,
        %{$class -> create_tables(
            schema => $desc{schema},
            tables => $class->q_tables,
        )||{}}
    );

    return \%tables; 
}
          
sub upgrade_schema {
    my($class, %desc) = @_;   
        
    defined $desc{schema} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'schema' not present"
    );

    # we need to follow the ISA trail... 
    my %tables = (); 
    %tables = (%tables,
               %{$_ -> upgrade_schema(%desc)||{}}
              )
        foreach grep { $_ -> can("upgrade_schema") } @{"${class}::ISA"};

    %tables = (%tables,
        %{$class -> upgrade_tables(
            schema => $desc{schema},
            tables => $class->q_tables,
            obsolete => $class->q_obsolete,
        )||{}} 
    );

    return \%tables;
}

sub init_relations {
    my($class, %desc) = @_;

    defined $desc{schema} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'schema' not present"
    );

    defined $desc{tables} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'tables' not present"
    );

    my $tables = $desc{tables};

    # we need to follow the ISA trail...
    $_ -> init_relations(%desc)
        foreach grep { $_ -> can("init_relations") } @{"${class}::ISA"};

    my $rs = $class -> q_relations;

    foreach my $r (@{$rs}) {
        my %R = %{$r};
        $R{$_} = $tables->{$R{$_}} for grep { exists $R{$_} } qw(table_from table_to);
        foreach my $k (grep { exists $R{$_} } qw(columns_from columns_to)) {
            my @cs = ( );
            if(UNIVERSAL::isa($R{$k}->[0], "ARRAY")) {
                foreach my $c ( @{$R{$k}} ) {
                    if(!defined $tables -> {$c->[0]}) {
                        warn "Table $$c[0] does not seem to exist.  Other errors may result.\n";
                        next;
                    }
                    push @cs, $tables->{$c->[0]}->column($c->[1]);
                }
            }
            else {
                my $c = $R{$k};
                if(!defined $tables -> {$c->[0]}) {
                    warn "Table $$c[0] does not seem to exist.  Other errors may result.\n";
                    next;
                }
                push @cs, $tables->{$c->[0]}->column($c->[1]);
                #push @cs, $tables->{$R{$k}->[0]}->column($R{$k}->[1]);
            }
            $R{$k} = \@cs;
        }
        eval {
            $desc{schema} -> add_relation(%R);
        };
        my $e = $@;
        if($e) {
            require Data::Dumper;
            warn "error adding relation: $e\n", Data::Dumper -> Dump([$r]), "\n";
        }
    }
}


sub create_tables {
    my($class, %p) = @_;
    my($schema, $ts) = @p{qw(schema tables)};
    my @ts = @{$ts};

    my %made_tables;

    while(my($name, $def) = splice @ts, 0, 2) {
        $made_tables{$name} = $class -> create_table(
            schema => $schema,
            name => $name,
            %{$def},
        );
    }

    return \%made_tables;
}

sub upgrade_tables {
    my($class, %p) = @_;
    my($schema, $ts, $os) = @p{qw(schema tables obsolete)};
    my @ts = @{$ts};
    my @os = @{$os};

    my %made_tables;

    #warn "Upgrading tables for $class\n";

    while(my($name, $def) = splice @os, 0, 2) {
        next unless $schema -> has_table($name);
        $class -> obsolete_table(
            schema => $schema,
            table => $schema -> table($name),
            %{$def},
        );
    }

    while(my($name, $def) = splice @ts, 0, 2) {
        if($schema -> has_table($name)) {
            #warn "Looking at $name\n";
            $made_tables{$name} = $schema -> table($name);
            $class -> upgrade_table(
                schema => $schema,
                table => $made_tables{$name},
                %{$def},
            );
        }
        else {
            #warn "Creating table $name\n";
            $made_tables{$name} = $class -> create_table(
                schema => $schema,
                name => $name,
                %{$def},
            );
        }
    }
}

sub obsolete_table {
    my($class, %desc) = @_;

    defined $desc{schema} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'schema' not present in table description"
    );   
     
    defined $desc{table} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'table' not present in table description"
    );

    my $table = $desc{table};

    my @cs = @{$desc{columns}};
    #warn "Removing columns ", join(", ", @cs), " from ", $table -> name, "\n";
    $table -> delete_column($_) 
        foreach 
            grep { $table -> has_column($_) } 
                 @{$desc{columns}}
            ;

    if(exists $desc{indices}) {
        foreach my $i (@{$desc{indices}}) {
            eval {
                # want to delete index
                $table -> make_index( %$i, columns => [
                    map { +{ column => $table->column($_) } } @{$i->{columns}}
                ] );
            };
        }
    }

    return $table;
}

sub create_table {
    my($class, %desc) = @_;

    defined $desc{schema} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'schema' not present in table description"
    );
   
    defined $desc{name} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'name' not present in table description"
    );

    defined $desc{columns} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'columns' not present in table description"
    );

    my $table;
    if($desc{schema} -> has_table($desc{name})) {
        $table = $desc{schema} -> table($desc{name});
    }
    else {
        $table = $desc{schema} -> make_table( name => $desc{name} );
    }

    my @cs = @{$desc{columns}};
    while(my($c, $d) = splice @cs, 0, 2) {
        warn "Creating ", $table -> name, ".$c\n";
        next if $table -> has_column($c);
        #eval {
            $table -> make_column(
                name => $c,
                %{$d}
            );
        #}
        #my $e = $@;
        #if($e) {
        #    warn "Unable to make column $c: $e\n";
        #}
    }

    if(exists $desc{indices}) {
        foreach my $i (@{$desc{indices}}) {
            $table -> make_index( %$i, columns => [
                map { +{ column => $table->column($_) } } @{$i->{columns}}
            ] );
        }
    }

    return $table;
}

sub upgrade_table {
    my($class, %desc) = @_;

    defined $desc{schema} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'schema' not present in table description"
    );
  
    defined $desc{table} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'table' not present in table description"
    );

    defined $desc{columns} or throw Gestinanna::Exception::Schema(
        -text => q"Required field 'columns' not present in table description"
    );

    my $table = $desc{table};

    my @cs = @{$desc{columns}};
    while(my($c, $d) = splice @cs, 0, 2) {
        if($table -> has_column($c)) {
            # check to see if the definition matches what we want
        }
        else {
            #warn "Adding column $c to table ", $table -> name, "\n";
            $table -> make_column(
                name => $c,
                %{$d}
            );
        }
    }

    if(exists $desc{indices}) {
        foreach my $i (@{$desc{indices}}) {
            eval {
                $table -> make_index( %$i, columns => [
                    map { +{ column => $table->column($_) } } @{$i->{columns}}
                ] );
            };
        }
    }

    return $table;
}

1;

__END__

=head1 NAME

Gestinanna::Schema::Base - base class for schema classes

=head1 SYNOPSIS

 use base qw(Gestinanna::Schema::Base);


=head1 DESCRIPTION

This module provides basic support for the various schema 
management routines in the various Gestinanna classes.

=head1 METHODS

=over 4

=back 4

=head1 AUTHOR
                
James G. Smith, <jsmith@cpan.org>  
                    
=head1 COPYRIGHT
                  
Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
                    
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
