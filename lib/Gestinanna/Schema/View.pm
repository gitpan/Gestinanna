package Gestinanna::Schema::View;

use Gestinanna::Schema::Base;
use Gestinanna::Schema::Repository qw(View);
use strict;
use vars qw(@ISA @TABLES @RELATIONS @OBSOLETE);

@ISA = qw(Gestinanna::Schema::Repository);

@TABLES = (
    View => {
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

Gestinanna::Schema::View - Schema for Template Toolkit views

=head1 SYNOPSIS

 use Gestinanna::Schema::View;

 $tables = Gestinanna::Schema::View -> init_schema(
    schema => $schema
 );

 Gestinanna::Schema::View -> init_relations(
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
