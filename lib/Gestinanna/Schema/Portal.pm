package Gestinanna::Schema::Portal;

use Gestinanna::Schema::Base;
use Gestinanna::Schema::Repository qw(Portal);
use strict;
use vars qw(@ISA @OBSOLETE @TABLES @RELATIONS);

# we need to add authorization info
# perhaps make it general for any resource?  in that case, it 
# needs to be in the Authz module

@ISA = qw(Gestinanna::Schema::Repository);

@OBSOLETE = (
);

@TABLES = (
    Portal => {
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
                    
Gestinanna::Schema::XSM - schema for state machine/wizard-like applications
                    
=head1 SYNOPSIS   
                
 use Gestinanna::Schema::XSM;
                    
 $tables = Gestinanna::Schema::XSM -> init_schema(
    schema => $schema
 );
                    
 Gestinanna::Schema::XSM -> init_relations(
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
