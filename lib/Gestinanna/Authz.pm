package Gestinanna::Authz;

use Gestinanna::Util qw(:path);

use Carp;

use Data::Dumper (); # for debugging

use strict;
use vars qw($VERSION);

$VERSION = '0.00_02';

=begin testing

# INIT

our $schema;
our $authz;

$authz = __PACKAGE__ -> new(
    alzabo_schema => $schema
);

=end testing

=head1 NAME

Gestinanna::Authz

=head1 SYNOPSIS

 $authz = Gestinanna::Authz -> new(alzabo_schema => $schema);

 if($authz -> has_attributes($user, $path, $attrs)) {
    # do something
 }

 $authz -> grant($granter, $grantee, $path, $attrs);

=head1 DESCRIPTION

=head1 PATHS

In addition to the paths used by L<Gestinanna::Util/path_cmp|path_cmp>, 
they may also contain special components:

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

=head1 METHODS

=head2 new

 $authz = Gestinanna::Authz -> new(alzabo_schema => $schema);

This constructs a new authorization management object.  The following 
options may be passed.

=over 4

=item group

This is the string to use to denote the user group type.

=item resource_group

This is the string to use to denote the resource group type.

=item alzabo_schema

The L<Alzabo|Alzabo> runtime schema to use when fetching information.

=item user

This is the string to use to denote the user type.

=back

=begin testing

# new

our $schema;

__OBJECT__ = __OBJECT__ -> new(
    alzabo_schema => $schema
);

isa_ok(__OBJECT__, __PACKAGE__);

__OBJECT__ = __PACKAGE__ -> new(
    alzabo_schema => $schema
);

isa_ok(__OBJECT__, __PACKAGE__);

__OBJECT__ = __PACKAGE__::new(
    alzabo_schema => $schema
);

isa_ok(__OBJECT__, __PACKAGE__);

=end testing

=cut

sub new {
    my $self;
    $self = shift if @_ % 2 == 1;
    my $class = ref $self || $self || __PACKAGE__;

    return bless { @_ } => $class;
}

=head2 fetch_acls

 $acls = $authz -> fetch_acls($user, $resource)

This method provides any ACL information that might be useful in the 
current ACL query as indicated by the user and resource string arguments.

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

=begin testing

# fetch_acls

my $acls;

$acls = __OBJECT__ -> fetch_acls([ actor => 1 ], [ xsm => '/sys/std/log-manager' ]);

is_deeply($acls, {
    1 => { 
        '/* | //* | /*@* | //*@*' => { admin => 1 },
        '/sys//* | /sys//*@*' => { read => 3 },
    },
    '*' => { 
        '/sys//* | /sys//*@*' => { read => 1, exec => 1 },
        '/home/SELF//* | /home/SELF//*@*' => { admin => 1 },
    },
});

$acls = __OBJECT__ -> fetch_acls([ actor => 2 ], [ xsm => '/sys/std/log-manager' ]);

is_deeply($acls, {
    1 => { 
        '/* | //* | /*@* | //*@*' => { admin => 1 },
        '/sys//* | /sys//*@*' => { read => 3 },
    },
    '*' => { 
        '/sys//* | /sys//*@*' => { read => 1, exec => 1 },
        '/home/SELF//* | /home/SELF//*@*' => { admin => 1 },
    },
});

$acls = __OBJECT__ -> fetch_acls([ actor => 2 ], [ foo => '/bar' ]);

is_deeply($acls, { 
    1 => { 
        '/* | //* | /*@* | //*@*' => { admin => 1 },
    },
});

$acls = __OBJECT__ -> fetch_acls([ app => 'deadbeef' ], [ xsm => '/sys/std/log-manager' ]);

is_deeply($acls, { });

=end testing

