package Gestinanna;

use Gestinanna::Schema;

use base qw(Exporter);

our @EXPORT = qw(shell tkgui);

our $VERSION = '0.02';

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

 perl -MGestinanna -e shell

See L<Apache::Gestinanna|Apache::Gestinanna> for web use.

See L<Gestinanna::Shell|Gestinanna::Shell> for more information on the shell.

=head1 DESCRIPTION

The Gestinanna application framework provides a highly scalable 
application development environment.  The framework works tightly 
with AxKit to provide all the power of AxKit with a highly inheritable 
and orthogonal model-view-controller system.

=head2 Content Providers

Four content providers are defined in Gestinanna.

=over

=item Document

A document is unmodified data that is used as-is with no interpretation 
within Gestinanna.

=item Portal

A portal document is a description of a page which may contain embedded 
documents.  This is useful for creating a common frame for a site.

=item View

A view document is processed by Template Toolkit before being sent to 
AxKit as part (or all) of the page.

=item XSM

An eXtensible State Machine is used to select a document that will be 
used based on the data received from the browser.  The document may be 
of any of the document classes supported by Gestinanna.  See 
L<Gestinanna::XSM|Gestinanna::XSM> for more information.

=back

=head2 Data Providers

Gestinanna creates an object factory (see L<Gestinanna::POF|Gestinanna::POF>) 
that may be used to instantiate objects from permanent storage.  Most 
objects will be based on Gestinanna::POF object classes.  See 
L<Apache::Gestinanna|Apache::Gestinanna> for resource configuration information.

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002-2004 Texas A&M University.  All Rights Reserved.
        
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
