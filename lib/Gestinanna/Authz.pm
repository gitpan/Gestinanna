package Gestinanna::Authz;

use Gestinanna::Authz::Path;

use Carp;

use Data::Dumper (); # for debugging

use strict;
use vars qw($VERSION);

$VERSION = '0.00_02';

sub new {
    my $self = shift;
    my $class = ref $self || $self;

    return bless { @_ } => $class;
}

sub fetch_acls { 
    my($self, $user, $path) = @_;

    # table: resource_type resource_id user_type user_id attribute value
    my $table = $self -> {alzabo_schema} -> table('Attribute');
    my $cursor = $table -> rows_where( 
        where => [
            '(',
              [ $table -> column('resource_type'), '=', $path->[0] ],
              'or',
              [ $table -> column('resource_type'), '=', '*' ],
            ')',
            'and',
            '(',
              [ $table -> column('user_type'), '=', $user->[0] ],
              'or',
              [ $table -> column('user_type'), '=', '*' ],
            ')',
        ],
    );

    my %acls;

    my $row;
    while($row = $cursor -> next) {
        my($rtype, $rid, $utype, $uid, $attr, $v) =
            $row -> select(qw(resource_type resource_id user_type user_id attribute value));
        next if exists $acls{$utype}{$rtype}{$uid}{$rid}{$attr} && $acls{$utype}{$rtype}{$uid}{$rid}{$attr} > $v;
        $acls{$utype}{$rtype}{$uid}{$rid}{$attr} = $v;
    }

    my %ret;
    # non'*' overrides '*'
    foreach my $c (
        [ $user->[0], $path->[0] ],
        [ $user->[0], '*' ],
        [ '*', $path->[0] ],
        [ '*', '*' ],
    ) {
        foreach my $suid ( keys %{$acls{$c->[0]}{$c->[1]}||{}} ) {
            foreach my $srid ( keys %{$acls{$c->[0]}{$c->[1]}{$suid}||{}} ) {
                foreach my $attr ( keys %{$acls{$c->[0]}{$c->[1]}{$suid}{$srid}||{}} ) {
                    next if defined $ret{$suid}{$srid}{$attr};
                    #warn "<$suid,$srid,$attr> = " . $acls{$c->[0]}{$c->[1]}{$suid}{$srid}{$attr} . "\n";
                    $ret{$suid}{$srid}{$attr} = $acls{$c->[0]}{$c->[1]}{$suid}{$srid}{$attr};
                }
            }
        }
    }
            
    return \%ret;
}

#sub fetch_groups { $_[0] -> _abstract; }

#sub fetch_resource_groups { $_[0] -> _abstract; }

sub query_acls {
    my($self, $user, $path) = @_;

    my $facls = $self -> fetch_acls($user, $path);

    #warn "query_acls acls: " . Data::Dumper -> Dump([$facls]);

    my $ppath = $path -> [1];

    my $utype = $user -> [0];
    my $upath = $user -> [1];

    # filter the {user} into bins: 1, 0, -1 (discard undef)
    my @acls;
    my $c;
    my $cmp = $self -> {cmp} ||= Gestinanna::Authz::Path -> new;

    foreach my $u (keys %$facls) {
        $c = $cmp -> path_cmp($upath, $u);
        #warn("$upath <=> $u : $c\n");
        next unless defined $c;
        if($c == 1) {
            $c = 2 if $cmp -> path_cmp($u, $upath) == 1;
        }
        #warn "pushing $u onto acls $c + 1\n";
        push @{$acls[$c+1]||=[]}, $u;
    }

    my @ret;

    my %vars = (
        SELF => $upath,
        SELFTYPE => $utype,
    );

    $vars{'SELF'} =~ s{(^/)|(/$)}{}g;
    $vars{'SELFTYPE'} =~ s{(^/)|(/$)}{}g;

    foreach my $i (0..3) {
        foreach my $u ( @{$acls[$i]||[]} ) {
            delete @vars{grep { /^F\d+/ } keys %vars};
            my $uu = $cmp -> path2regex($u);
            my(@c) = $upath =~ m{^$uu$};
            #warn("$u => " . Data::Dumper -> Dump([\@c]));
            if(@c) {
                for $i (0..$#c) {
                    $vars{"F" . ($i+1)} = "\Q$c[$i]\E";
                }
            }
            #warn("vars: " . Data::Dumper -> Dump([\%vars]));
            my %ps = map { my $p = $_; 
                           $p =~ s{([^/@|&*]+)}{$vars{$1} || $1}egx; 
                           ($p => $_)
                         } keys %{$facls -> {$u}};
            #warn("\%ps: " . Data::Dumper -> Dump([\%ps]));
            #warn "ppath: $ppath\n";
            my @ps = grep { defined $cmp -> path_cmp($ppath, $_) } keys %ps;
            #warn "ps: " . join(", ", @ps) . "\n";
            @{$ret[$i]->{$u}}{@ps} = @{$facls -> {$u}}{@ps{@ps}};
        }
    }

    return \@ret;
}

