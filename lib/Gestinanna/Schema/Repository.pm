package Gestinanna::Schema::Repository;

use Gestinanna::Schema::Base qw(ID_LEN TYPE_LEN);
use Exporter;
use strict;
no strict 'refs';
use vars qw(@ISA @OBSOLETE @TABLES @RELATIONS @EXPORT);

# we need to add authorization info
# perhaps make it general for any resource?  in that case, it 
# needs to be in the Authz module

@ISA = qw(Gestinanna::Schema::Base);

our %repositories;

sub import {
    my($class, $rep) = @_;

    #warn "import($class, $rep)\n";
    return unless $rep;

    my $package = caller;
    #warn "package: $package\n";

    $repositories{$package} = $rep;
}

sub q_repository {
    my($class) = shift;

    #warn "q_repository($class)\n";
    my @isa = @{"${class}::ISA"};

    while(@isa && !defined $repositories{$class}) {
        $class = shift @isa;
        unshift @isa, @{"${class}::ISA"};
    }

    #warn "Prefix: $repositories{$class}\n";

    return $repositories{$class};
}

sub q_tables { 
    my $class = ref $_[0] || $_[0]; 
    return [$class -> tables, @{"${class}::TABLES"}]; 
}

sub q_obsolete { 
    my $class = ref $_[0] || $_[0]; 
    return [$class -> obsolete, @{"${class}::OBSOLETE"}]; 
}

sub q_relations { 
    my $class = ref $_[0] || $_[0]; 
    return [$class -> relations, @{"${class}::RELATIONS"}]; 
}

sub obsolete { 
    return ( 
    );
}

sub tables {
    my($class) = @_;
    my $prefix = $class -> q_repository;

    return ( ) unless defined $prefix;

    my $pkfield = lc $prefix;

    return (
        "Folder" => { # make sure we have this if we have any repositories - helps with creating folders
            columns => [
                name => {
                    type => 'char',
                    length => ID_LEN,
                    primary_key => 1,
                },
                description => {
                    type => 'text',
                },
            ],
        },
        "${prefix}_Description" => {
            columns => [
                name => {
                    type => 'char',
                    length => ID_LEN,
                    primary_key => 1,
                },
                description => {
                    type => 'text',
                },
            ],
        },
        $prefix => {
            columns => [
#                $pkfield => {
#                    type => 'int',
#                    primary_key => 1,
#                    sequenced => 1,
#                    nullable => 1,
#                },
                name => {
                    type => 'char',
                    length => ID_LEN,
                    primary_key => 1,
                },
                revision => {
                    type => 'char',
                    length => ID_LEN,
                    primary_key => 1,
                },
                modify_timestamp => {
                    type => 'timestamp',
                    nullable => 1,
                },
                user_type => {
                    type => 'char',
                    length => TYPE_LEN,
                },
                user_id => {
                    type => 'char',
                    length => ID_LEN,
                },
                log => {
                    type => 'text',
                },
            ],
            indices => [
                {
                    columns => [qw(name revision)],
                    unique => 1,
                },
            ],
        },
        "${prefix}_Tag" => {
            columns => [
                name => {
                    type => 'char',
                    length => ID_LEN,
                    primary_key => 1,
                },
                tag => {
                    type => 'char',
                    length => ID_LEN,
                    primary_key => 1,
                },
                revision => {
                    type => 'char',
                    length => ID_LEN,
                },
            ],
            indices => [
                {
                    columns => [qw(name revision)],
                    unique => 1,
                },
            ],
        },
    );
}

sub relations {
    my($class) = @_;
    my $prefix = $class -> q_repository;

    return ( );
    return ( ) unless defined $prefix;

    my $pkfield = lc $prefix;

    return (
        {
            table_from => qq{${prefix}_Tag},
            table_to => $prefix,
            cardinality => ['1', '1'],
            from_is_dependent => 1,
            to_is_dependent => 0,
        },
    );
}

1;

__END__

=head1 NAME
                    
Gestinanna::Schema::Repository - provides base schema support for repositories
                    
=head1 SYNOPSIS   

 package My::Schema;
                
 use Gestinanna::Schema::Repository q(Prefix);

 @ISA = qw(Gestinanna::Schema::Repository);

 @TABLES = (
    # `normal' definitions of repository contents
    Prefix => {
    },
 );

=head1 DESCRIPTION

This module can be used to create the basic tables and relations 
needed to manage a versioned repository.

The schema definitions held in @TABLE, @OBSOLETE, and @RELATIONS 
should define the objects being held in the repository.  Usually, 
the tables are prefixed with the same prefix as given to 
Gestinanna::Schema::Repository.

Individual revisions are assigned a unique id in the C<Prefix> 
table.  The primary key of this table is C<prefix> (all lowercase 
version of the prefix).  Tables defined in the repository sub-class 
should define a relationship between this primary key and the data 
in the object tables.  Simple data types may be kept in the 
C<Prefix> table (columns beginning with C<data_> will not be used by 
the repository [this also holds for the column C<data> with no underscore]).

The repository tracks resources by revision number and allows tags 
to be assigned to resource/revision combinations.  Resources may 
be retrieved by revision or tag at runtime.

=head1 SEE ALSO

L<Gestinanna::Runtime::Repository>.
                    
=head1 AUTHOR
                
James G. Smith, <jsmith@cpan.org>  
                    
=head1 COPYRIGHT
                  
Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
                    
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
