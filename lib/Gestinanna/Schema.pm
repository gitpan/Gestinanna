package Gestinanna::Schema;

use Gestinanna::Exception;
use Lingua::EN::Inflect;
use strict;

sub load_create {
    eval { require Alzabo::Create; };

    throw Gestinanna::Exception::Load(
	-text => "Unable to load Alzabo::Create"
    ) if $@;
}

sub load_runtime {
    eval { require Alzabo::Runtime; };

    throw Gestinanna::Exception::Load(
	-text => "Unable to load Alzabo::Runtime"
    ) if $@;
}

sub load_schema {
    my($class, %args) = @_;

    $class -> load_runtime;

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

sub load_schema_create {
    my($class, %args) = @_;

    $class -> load_create;

    my $s = Alzabo::Create::Schema->load_from_file(
        name => $args{name},
    );
            
    return $s;
}


sub find_schemas {
    my($class, $base) = @_;

    my @schemas;

    eval {
        require Module::Require;
    };

    throw Gestinanna::Exception::Load(
	-text => "Unable to load Module::Require"
    ) if $@;

    $base =~ s{::}{/}g;

    Module::Require::walk_inc (
        sub { 
            return $_ unless m{^CVS$} or m{\.pod$} or m{\.pl$};
        },
        undef,
        $base,
        );

    foreach my $class (grep /\Q$base/, keys %INC) {
        foreach my $p (@INC) {
            if($class =~ /^\Q$p/) {
                $class =~ s{^\Q$p\E/?}{};
                next unless $class =~ m{^/?\Q$base/};
                $class =~ s{\.pm$}{};
                $class =~ s{/}{::}g;
         #       eval "require $class";
         #       next if $@;
                push @schemas, $class;
                last;
            }
        }
    }

    return @schemas;
}

sub create_schema {
    my($class) = shift;
    return $class -> _upgrade_create_schema('create', @_);
}

sub upgrade_schema {
    my($class) = shift;
    return $class -> _upgrade_create_schema('upgrade', @_);
}

sub _upgrade_create_schema {
    my($class, $type, %args) = @_;

    $class -> load_create;

    my @schemas = $class -> find_schemas('Gestinanna::Schema');

    push @schemas, @{$args{classes}||[]};

    my %s = map { $_ => undef } @schemas;

    foreach my $n (keys %s) {
        foreach my $k (keys %s) {
            next if $n eq $k;
            delete $s{$k} if $n -> isa($k);
        }
    }

    @schemas = keys %s;

    my $s;
    my($schema_method, $rel_method) = ("upgrade_schema", "upgrade_relations");
    if($type eq 'upgrade') {
        warn "Upgrading schema\n";
        if($args{schema}) {
            $s = $args{schema};
        }
        else {
            eval {
                $s = load_schema_create(%args);
            };
            if($@ || !$s) {
                $type = 'create';
                warn "Switching to schema creation\n";
            }
        }
    }
    if($type eq 'create') {
        eval {
            $s = Alzabo::Create::Schema -> new(
                name => $args{name},
                rdbms => $args{rdbms}
            );
        };
        if($@) {
            warn "$@\n";
            return;
        }
        ($schema_method, $rel_method) = ("init_schema", "init_relations");
    }

    my %made_tables;

    eval {
        %made_tables = (   
            %made_tables,
            %{$_ -> $schema_method(
                schema => $s,
            )}
        ) for grep { $_ -> can($schema_method) } @schemas;
    };
    if($@) {
        warn "$@\n";
        return;
    }

    eval {
        $_ -> $rel_method(
            schema => $s,
            tables => \%made_tables
        ) for grep { $_ -> can($rel_method) } @schemas;
    };
    if($@) {
        warn "$@\n";
        return;
    }

    eval {
        $s -> save_to_file; 
    };
    if($@) {
        warn "$@\n";
        return;
    }

    my %params;
    for(qw(host port user password)) {
        next unless defined $args{$_};
        $params{$_} = $args{$_};
    }

    if($type eq 'create') {
        eval {
            $s -> create(%params);
        };
    }
    else {
        eval {
            $s -> sync_backend(%params);
        };
    }

    if($@) {
        warn "$@\n";
        if($type eq 'create') {
            $s -> drop();
            $s -> delete();
            return;
        }
    } else {
        $s -> save_to_file; 

        if(wantarray) {
            return($s, \@schemas);
        } else {
            return $s;
        }
    }
}

sub drop_schema {
    my($class, %args) = @_;

    my $s = $args{schema} || $class -> load_schema_create(%args);

    my %params;
    for(qw(host port user password)) {
        next unless defined $args{$_};
        $params{$_} = $args{$_};
    }

    delete @params{qw(user password port host)}
        if $s -> rules -> rules_id eq 'SQLite';

    $s -> drop(%params);
}

sub delete_schema {
    my($class, %args) = @_;

    my $s = $args{schema} || $class -> load_schema_create(%args); 
    $s -> delete;
}

sub make_methods {
    my($class, %args) = @_;

    $class -> load_runtime;

    eval {
        require Alzabo::MethodMaker;
    };

    throw Gestinanna::Exception::Load(
        -text => "Unable to load Alzabo::MethodMaker"
    ) if $@;

    Alzabo::MethodMaker -> import(
        schema => $args{name},
        class_root => "Gestinanna::Schemas::$args{name}",
        all => 1,
        pluralize => sub {
            for($_[0]) {
                /hours$/ and return $_;
                return Lingua::EN::Inflect::PL($_);
            }
        },
    );
}

1;

__END__

=head1 NAME

Gestinanna::Schema - manage core Gestinanna schema

=head1 SYNOPSIS

 use Gestinanna::Schema;

 Gestinanna::Schema->load_schema(
     name => $database
 );

=head1 DESCRIPTION

This module provides basic support for the various schema 
management routines in the various Gestinanna classes.

=head1 METHODS

All methods are considered static---that is, there is no 
Gestinanna::Schema object.  This allows sub-classing.

=over 4

=back 4

=head1 AUTHOR
                
James G. Smith, <jsmith@cpan.org>  
                    
=head1 COPYRIGHT
                  
Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
                    
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