sub query_attributes {
    my($self, $user, $path) = splice @_, 0, 3;

    return $self -> {_attribute_cache} -> {$user} -> {$path}
        if $self -> {_attribute_cache} -> {$user} -> {$path};

    my $acls = @_ ? shift : $self -> query_acls($user, $path);

    #warn "Acls: " . Data::Dumper -> Dump([$acls]);

    # we want negatives from $acls[2], negatives from $acls[1], and positives/negatives from $acls[0] and $acls[3]
    # want to sort user paths by containment - those contained in another take precedence over the other
    # those `equal' take the minimum of the two

    my $ret;

    my $cmp = $self -> {cmp} ||= Gestinanna::Authz::Path -> new;

    foreach my $i (qw(2 1)) {
        my @us = sort { 
            my $c = $cmp -> path_cmp($a, $b); 
            return 0 unless defined $c;
            return $c if $c < 1; 
            $c = $cmp -> path_cmp($b, $a);
            return 1 unless defined $c;
            return $c == 1 ? 0 : 1;
        } keys %{$acls -> [$i]||{}};

        #warn("Us[$i]: " . join(", ", @us) . "\n");

        foreach my $u (@us) {
            # now sort by how close the path matches the $ppath
            my @ps = sort { 
                my $c = $cmp -> path_cmp($a, $b); 
                return 0 unless defined $c;
                return $c if $c < 1; 
                $c = $cmp -> path_cmp($b, $a);
                return 1 unless defined $c;
                return $c == 1 ? 0 : 1;
            } keys %{$acls -> [$i] -> {$u}};

            foreach my $p (@ps) {
                foreach my $a (keys %{$acls -> [$i] -> {$u} -> {$p}||{}}) {
                    next unless $acls -> [$i] -> {$u} -> {$p} -> {$a};
                    $ret -> {$a} = $acls -> [$i] -> {$u} -> {$p} -> {$a}
                        if( ( !exists($ret -> {$a})
                              || $ret -> {$a} > $acls -> [$i] -> {$u} -> {$p} -> {$a}
                            ) && $acls -> [$i] -> {$u} -> {$p} -> {$a} < 0
                          );
                }
            }
        }

        #main::diag("return: " . Data::Dumper -> Dump([$ret]));
    }

    foreach my $i (qw(0 3)) {
        my @us = sort {
            my $c = $cmp -> path_cmp($a, $b); 
            return 0 unless defined $c;
            return $c if $c < 1; 
            $c = $cmp -> path_cmp($b, $a);
            return 1 unless defined $c;
            return $c == 1 ? 0 : 1;
        } keys %{$acls -> [$i]||{}};

        #warn("Us[$i]: " . join(", ", @us) . "\n");

        foreach my $u (@us) {
            # now sort by how close the path matches the $ppath
            my @ps = sort { 
                my $c = $cmp -> path_cmp($a, $b); 
                return 0 unless defined $c;
                return $c if $c < 1; 
                $c =  $cmp -> path_cmp($b, $a);
                return 1 unless defined $c;
                return $c == 1 ? 0 : 1 
            } keys %{$acls -> [$i] -> {$u}};
    
            #warn "ps: " . Data::Dumper -> Dump([\@ps]);
            foreach my $p (@ps) {
                foreach my $a (keys %{$acls -> [$i] -> {$u} -> {$p}||{}}) {
                    next unless $acls -> [$i] -> {$u} -> {$p} -> {$a};
                    $ret -> {$a} = $acls -> [$i] -> {$u} -> {$p} -> {$a}
                        if( ( !exists($ret -> {$a})
                              || $ret -> {$a} < $acls -> [$i] -> {$u} -> {$p} -> {$a}
                            )
                          );
                }
            }
        }
        
        #main::diag("return: " . Data::Dumper -> Dump([$ret]));

    }

    return $self -> {_attribute_cache} -> {$user} -> {$path} = $ret;
    return $ret;
}

#sub query_resource_groups {
#    my($self, $path) = @_;
#
#    my $groups = $self -> fetch_resource_groups($path);
#
#}

