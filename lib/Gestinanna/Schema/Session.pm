package Gestinanna::Schema::Session;

use Gestinanna::Exception;
use Gestinanna::Schema::Base qw(ID_LEN);
use strict;
use vars qw(@ISA @TABLES @RELATIONS @OBSOLETE);

@ISA = q{Gestinanna::Schema::Base};

@TABLES = (
    sessions => {
        columns => [
            id => {
                type => 'char',
                length => 32,
                primary_key => 1,
            },
            user_id => {
                type => 'char',
                length => ID_LEN,
                nullable => 1,
            },
            last_modified => {
                type => 'timestamp',
                nullable => 1,
            },
            a_session => {
                type => 'text',
                nullable => 1,
            },
        ],
    },
);


@RELATIONS = (
    {
        columns_from => [q{sessions}, 'user_id'],
        columns_to => [q{User}, 'user_id'],
        cardinality => [1, 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    }
);

1;

__END__

=head1 NAME
                    
Gestinanna::Schema::Session - schema for sessions
                    
=head1 SYNOPSIS   
                
 use Gestinanna::Schema::Session;
                    
 $tables = Gestinanna::Schema::Session -> init_schema(
    schema => $schema
 );
                    
 Gestinanna::Schema::Session -> init_relations(
    schema => $schema,
    tables => $tables,
 );
                    
=head1 DESCRIPTION
                    
=head1 AUTHOR
                
James G. Smith, <jsmith@cpan.org>  
                    
=head1 COPYRIGHT
                  
Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
                    
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
