package Gestinanna::Schema::Document;

use Gestinanna::Schema::Base;
use Gestinanna::Schema::Repository qw(Document);
use strict;
use vars qw(@ISA @TABLES @RELATIONS @OBSOLETE);

@ISA = qw(Gestinanna::Schema::Repository);

@TABLES = (
    Document => {
        columns => [
            data => {
                type => 'text',
            },
        ],
    },
);

@RELATIONS = (

);

1;

__END__

=head1 NAME

Gestinanna::Schema::Document - Schema for simple documents

=head1 SYNOPSIS

 use Gestinanna::Schema::Document;

 $tables = Gestinanna::Schema::Document -> init_schema(
    schema => $schema
 );

 Gestinanna::Schema::Document -> init_relations(
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