=cut

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
        #next if exists $acls{$utype}{$rtype}{$uid}{$rid}{$attr} && $acls{$utype}{$rtype}{$uid}{$rid}{$attr} > $v;
        $acls{$utype}{$rtype}{$uid}{$rid}{$attr} = $v if !defined($acls{$utype}{$rtype}{$uid}{$rid}{$attr}) || $v > $acls{$utype}{$rtype}{$uid}{$rid}{$attr};
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

=begin testing

# query_point_attributes

my $attrs;

$attrs = __OBJECT__ -> query_point_attributes([actor => '1'], ['*' => '/* | //* | /*@* | //*@*']);
is_deeply($attrs, { admin => 1 });

for my $type (qw(xsm view xslt document portal)) {
    $attrs = __OBJECT__ -> query_point_attributes([actor => '*'], [$type => '/home/SELF//* | /home/SELF//*@*']);
    is_deeply($attrs, { admin => 1 });
    $attrs = __OBJECT__ -> query_point_attributes([actor => '*'], [$type => '/sys//* | /sys//*@*']);
    is_deeply($attrs, { read => 1, exec => 1 });
}

=end testing

=cut

sub query_point_attributes {
    my($self, $user, $path) = @_;

        my $table = $self -> {alzabo_schema} -> table('Attribute');
    my $cursor = $table -> rows_where(
        where => [
            [ $table -> column('resource_type'), '=', $path->[0] ],
            'and',
            [ $table -> column('resource_id'), '=', $path->[1] ],
            'and',
            [ $table -> column('user_type'), '=', $user->[0] ],
            'and',
            [ $table -> column('user_id'), '=', $user->[1] ],
        ],
    );   
    
    my %acls;

    my $row;
    while($row = $cursor -> next) {
        my($attr, $v) =
            $row -> select(qw(attribute value));
        #warn "$attr => $v <=> $acls{$attr}\n";
        #next if exists $acls{$attr} && $acls{$attr} > $v;
        $acls{$attr} = $v if !defined($acls{$attr}) || $v > $acls{$attr};
    }

    return \%acls;
}

sub fetch_groups { 
}

sub fetch_resource_groups {
}

=begin testing

# query_acls

my $acls;

$acls = __OBJECT__ -> query_acls([actor => 1], [xsm => '/sys/std/log-manager']);

is_deeply($acls, [
    {
        '*' => {
            '/sys//* | /sys//*@*' => { read => 1, exec => 1 }
        },
    },
    undef, undef,
    {
        '1' => {
            '/* | //* | /*@* | //*@*' => { admin => 1 },
            '/sys//* | /sys//*@*' => { read => 3 },
        },
    }
]);

$acls = __OBJECT__ -> query_acls([actor => 2], [xsm => '/sys/std/log-manager']);

is_deeply($acls, [
    {
        '*' => {
            '/sys//* | /sys//*@*' => { read => 1, exec => 1 }
        },
    },
    undef, undef, 
    undef,
]);

$acls = __OBJECT__ -> query_acls([actor => 2], [foo => 'bar']);

is_deeply($acls, [ undef, undef, undef, undef ]);


=end testing

=cut

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

    foreach my $u (keys %$facls) {
        $c = path_cmp($upath, $u);
        #warn("$upath <=> $u : $c\n");
        next unless defined $c;
        if($c == 1) {
            $c = 2 if path_cmp($u, $upath) == 1;
        }
        #warn "pushing $u onto acls $c + 1\n";
        push @{$acls[$c+1]||=[]}, $u;
    }

    my @ret = ( undef ) x 4;

    my %vars = (
        SELF => $upath,
        SELFTYPE => $utype,
    );

    $vars{'SELF'} =~ s{(^/)|(/$)}{}g;
    $vars{'SELFTYPE'} =~ s{(^/)|(/$)}{}g;

    foreach my $i (0..3) {
        foreach my $u ( @{$acls[$i]||[]} ) {
            delete @vars{grep { /^F\d+/ } keys %vars};
            my $uu = path2regex($u);
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
            my @ps = grep { defined path_cmp($ppath, $_) } keys %ps;
            #warn "ps: " . join(", ", @ps) . "\n";
            @{$ret[$i]->{$u}}{@ps} = @{$facls -> {$u}}{@ps{@ps}} if @ps;
        }
    }

    return \@ret;
}

