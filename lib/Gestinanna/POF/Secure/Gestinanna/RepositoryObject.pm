package Gestinanna::POF::Secure::Gestinanna::RepositoryObject;

use base qw(Class::Container);
use NEXT;

use strict;

sub save {
    # we want to move actor->object_id tag when we save
    my $self = shift;

    return unless $self -> {actor};  # actor required for saving, optional for loading

    # do any branching here if actor is not owner of edited revision

#    warn "Saving $self\n";

    my($actor_type, $actor_id);

    if($self -> {actor}) {
        ($actor_type, 
         $actor_id) = ($self -> {actor} -> object_type, 
                       $self -> {actor} -> object_id);
    }
    else {
        ($actor_type, $actor_id) = ('UNKNOWN', 'UNKNOWN');
    }

    if($self -> {user_type} ne $actor_type ||
       $self -> {user_id}   ne $actor_id)
    {
        $self -> {user_type} = $actor_type;
        $self -> {user_id  } = $actor_id;
        $self -> branch if $self -> revision;
    }

    $self -> NEXT::save(@_);  # pass on any parameters, though we don't expect any

    if($actor_type ne 'UNKNOWN' && $actor_id ne 'UNKNOWN') {
        # move actor's tag
        my $tag = $self -> tag_class -> init(
            tag => $actor_id,
            object_id => $self -> {name},
            alzabo_schema => $self -> {alzabo_schema},
            _factory => $self -> {_factory},
        );

        $tag -> {revision} = $self -> {revision};
        $tag -> save;
    }

    #warn "Returning from $self -> save\n";
    return 1;
}

1;

__END__

=head1 NAME

Gestinanna::POF::Secure::Gestinanna::RepositoryObject - basic support for a revision controlled repository

=head1 SYNOPSIS

 package My::Files;

 use Gestinanna::POF::Repository qw(Files);

Creates the packages C<My::Files::Object>, C<My::Files::Tag>, and 
C<My::Files::Description>.  Use C<My::Files::Object> as the main 
POF object.

=head1 DESCRIPTION

A repository (for the purposes of this module) is a collection of 
revision-controlled objects in an RDBMS accessed through L<Alzabo|Alzabo>.

=head1 SCHEMA

The repository expects the following schema.  This assumes 
C<use Gestinanna::POF::Repository qw(Prefix)>.

=head2 Table `Prefix'

This is the primary object store and has the following columns.  
Additional text columns named C<data> or starting with C<data_> 
may be added.  These columns are then the default set of 
revision-controlled columns.

=over 4

=item prefix

This is the unique id of the object revision.  This may be used 
to establish relationships with other tables.

=item name

This is the name of the object.  The name and revision (together) 
must be unique.

=item revision

This is the revision of the object.  This is a text string of 
period (.) separated numbers following the RCS/CVS convention for 
denoting branches and versions.

=item modify_timestamp

This is the timestamp of the revision (when it was saved to the RDBMS).

=item user_type

This is the type of the user that created the revision.

=item user_id

This is the id of the user that created the revision.

=item log

This is any log text added by the user when the revision was created.

=back

=head2 Table `Prefix_Tag'

This table maps tags and names to revisions.  Any tag and name combination must be unique.

=over 4

=item tag

This is the name of the tag.  This is part of the primary key.

=item name

This is the name of the tagged object.  This is also part of the primary key.

=item revision

This is the revision of the object the tag points to.

=back

=head2 Table `Prefix_Drescription'

This table is for convenience.  It holds metadata that is not tied to a particular revision.

=over 4

=item name

This is the name of the object being described.

=item description

This is a text description of the object.

=back

=head1 METHODS

While the repository classes are based on 
L<Gestinanna::POF::Alzabo|Gestinanna::POF::Alzabo>, they extend 
the functionality to allow management of the repository while 
still allowing simple use of the objects within the repository.

=head2 Description Class

This class is directly based on 
L<Gestinanna::POF::Alzabo|Gestinanna::POF::Alzabo> and does not 
behave any differently than would be expected.  See 
L<Gestinanna::POF::Alzabo> for more information.

If the description of an object is deleted and the Alzabo schema 
is enforcing data integrity, then all revision history for the 
object will be deleted as well.

=head2 Object Class

The object_id is the name of the object (C<object_id> is an alias 
for C<name> in the constructor).  If C<revision> is given, then 
that revision is loaded.  If no revision is given but a tag_path 
is supplied, then the tags are searched until one is found 
pointing to a revision of the named object.

Saving an object will not modify any existing row in the RDBMS 
but will create a new row storing the differences between that 
version of the object and the previous version.  If a more recent 
version of the object exists in the branch, then a new branch is 
created.  Otherwise, a new revision is created in the same branch.

What is done during a save may be modified by calling C<branch> 
or C<merge> beforehand.

Revision numbers are Perl ordinal strings.  For example, C<v1.1> 
is the first revision of the first branch.  C<v1.1.1.1> is the 
first revision of the first branch of the first revision of the 
first branch.  Etc.  This is an added feature in Perl 5.6.0.

=head2 Tag Class

=head1 AUTHOR

=head1 COPYRIGHT
