package Gestinanna::Schema::XSLT;

use Gestinanna::Schema::Base;
use Gestinanna::Schema::Repository qw(XSLT);
use strict;
use vars qw(@ISA @TABLES @RELATIONS @OBSOLETE);

@ISA = qw(Gestinanna::Schema::Repository);

@TABLES = (
    XSLT => {
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

Gestinanna::Schema::XSLT - Schema for simple documents

=head1 SYNOPSIS

 use Gestinanna::Schema::XSLT;

 $tables = Gestinanna::Schema::XSLT -> init_schema(
    schema => $schema
 );

 Gestinanna::Schema::XSLT -> init_relations(
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
