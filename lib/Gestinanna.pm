package Gestinanna;

use Gestinanna::Schema;

use base qw(Exporter);

our @EXPORT = qw(shell tkgui);

our $VERSION = '0.01';

sub shell {
    eval {
        require Gestinanna::Shell;
    };

    return if $@;

    Gestinanna::Shell -> shell(@_);
}

sub tkgui {
    eval {
        require Gestinanna::TkGUI;
    };

    return if $@;

    Gestinanna::TkGUI -> tkgui(@_);
}

1;

__END__

=head1 NAME

Gestinanna - core model for the Gestinanna application framework

=head1 SYNOPSIS

 use Gestinanna;

=head1 DESCRIPTION

=head1 AUTHOR
        
James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
        
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
