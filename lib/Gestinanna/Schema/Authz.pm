package Gestinanna::Schema::Authz;

use Gestinanna::Schema::Base qw(ID_LEN TYPE_LEN);
use strict;
use vars qw(@ISA @TABLES @RELATIONS @OBSOLETE);

@ISA = qw(Gestinanna::Schema::Base);

@OBSOLETE = ( );

@TABLES = (
    Object_Type => {
        columns => [
            type => {
                type => 'char',
                length => TYPE_LEN,
                primary_key => 1,
            },
            description => {
                type => 'text',
            },
        ],
    },
    Object_Class => {
        columns => [
            type => {
                type => 'char',
                length => TYPE_LEN,
                primary_key => 1,
            },
            site => {
                type => 'int',
                primary_key => 1,
            },
            file => {
                type => 'char',
                length => ID_LEN,
                nullable => 1,
            },
            class => {
                type => 'char',
                length => ID_LEN,
                nullable => 1,
            },
        ],
    },
    Attribute => {
        columns => [
            id => {
                type => 'integer',
                primary_key => 1,
                sequenced => 1,
            },
            resource_type => {
                type => 'char',
                length => TYPE_LEN,
                #primary_key => 1,
            },
            resource_id => {
                type => 'char',
                length => ID_LEN,
                #primary_key => 1,
            },
            user_type => {
                type => 'char',
                length => TYPE_LEN,
                #primary_key => 1,
            },
            user_id => {
                type => 'char',
                length => ID_LEN,
                #primary_key => 1,
            },
            granter_id => { # special handling when granter is removed from system
                type => 'char',
                length => ID_LEN,
                nullable => 1, # for top-level grants
                #primary_key => 1,
            },
            granted_at => { # most recent grant takes precedence over older ones
                type => 'timestamp',
                nullable => 1,
            },
            attribute => {
                type => 'char',
                length => TYPE_LEN,
                #primary_key => 1,
            },
            value => {
                type => 'int',
            },
        ],
        indices => [
            { columns => [qw(user_type user_id)] },
            { columns => [qw(resource_type resource_id user_type user_id attribute)], unique => 1},
        ],
    },
    Authz_Group_Member => {
        columns => [
            #pid => {
            #    type => 'integer',
            #    primary_key => 1,
            #    sequenced => 1,
            #},
            id => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
            },
            user_type => {
                type => 'char',
                length => TYPE_LEN,
                primary_key => 1,
            },
            user_id => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
            },
            priority => {
                type => 'int',
            },
        ],
        indices => [
            #{ columns => [qw(id user_type user_id)], unique => 1 },
            { columns => [qw(user_type user_id)] },
        ],
    },
    Authz_Group => {
        columns => [
            id => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
            },
            name => {
                type => 'char',
                length => ID_LEN,
            },
            priority => {
                type => 'int',
                default => 0,
            },
        ],
    },
);

@RELATIONS = (
    {
        columns_from => [Authz_Group_Member => 'id'],
        columns_to => [Authz_Group => 'id'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
    {
        columns_from => [Authz_Group_Member => 'user_type'],
        columns_to => [Object_Type => 'type'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
    {
        columns_from => [Attribute => 'user_type'],
        columns_to => [Object_Type => 'type'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
    {
        columns_from => [Attribute => 'resource_type'],
        columns_to => [Object_Type => 'type'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
    {
        columns_from => [Object_Class => 'type'],
        columns_to => [Object_Type => 'type'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
);

1;

__END__

=head1 NAME

Gestinanna::Schema::Authz - schema for authorization

=head1 SYNOPSIS

 use Gestinanna::Schema::Authz;

 $tables = Gestinanna::Schema::Authz -> init_schema(
    schema => $schema
 );

 Gestinanna::Schema::Authz -> init_relations(
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
