package Gestinanna::Schema::User;

use Gestinanna::Schema::Base qw(ID_LEN TYPE_LEN);
use strict;
use vars qw(@ISA @TABLES @RELATIONS @OBSOLETE);

@ISA = qw(Gestinanna::Schema::Base);

@TABLES = (
    User => {
        columns => [
            user_id => {
                type => 'int',
                primary_key => 1,
                sequenced => 1,
            },
            uid => {
                type => 'char',
                length => ID_LEN,
                nullable => 1,
            },
            password => {
                type => 'char',
                length => 32,
            },
            email => {
                type => 'text',
                nullable => 1,
            },
        ],
    },
    Username => {
        columns => [
            username => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
            },
            user_id => {
                type => 'int',
                nullable => 1,
            },
            password_check => {
                type => 'char',
                length => 32,
            },
            activated => {
                type => 'datetime',
                nullable => 1,
            },
        ],
    },
    Username_Log => {
        columns => [
            id => {
                type => 'int',
                primary_key => 1,
                sequenced => 1,
            },
            username => {
                type => 'char',
                length => ID_LEN,
            },
            action_when => {
                type => 'timestamp',
                nullable => 1,
            },
            actor_type => {
                type => 'char',
                length => ID_LEN,
            },
            actor_id => {
                type => 'char',
                length => ID_LEN,
            },
            action => {
                #type => 'enum("add","del","mod","res","misc")',
                type => 'char',
                length => 4,
            },
            comment => {
                type => 'text',
            }
        ],
    },
);

@RELATIONS = (
    {
        columns_from => [q{User}, 'user_id'],
        columns_to => [q{Username}, 'user_id'],
        cardinality => [1, 'n'],
        from_is_dependent => 0,
        to_is_dependent => 0,
    },
    {
        columns_from => [q{Username}, 'username'],
        columns_to => [q{Username_Log}, 'username'],
        cardinality => [1, 'n'],
        from_is_dependent => 0,
        to_is_dependent => 1,
    }
);

1;

__END__

=head1 NAME
                    
Gestinanna::Schema::User - schema for users
                    
=head1 SYNOPSIS   
                
 use Gestinanna::Schema::User;
                    
 $tables = Gestinanna::Schema::User -> init_schema(
    schema => $schema
 );
                    
 Gestinanna::Schema::User -> init_relations(
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