=begin testing

# query_attributes

my $attrs;

$attrs = __OBJECT__ -> query_attributes([actor => 1], [xsm => '/sys/std/login-manager']);

is_deeply($attrs, {
    admin => 1,
    read => 3,
    exec => 1,
});

$attrs = __OBJECT__ -> query_attributes([actor => 2], [xsm => '/sys/std/login-manager']);

is_deeply($attrs, {
    exec => 1,
    read => 1,
});

=end testing

=cut

sub query_attributes {
    my($self, $user, $path) = splice @_, 0, 3;

    my $acls = @_ ? shift : $self -> query_acls($user, $path);

    # we want negatives from $acls[2], negatives from $acls[1], and positives/negatives from $acls[0] and $acls[3]
    # want to sort user paths by containment - those contained in another take precedence over the other
    # those `equal' take the minimum of the two

    my $ret;

    foreach my $i (qw(2 1)) {
        my @us = sort { 
            my $c = path_cmp($a, $b); 
            return 0 unless defined $c;
            return $c if $c < 1; 
            $c = path_cmp($b, $a);
            return 1 unless defined $c;
            return $c == 1 ? 0 : 1;
        } keys %{$acls -> [$i]||{}};

        #warn("Us[$i]: " . join(", ", @us) . "\n");

        foreach my $u (@us) {
            # now sort by how close the path matches the $ppath
            my @ps = sort { 
                my $c = path_cmp($a, $b); 
                return 0 unless defined $c;
                return $c if $c < 1; 
                $c = path_cmp($b, $a);
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
            my $c = path_cmp($a, $b); 
            return 0 unless defined $c;
            return $c if $c < 1; 
            $c = path_cmp($b, $a);
            return 1 unless defined $c;
            return $c == 1 ? 0 : 1;
        } keys %{$acls -> [$i]||{}};

        #warn("Us[$i]: " . join(", ", @us) . "\n");

        foreach my $u (@us) {
            # now sort by how close the path matches the $ppath
            my @ps = sort { 
                my $c = path_cmp($a, $b); 
                return 0 unless defined $c;
                return $c if $c < 1; 
                $c =  path_cmp($b, $a);
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

    return $ret;
}

#sub query_resource_groups {
#    my($self, $path) = @_;
#
#    my $groups = $self -> fetch_resource_groups($path);
#
#}

=begin testing

# has_attribute

ok(__OBJECT__ -> has_attribute([actor => 1], [xsm => '/home/1/std/log-manager'], [ 'read' ]));
ok(__OBJECT__ -> has_attribute([actor => 2], [xsm => '/home/2/std/log-manager'], [ 'admin' ]));

=end testing

=cut

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
    
    return !($self -> _attr_or_eq($needs, \%denied)) if defined $attrs -> {admin} && $attrs -> {admin} > 0;
    
    return $self -> _attr_or_eq($needs, \%allowed);
}

=begin testing

# _attr_or_eq

is(__OBJECT__ -> _attr_or_eq( [ 'read', 'write' ], { read => 1 } ), 1);
is(__OBJECT__ -> _attr_or_eq( [ 'read', [ 'write' ] ], { write => 1 } ), 1);

=end testing

=cut
     
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

=begin testing

# _attr_and_eq

is(__OBJECT__ -> _attr_and_eq( [ 'read', 'write' ], { read => 1, write => 0 } ), 0);
is(__OBJECT__ -> _attr_and_eq( [ 'read', 'write' ], { read => 1, write => 1 } ), 1);
is(__OBJECT__ -> _attr_and_eq( [ 'read', [ 'write' ] ], { write => 1, read => 1 } ), 1);
is(__OBJECT__ -> _attr_and_eq( [ 'read', [ 'write', 'exec' ] ], { write => 1, read => 1, exec => 0 } ), 1);

=end testing

=cut
     
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
                    return 0 unless $match->{$a};
                }
            }
        }
    } else {
        #warn "_attr_and_eq matching for $attr\n";
        if(substr($attr, 0, 1) eq "!") {
            return 0 if $match->{substr($attr, 1)};  
        } else {
            return 0 unless $match->{$attr};
        }
    }
    return 1;
}    


