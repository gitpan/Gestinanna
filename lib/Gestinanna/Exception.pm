package Gestinanna::Exception;

use base qw(Error);
use overload 'bool' => 'bool';
use strict;

# based on Apache::AxKit::Exception

sub bool { 1; }

sub value {
    my $self = shift;

    exists $self->{'-value'} ? $self->{'-value'} : 1;
}

BEGIN {
    eval qq{\@${_}::ISA = (qw(Gestinanna::Exception));}
        for (qw(
            Gestinanna::Exception::Authz
            Gestinanna::Exception::Error
            Gestinanna::Exception::Load
	    Gestinanna::Exception::Schema
        ));
}

1;

__END__

=head1 NAME

Gestinanna::Exception - Exception classes used by the Gestinanna framework

=head1 SYNOPSIS

 use Gestinanna::Exception qw(:try);

 try {
     throw Gestinanna::Exception::Error(
         -text => "Something happened!"
     );
 } 
 catch Gestinanna::Exception::Error with {
 };

=head1 DESCRIPTION

=head1 PRE-DEFINED EXCEPTION CLASSES

=over 4

=item Gestinanna::Exception::Authz

=item Gestinanna::Exception::Error

=item Gestinanna::Exception::Load

=item Gestinanna::Exception::Schema

=back

=head1 AUTHOR
                
James G. Smith, <jsmith@cpan.org>  
                    
=head1 COPYRIGHT
                  
Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
                    
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