sub has_attribute {
    my($self, $user, $path, $needs) = @_;

    # need to be able to query group memberships and resource groups

    my $attrs;

    $attrs = $self -> query_attributes($user, $path);

    # now do comparison with $needs
    my %denied;
    my %allowed;
     
    @denied{grep { $attrs->{$_} < 0 } keys %$attrs} = ();
    @allowed{grep { $attrs->{$_} > 0 } keys %$attrs} = ();
    
    #warn "Allowed: ", join("; ", keys %allowed), "\n";
    #warn "Denied: ", join("; ", keys %denied), "\n";
    
    return !($self -> _attr_or_eq($needs, \%denied)) if $attrs -> {admin} > 0;
    
    return $self -> _attr_or_eq($needs, \%allowed);
}
     
sub _attr_or_eq {
    my($self, $attr, $match) = @_;
     
    if(ref $attr) {
        foreach my $a (@{$attr}) {
            if(ref $a) {
                return 1 if $self -> _attr_and_eq($a, $match);
            }
            else {
                #warn "_attr_or_eq matching for $a\n";
                if(substr($a, 0, 1) eq "!") {
                    return 1 unless $match->{substr($a, 1)};
                }
                else {
                    return 1 if exists $match->{$a};
                }
            }
        }
    }
    else {
        #warn "_attr_or_eq matching for $attr\n";
        if(substr($attr, 0, 1) eq "!") {
            return 1 unless $match->{substr($attr, 1)};
        }
        else {
            return 1 if exists $match->{$attr};
        }   
    }
    return 0;
}               

sub _attr_and_eq {
    my($self, $attr, $match) = @_;

    if(ref $attr) {
        foreach my $a (@{$attr}) {
            if(ref $a) {
                return 0 unless $self -> _attr_or_eq($a, $match);
            } else {
                #warn "_attr_and_eq matching for $a\n"; 
                if(substr($a, 0, 1) eq "!") {
                    return 0 if $match->{substr($a, 1)};
                } else {
                    return 0 unless exists $match->{$a};
                }
            }
        }
    } else {
        #warn "_attr_and_eq matching for $attr\n";
        if(substr($attr, 0, 1) eq "!") {
            return 0 if $match->{substr($attr, 1)};  
        } else {
            return 0 unless exists $match->{$attr};
        }
    }
    return 1;
}    



1;

__END__

=head1 NAME

Gestinanna::Authz

=head1 SYNOPSIS

 $authz = new My::ACLs;

 if($authz -> has_attributes($user, $path, $attrs)) {
    # do something
 }

=head1 DESCRIPTION

Authz::Path provides the basic logic for ACLs.  It is an abstract 
class that does not actual manage the storage of ACLs.  You will need 
to subclass Authz::Path and provide a storage mechanism.

=head1 PATHS

Paths are made up of a sub-set of the XPath language:

=over 4

=item /

The slash (/) is the component separator.  Alone, it describes the root of the resource heirarchy.

=item //

