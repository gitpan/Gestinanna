package Gestinanna::Schema::Site;

use Gestinanna::Schema::Base qw(ID_LEN);
use strict;
use vars qw(@ISA @TABLES @OBSOLETE @RELATIONS);

@ISA = qw(Gestinanna::Schema::Base);

@TABLES = (
    Site => {
        columns => [
            site => {
                type => 'int',
                primary_key => 1,
                sequenced => 1,
            },
            name => {
                type => 'text',
            },
            configuration => {
                type => 'text',
            },
        ],
    },
    Uri_Map => {
        columns => [
            site => {
                type => 'int',
                primary_key => 1,
            },
            uri => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
            },
            file => {
                type => 'char',
                length => ID_LEN,
            },
            type => {
                type => 'char',
                length => ID_LEN,
            },
        ],
        indices => [
            { 
                columns => [qw(site file)]
            }
        ],
    },
    Embedding_Map => {
        columns => [
            site => {
                type => 'int',
                primary_key => 1,
                default => 0,
            },
            theme => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
                nullable => 1,
            },
            path => {
                type => 'char',
                length => ID_LEN,
                primary_key => 1,
            },
            type => {
                type => 'char',
                length => ID_LEN,
            },
            file => {
                type => 'char',
                length => ID_LEN,
            },
        ],
    },
);

@RELATIONS = (
    {
        columns_from => [q{Uri_Map}, 'site'],
        columns_to => [q{Site}, 'site'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
    {
        columns_from => [q{Embedding_Map}, 'site'],
        columns_to => [q{Site}, 'site'],
        cardinality => ['n', 1],
        from_is_dependent => 1,
        to_is_dependent => 0,
    },
);

1;
