package Gestinanna::Exception;

use base qw(Error);
use overload 
    'bool' => 'bool',
    '""'   => 'to_string',
;
use strict;

=begin testing

# class

eval {
    throw __PACKAGE__
        -class => 'foo.bar'
    ;
};

my $e = $@;

ok($e);
isa_ok($e, '__PACKAGE__');
ok($e -> class('foo'));
ok($e -> class('foo.bar'));
ok(!$e -> class('foo.bar.baz'));
ok(!$e -> class('foo.ba.'));
ok($e -> class('foo.'));

=end testing

=cut

sub class {
    my $self = shift;
    my $class = shift;

    if(defined $class) {
        my $qrclass = qr{^\Q$class\E};
        return 1 if $self -> {'-class'} =~ m{$qrclass(\.|$)}
                 || $class =~ m{\.$}
                    && $self -> {'-class'} =~ m{$qrclass};
  
        return 0;
    }

    return $self -> {'-class'};
}

=begin testing

# bool

eval {
    throw __PACKAGE__
    ;
};

my $e = $@;

ok($e);
isa_ok($e, '__PACKAGE__');
is($e -> bool, 1);
is(($e ? 1 : 0), 1);

=end testing

=cut

sub bool { 1; }

=begin testing

# to_string

eval {
    throw __PACKAGE__
        -text => 'This is %s much %s',
        -param => [qw(so fun)],
    ;
};

my $e = $@;

ok($e);
isa_ok($e, '__PACKAGE__');
is($e -> to_string, q{This is so much fun});
is("".$e, q{This is so much fun});

=end testing

=cut

sub to_string {
    my $self = shift;

    return "" unless defined $self -> {'-text'};

    return sprintf($self -> {'-text'}, @{$self -> {'-param'}||[]});
}

=begin testing

# exception

eval {
    throw __PACKAGE__
        -e => 'THis',
    ;
};

my $e = $@;

ok($e);
isa_ok($e, '__PACKAGE__');
is($e -> exception, 'THis');

=end testing

=cut

sub exception {
    my $self = shift;

    return $self -> {'-e'};
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