The double slash (//) stands in place of any number of components 
(zero or more).  Alone, it matches any possible path that does not 
specify attributes or a final component.  To match any component with 
any attributes, use C<//*|//*@*>.

=item @

The at sign (@) is the attribute separator.  A path should only have 
one.  It separates the final component from any attribute.  If no 
attribute follows it, it stands for the general collection of 
attributes for an object.

=item |

The pipe symbol (|) separates paths which together specify a union.

=item &

The ampersand (&) separates paths which together specify an 
intersection.  Intersection has higher precedence to union.  For 
example, the path C<//a/* & //*@name | //b/*> is considered to be 
C<(//a/* & //*@name) | //b/*>, not C<//a/* & (//*@name | //b/*)>.  
There are no parenthesis for grouping in actual path expressions.

=item !

An odd number of initial bangs (!) will negate the following clause, up to 
a pipe (|) or ampersand (&).  An even number of initial bangs will 
have no effect.

=back

Paths may also contain special components:

=over 4

=item SELF

This refers to the path describing the user or actor.  This allows the 
specification of ACLs that are specific to each user without having to 
have a separate ACL for each user.  For example, to allow each user 
their own test area, allow C</testing/SELF//*> for all users that can 
do testing.

=item SELFTYPE

This refers to the type of object described by SELF.  This defaults to C<user>.

=item Fn

The components beginning with C<F> followed by an integer refer to 
particular parts of the user path that are variable, such as C<//> or 
C<*>.  These are numbered starting at 1 and increasing as they are 
encountered.  Each part of an intersection is also counted.

=back

=head2 Examples

The following are some examples of paths.

=over 4

=item //*

This matches any path.  Attaching attributes to this path will 
apply them to all objects.

=item //*@name

This matches the name attribute of all objects.

=item //*/*

This matches any component that is not at the top-level.

=item !//a//* & //b//*

This matches any path that has a C<b> component and not an C<a> 
component.

=back

=head1 METHODS

=head2 fetch_acls

 $acls = $authz -> fetch_acls($user, $resource)

This method must be defined in the derived class.  This method provides 
any ACL information that might be useful in the current ACL query as 
indicated by the user and resource string arguments.

The return value is a hash reference with the following structure:

  { user_path => { resource_path => { %attributes } } }

The attribute mapping maps attribute names to numeric values.  Negative 
values are considered to be prohibitive while positive values are 
permissive.  Undefined or zero values are ignored.

Both C<$user> and C<$resource> will be array references.  The first 
element will be the type of object the path is referring to.  The 
second element will be the path describing the set of such objects.

The safest set of information to return is all ACLs that describe the 
relationship between the C<$user> and C<$resource> object types.

=head2 fetch_groups

 $groups = $authz -> fetch_groups($user);

This method must be defined in the derived class.  This method provides 
the list of user groups the given C<$user> belongs to.  The C<$user> 
may be an actual user or a group.

C<$user> will be an array reference.  The first element will be the type
of the object the path is referring to.  The second element will be 
the path describing the set of such objects.

This method should return an array reference to a list of group names.  
No object types should be specified since they are all user groups.

=head2 fetch_resource_groups

 $groups = $authz -> fetch_resource_groups($resource);

This method must be defined in the derived class.  This method provides 
the list of resource groups the given C<$resource> belongs to.

C<$resource> will be an array reference.  The first element will be the type
of the object the path is referring to.  The second element will be 
the path describing the set of such objects.

This method should return an array reference to a list of group names.
No object types should be specified since they are all resource groups.

ACLs applied to a resource group restrict the possible ACLs that may 
be applied to the resource group for a user or user group.  This makes 
it easy to manage what can be done to a set of resources whether or 
not anyone is actually allowed to do it.

=head2 new

This creates a new authorization object.  The following options may be passed.

=over 4

=item group

This is the string to use to denote the user group type.

=item resource_group

This is the string to use to denote the resource group type.

=item user

This is the string to use to denote the user type.

=back

=head2 path_cmp

This method may be called as either a static function or an object 
method.  If an object is used, then the regular expression translations 
of the path expressions are cached in the object.

 Static method:  Authz::Path::path_cmp($path_a, $path_b)
 Object method: $authz -> path_cmp($path_a, $path_b)

Comparisons of intersections with other intersections are not supported 
(i.e., only one of the paths should have an intersection).  Likewise, 
only one of the paths should contain negations.

This method returns one of four values:

=over 4

=item undef

The two paths describe disjoint sets.

=item 0

The two paths describe overlapping sets.  Both of the paths 
describe elements not described by the other.

=item 1

The first path describes a superset of the set described by the second 
path, or the two paths describe equivalent sets.

=item -1

The first path describes a subset of the set described by the second path.

=back

=head2 path2regex

This method will translate a path to a regular expression.  The 
C<path_cmp> method uses this for certain comparisons.

If this is called as an object method, it will cache translations.  
Otherwise, it may be called as a static method.

 Static method: Authz::Path::path2regex($path);
 Object method: $authz -> path2regex($path)

Some example translations (cleaned up a little):

=over 4

=item //*@*

 qr(?-xism:(?:
     /+           # one or more initial slashes
     ((?:
         [^/@|&]+
         /+
     )*)          # any number of slash-separated path components
     (?:/)*       # any number of trailing slashes
     ([^/@|&]+)   # component
     @
     ([^/@|&]+)   # attribute
 ) )x

=item /*/a | /*/b

 qr(?-xism:
     (?:/([^/@|&]+)/b)  # /<any component>/b
     |                  # OR
     (?:/([^/@|&]+)/a)  # /<any component>/a
 )x

=item /*/a & /*/*@*

 qr(?-xism:(?:
    (?(?=/([^/@|&]+)/a)   # if we match /<any component>/a
        (?:               # then match:
            /
            ([^/\@\|&]+)  # any component
            /
            ([^/\@\|&]+)  # any component
            @
            ([^/\@\|&]+)  # any attribute
        )
    )                     # otherwise, we fail
 ))x

=item !//a//* & //b//*

 qr(?-xism:(?:
    (?(?=
        (?:
            (?! /+((?:[^/@|&]+/+)*)(?:/)*a/+((?:[^/@|&]+/+)*)(?:/)*([^/@|&]+))
            |
            (?:!/+((?:[^/@|&]+/+)*)(?:/)*a/+((?:[^/@|&]+/+)*)(?:/)*([^/@|&]+))
        )
      )
      (?:
                /+((?:[^/@|&]+/+)*)(?:/)*b/+((?:[^/@|&]+/+)*)(?:/)*([^/@|&]+)
      )
    )
 ))x

=back

=head2 query_acls

=head2 query_attributes

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
