package Gestinanna::XSM::LibXMLSupport;

use strict;
use XML::LibXML 1.50;
#use Apache::AxKit::Provider;

use vars qw($provider_cb);

$provider_cb = \&get_provider;

=begin testing

# reset

__PACKAGE__::__METHOD__;

#is($XML::LibXML::match_cb, \&match_uri);
#is($XML::LibXML::read_cb, \&read_uri);
#is($XML::LibXML::close_cb, \&close_uri);
#is($XML::LibXML::open_cb, \&open_uri);

=end testing

=cut

sub reset {
    my $class = shift;
    $XML::LibXML::match_cb = \&match_uri;
    $XML::LibXML::read_cb = \&read_uri;
    $XML::LibXML::close_cb = \&close_uri;
    $XML::LibXML::open_cb = \&open_uri;
}

=begin testing

# get_provider

my $provider = __PACKAGE__::__METHOD__; # will need ($r) here eventually

ok(UNIVERSAL::isa($provider, 'CODE'));

ok($provider -> ( ) eq '');

=end testing

=cut

# Default provider callback
sub get_provider {
    my $r = shift;
#    my $provider = Apache::AxKit::Provider->new_content_provider($r);
    my $provider = sub { return ''; };
    return $provider;
}

=begin testing

# match_uri

=end testing

=cut

sub match_uri {
    my $uri = shift;
#    AxKit::Debug(8, "LibXSLT match_uri: $uri");
    return 1 if $uri =~ /^(axkit|xmldb):/;
    return $uri !~ /^\w+:/; # only handle URI's without a scheme
}

=begin testing

# open_uri

=end testing

=cut

sub open_uri {
    my $uri = shift || './';
    #AxKit::Debug(8, "LibXSLT open_content_uri: $uri");
    
#    if ($uri =~ /^axkit:/) {
#        return AxKit::get_axkit_uri($uri);
#    } elsif ($uri =~ /^xmldb:/) {
#        return Apache::AxKit::Provider::XMLDB::get_xmldb_uri($uri);
#    }
    
    # create a subrequest, so we get the right AxKit::Cfg for the URI
    #my $apache = AxKit::Apache->request;
    #my $sub = $apache->lookup_uri(AxKit::FromUTF8($uri));
    #local $AxKit::Cfg = Apache::AxKit::ConfigReader->new($sub);
    
    #my $provider = $provider_cb->($sub);
    #my $str = $provider->get_strref;
    
    #undef $provider;
    #undef $apache;
    #undef $sub;
    
    #return $$str;
    return '';
}

=begin testing

# close_uri

=end testing

=cut

sub close_uri {
    # do nothing
}

=begin testing

# read_uri

=end testing

=cut

sub read_uri {
    return substr($_[0], 0, $_[1], "");
}

1;
__END__

=head1 NAME

Apache::AxKit::LibXMLSupport - XML::LibXML support routines

=head1 SYNOPSIS

  require Apache::AxKit::LibXMLSupport;
  Apache::AxKit::LibXMLSupport->setup_libxml();

=head1 DESCRIPTION

This module sets up some things for using XML::LibXML in AxKit. Specifically this
is to do with callbacks. All callbacks look pretty much the same in AxKit, so
this module makes them editable in one place.

=head1 API

There is just one method: C<< Apache::AxKit::LibXMLSupport->setup_libxml() >>.

You can pass a parameter, in which case it is a callback to create a provider
given a C<$r> (an Apache request object). This is so that you can create the
provider in different ways and register the fact that it was created. If you
don't provide a callback though a default one will be provided.

=cut

