package Gestinanna::POF::Secure::Gestinanna;

use base qw(Gestinanna::POF::Secure);
use Gestinanna::Authz;

our $VERSION = '0.01';

our $REVISION = 'something';

__PACKAGE__->valid_params (
    authz => { isa => q(Gestinanna::Authz), },
);

__PACKAGE__->contained_objects (
    authz => { class => q(Gestinanna::Authz), },
);

=begin testing

# has_access

sub __PACKAGE__::get_auth_id { [ 'temp', '/stuff' ] }

__OBJECT__ = __PACKAGE__ -> new(
    authz => $authz
);

=end testing

=cut

sub has_access {
    my($self, $attribute, $requirements) = @_;

    #warn("$self -> has_access($attribute, ...)\n");

    return unless defined $self -> {authz};

    return unless defined $self -> {actor};

    my $self_id = $self -> get_auth_id;
    $self_id -> [1] .= "/\@$attribute" if defined $attribute;

#    main::diag("has_access: $$self_id[1]");

    return $self -> {authz} -> has_attribute($self -> {actor} -> get_auth_id, $self_id, $requirements);
}

1;

__END__

=head1 NAME

Gestinanna::POF::Secure::Gestinanna - provides security for POF classes in the Gestinanna application framework

=head1 SYNOPSIS

 package My::DataObject;

 use base qw(Gestinanna::POF::Secure);
 use base qw(Gestinanna::POF::Container);

 __PACKAGE__ -> contained_objects(
 );

=head1 DESCRIPTION

This module provides basic security using the 
L<Gestinanna::Authz|Gestinanna::Authz> module.
This may be added to any POF class by adding it as the first 
member of the C<@ISA> array.

The following parameters are required for the security code.

=over 4

=item actor

This is the object acting on this object.  Permissions are based 
on both the actor and the object being acted upon.

=item cache

This is actually an optional parameter.  This is used to cache 
authorization information.  This should be derived from the 
L<Cache::Cache|Cache::Cache> module.

=item schema

This is the L<Alzabo|Alzabo> runtime schema that can be passed to 
the L<Gestinanna::Runtime::Authz|Gestinanna::Runtime::Authz> object.

=back

=head1 METHODS

=head2 ACCESS METHODS

By default, access methods are created as needed for attributes.  
The following are part of the base POF object class and should 
not be used for anything else.

=over 4

=item actor

=back

=head1 TODO

Need to be able to query available attributes considering security and not considering security.