###
###

=begin testing

# set_point_attributes

__OBJECT__ -> set_point_attributes([actor => '1'], ['*' => '/* | //* | /*@* | //*@*'], { admin => 1 }, [actor => 1]);
__OBJECT__ -> set_point_attributes([actor => '*'], [$_ => '/home/SELF//* | /home/SELF//*@*'], { admin => 1 }, [actor => 1])
    for qw(xsm view xslt document portal);
__OBJECT__ -> set_point_attributes([actor => '*'], [$_ => '/sys//* | /sys//*@*'], { read => 1, exec => 1 }, [actor => 1])
    for qw(xsm view xslt document portal);
__OBJECT__ -> set_point_attributes([actor => '1'], [$_ => '/sys//* | /sys//*@*'], { read => 3 }, [actor => 1])
    for qw(xsm view xslt document portal);

my $table = __OBJECT__ -> {alzabo_schema} -> table('Attribute');

my $cursor = $table -> all_rows;
my %attrs;

while(my $row = $cursor -> next) {
    my($user_type, $user_id, $r_type, $r_id, $attr, $v, $granter_type, $granter_id) =
        $row -> select(qw(user_type user_id resource_type resource_id attribute value granter_type granter_id));

    $attrs{join(":", $user_type, $user_id, $r_type, $r_id, $granter_type, $granter_id)} -> {$attr} = $v;
}

ok($attrs{join(":", actor => 1, '*' => '/* | //* | /*@* | //*@*', actor => 1)}->{admin} == 1);
ok($attrs{join(":", actor => '*', $_ => '/home/SELF//* | /home/SELF//*@*', actor => 1)}->{admin} == 1)
    for qw(xsm view xslt document portal);
ok($attrs{join(":", actor => '*', $_ => '/sys//* | /sys//*@*', actor => 1)}->{read} == 1
   && $attrs{join(":", actor => '*', $_ => '/sys//* | /sys//*@*', actor => 1)}->{exec} == 1
   && $attrs{join(":", actor => '1', $_ => '/sys//* | /sys//*@*', actor => 1)}->{read} == 3
) for qw(xsm view xslt document portal);

=end testing

=cut

sub set_point_attributes {
    my($self, $actor, $resource, $attributes, $granter) = @_;

    my $table = $self -> {alzabo_schema} -> table('Attribute');

    my %attr = %{$attributes || {}};

    my $cursor = $table -> rows_where(
        where => [
            [ $table -> column('resource_type'), '=', $resource->[0] ],
            'and',
            [ $table -> column('resource_id'), '=', $resource->[1] ],
            'and',
            [ $table -> column('user_type'), '=', $actor->[0] ],
            'and',
            [ $table -> column('user_id'), '=', $actor->[1] ],
        ],
    );
        
    my %acls;

    #warn "Updating attributes for $$resource[0]:$$resource[1] => $$actor[0]:$$actor[1]\n";
    
    my $row;
    while($row = $cursor -> next) {
        my $a = $row -> select('attribute');
        if(exists($attr{$a}) && !defined($attr{$a})) {
    #        warn "  deleting $a\n";
            $row -> delete;
        }
        else {
    #        warn "  updating $a to $attr{$a}\n";
            $row -> update(
                value => delete $attr{$a},
            );
        }
    }

    # add attributes
    my %ids = (
        resource_type => $resource -> [0],
        resource_id => $resource -> [1],
        user_type => $actor -> [0],
        user_id => $actor -> [1],
    );

    if($granter) {
        $ids{granter_type} = $granter -> [0];
        $ids{granter_id} = $granter -> [1];
    }

    foreach my $a (keys %attr) {
        next unless defined $attr{$a}; # don't add what isn't there
    #    warn "  adding $a as  $attr{$a}\n";
        $table -> insert(
            values => {
                %ids,
                attribute => $a,
                value => $attr{$a},
            },
        );
    }
}

