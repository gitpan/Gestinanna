# $Id: Request.pm,v 1.2 2004/04/05 16:08:13 jgsmith Exp $

package Gestinanna::Upload;

=head1 NAME

Gestinanna::Upload - manages file uploads

=head1 METHODS

=head2 new

=begin testing

# new

__OBJECT__ = __PACKAGE__ -> new(
    name => 'name',
    filename => 'filename',
    size => '1234',
    type => 'mime/type',
    hash => 'hash'
);

isa_ok(__OBJECT__, __PACKAGE__);

=end testing

=cut

sub new {
    my $class = shift;
    $class = ref $class || $class;

    return bless {
        @_
    } => $class;
}

=head2 name

=begin testing

# name

is(__OBJECT__ -> name, 'name');

=end testing

=cut

sub name { $_[0] -> {name} }

=head2 filename

=begin testing

# filename

is(__OBJECT__ -> filename, 'filename');

=end testing

=cut

sub filename { $_[0] -> {filename} }

=head2 fh

sub fh { 
    my $self = shift;  # return IO::String object
    my $R = Gestinanna::Request -> instance;

    my $ob = $R -> factory(upload => object_id => $self -> {id});
    return IO::String -> new($ob -> content);
}

=head2 content

sub content {
    my $self = shift;  # return IO::String object
    my $R = Gestinanna::Request -> instance;

    my $ob = $R -> factory(upload => object_id => $self -> {id});
    return \($ob -> content);
}

=head2 size

=begin testing

# size

is(__OBJECT__ -> size, 1234);

=end testing

=cut

sub size { $_[0] -> {size} }

=head2 info

sub info { @_ > 1 ? undef : { } }

=head2 type

=begin testing

# type

is(__OBJECT__ -> type, 'mime/type');

=end testing

=cut

sub type { $_[0] -> {type} }

=head2 hash

=begin testing

# hash

is(__OBJECT__ -> hash, 'hash');

=end testing

=cut

sub hash { $_[0] -> {hash} }

1;

__END__
