package Gestinanna::Schema::Context;

use Gestinanna::Schema::Base qw(ID_LEN);
use strict;
use vars qw(@ISA @TABLES @OBSOLETE @RELATIONS);

@ISA = qw(Gestinanna::Schema::Base);

@TABLES = (
    Context => {
        columns => [
            id => {
                type => 'char',
                length => 44,
                primary_key => 1,
            },
            parent => {
                type => 'char',
                length => 44,
                nullable => 1,
            },
            filename => {
                type => 'char',
                length => ID_LEN,
            },
            ascension => {
                type => 'timestamp',
                nullable => 1,
            },
            user_id => {
                type => 'char',
                length => ID_LEN,
                nullable => 1,
            },
            context => {
                type => 'text',
            },
        ],
    },
);

@RELATIONS = (
    {
        columns_from => [Context => 'parent'],
        columns_to => [Context => 'id'],
        cardinality => [n => 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
    {
        columns_from => [Context => 'user_id'],
        columns_to => [User => 'user_id'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
);

1;