=begin testing

# can_grant

ok(__OBJECT__ -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 1}));
ok(__OBJECT__ -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 2}));
ok(!__OBJECT__ -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 3}));
ok(!__OBJECT__ -> can_grant([actor => 1], [actor => 2], [ xsm => '/sys/std/log-manager' ], { read => 4}));
ok(!__OBJECT__ -> can_grant([actor => 2], [actor => 3], [ xsm => '/sys/std/log-manager' ], { exec => 1}));

=end testing

=cut

sub can_grant {
    my($self, $granter, $user, $path, $attributes) = @_;

    my $attr = $self -> query_attributes($granter, $path);
    my $user_attr = $self -> query_attributes($user, $path);

    #if($attr->{admin}) {
    #    foreach my $a (keys %{$attributes}) {
    #        $attr->{$a} = $attr->{admin} unless $attr->{$a};
    #    }
    #}
    #if($user_attr->{admin}) {
    #    foreach my $a (keys %$attributes) {
    #        $user_attr->{$a} = $user_attr->{admin} unless $user_attr->{$a};
    #    }
    #}

    foreach my $a (keys %{$attributes || {}}) {
        $attr -> {$a} = 0 unless defined $attr -> {$a};
        $attr -> {"grant_$a"} = $attr -> {"admin"} unless defined $attr -> {"grant_$a"};
        $user_attr -> {$a} = 0 unless defined $user_attr -> {$a};

        if($attributes->{$a} > 0) {
            #return 0 if !defined $attr -> {$a} && !defined $attr -> {"grant_$a"};
            return 0 if( (!defined($attr->{$a}) || $attr->{$a} < 2 ) && ( !defined($attr -> {"grant_$a"}) || $attr->{"grant_$a"} <= 0) );
            next if $attr->{"grant_$a"} >= $attributes->{$a} 
                 && $attr->{"grant_$a"} >= $user_attr->{$a};
            return 0 unless $attr->{$a} > $attributes->{$a};
            return 0 unless $attr->{$a} > $user_attr->{$a};
        }
        elsif($attributes->{$a} < 0) {
            return 0 if $attr->{$a} < 2 && $attr->{"grant_$a"} <= 0;
            next if $attr->{"grant_$a"} >= -$attributes->{$a} 
                 && $attr->{"grant_$a"} >= $user_attr->{$a};
            return 0 unless $attr->{$a} > -$attributes->{$a};
            return 0 unless $attr->{$a} > abs($user_attr->{$a});
        }
    }
    return 1;
}

=begin testing

# grant

ok(!__OBJECT__ -> has_attribute([actor => 2], [xsm => '/home/1/std/log-manager'], [ 'read' ]));
ok(__OBJECT__ -> grant([actor => 1], [actor => 2], [xsm => '/home/1/std/log-manager'], {read => 1}));
ok(__OBJECT__ -> has_attribute([actor => 2], [xsm => '/home/1/std/log-manager'], [ 'read' ]));

=end testing

=cut

sub grant {
    my($self, $granter, $user, $path, $attributes) = @_;

    if($self -> can_grant($granter, $user, $path, $attributes)) {
        $self -> set_point_attributes($user, $path, $attributes, $granter);
        return 1;
    }
    else {
        return 0;
    }
}

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2003-2004 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;

__END__
