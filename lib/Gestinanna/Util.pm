package Gestinanna::Util;

use Carp;
use Exporter;
use strict;

=head1 NAME

Gestinanna::Util - utility functions

=head1 SYNOPSIS

 use Gestinanna::Util qw(:path);

 my $regex = path2regex($path)
 my $cmp   = path_cmp($path_a, $path_b);

 use Gestinanna::Util qw(:hash);

 my $new_hash = deep_merge_hash(@hashes);

=cut

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
    path2regex
    path_cmp 
    deep_merge_hash
);

our %EXPORT_TAGS = (
    'path' => [qw(path_cmp path2regex)],
    'hash' => [qw(deep_merge_hash)],
);

=head1 DESCRIPTION

This module provides utility functions that have no better place to be.  
Sets of utility functions may be imported by specifying their tags.

=over 4

=item :path

Imports: path2regex, path_cmp

=back

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

=head2 path2regex

This method will translate a path to a regular expression.  The 
C<path_cmp> method uses this for certain comparisons.

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

=begin testing

# path2regex

my %paths = (
    '/' => q{\/},
    '/this' => q{\/this},
    '/*' => q{\/([^\/\@\|\&]+)},
    '//*' => q{\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+)},
    '//*@*' => q{\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+)\@([^\/\@\|\&]+)},
    '//*@name' => q{\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+)\@name},
    '//* & //name' => q{(?(?=\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*([^\/\@\|\&]+))(?:\/+(?:([^\/\@\|\&]+)\/+)*(?:\/)*name))},
);

foreach my $path (sort keys %paths) {
    is(__PACKAGE__::path2regex($path), $paths{$path}, "path2regex($path)");
}

is(__PACKAGE__::path2regex('//*'), $paths{'//*'}, "Cached path2regex(//*)");

=end testing

=cut

my $component = q{([^\/\@\|\&]+)};

sub path2regex ($) {
    my $path = shift;

    my @bits;
    foreach my $bit (split(/\s*\|\s*/, $path)) {
        my @xbits = split(/\s*\&\s*/, $bit);

        my $t;
        foreach (reverse @xbits) {
            $_ = "\Q$_\E";
            s{^(?:\\!\\!)+(.*)$}{$1};
            s{^\\!(?:\\!\\!)*(.*)$}{(?:(?!$1)|(?:!$1))};
            s{\\/(\\/)+}{\\\/+(?:$component\\\/+)*(?:\\\/)*}g;
            s{\\\*}{$component}g;
            s{\\/}{\\\/}g;
            unless(defined $t) {
                $t = $_;
            }
            else {
                $t = "(?(?=$_)(?:$t))"; # hint: regex equiv of ?:
            }
        }
        push @bits, $t;
    }

    my $tpath = join(")|(?:", @bits);
        
    $tpath = qq{(?:$tpath)} if @bits > 1;

    return $tpath;
}

my $is_regex = qr{^!|//+|\*|\||\&};

=head2 path_cmp

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

=begin testing

# path_cmp

my @paths = (
    [ qw(a a), 1 ],
    [ qw(/this /that), undef ],
    [ qw(/this /that), undef ],
    [ '', '', 1 ],
    [ qw(/this /*), -1 ],
    [ qw(/* /this),  1 ],
    [ q(//foo | //bar), q(//foo | //baz), 0 ],
    [ qw(//*@* //*@name),  1 ],
    [ qw(//*@* //*@name),  1 ],
    [ qw(//*@name //*@*), -1 ],
    [ qw(//foo //bar), undef ],
    [ qw(/foo/bar/baz //bar), undef ],
    [ qw(/foo/bag //bar), undef ],
    [ qw(//bar /foo/bag), undef ],
    [ '/this | /that', '', 1 ],
    [ '', '/this | /that', -1 ],
    [ '/this', '/this | /that', -1 ],
    [ '//bar//* & //foo//*', '/baz/foo/bar/fob', 1],
);

foreach my $path (@paths) {
    is(__PACKAGE__::path_cmp($path->[0], $path->[1]), $path->[2], "__PACKAGE__::path_cmp($$path[0], $$path[1])");
}

=end testing

=cut

sub path_cmp ($$) {
    my($a, $b) = @_;

    return 1 if $a eq $b;
    return -1 if $a eq '';
    return 1 if $b eq '';

    if( $a !~ m{\s*\|\s*} 
        and $b !~ m{\s*\|\s*} 
        and $a !~ m{$is_regex} || $b !~ m{$is_regex} 
    ) {
        if($a !~ m{$is_regex}) {
            return undef if $b !~ m{$is_regex};

            my $bb = path2regex($b);
    
            return -1 if $a =~ m{^${bb}$};

            return undef;
        }
        else {
            my $aa = path2regex($a);

            return 1 if $b =~ m{^$aa$};

            return undef;
        }
    }
    else {
        my %abits = map { $_ => undef } split(/\s*\|\s*/, $a);
        my %bbits = map { $_ => undef } split(/\s*\|\s*/, $b);
        my $alla = scalar keys %abits;
        my $allb = scalar keys %bbits;

        my $aa = path2regex($a);
        my $bb = path2regex($b);
        $aa = qr{^$aa$};
        $bb = qr{^$bb$};

        # if a =~ B, then a <= B
        foreach my $p (keys %abits) {
            $abits{$p} = $p =~ m{$bb};
        }
        foreach my $p (keys %bbits) {
            $bbits{$p} = $p =~ m{$aa};
        }

        my $numa = scalar(grep { $_ } values %abits);
        my $numb = scalar(grep { $_ } values %bbits);

        return undef if $numa == 0 && $numb == 0; # disjoint
        return 1 if $numb == $allb;  # A <= B
        return -1 if $numa == $alla;  # B < A
        return 0;    # overlap
    }
}

=begin testing

# deep_merge_hash

is_deeply(__PACKAGE__::deep_merge_hash(
    { foo => 2, bar => 3 }, { baz => 5 }
), { foo => 2, bar => 3, baz => 5 });

is_deeply(__PACKAGE__::deep_merge_hash(
    { foo => [ 1, 2 ] }, { foo => [ 3, 4 ] }
), { foo => [1, 2, 3, 4] });

is_deeply(__PACKAGE__::deep_merge_hash(
    { foo => 2, bar => [ { baz => 2 }, [ 3, 4 ] ] },
    { fud => 5, bar => [ 5, [ 6, 7] ] }
), {
    foo => 2,
    bar => [ { baz => 2 }, [ 3, 4 ], 5, [6, 7] ],
    fud => 5
});

is_deeply(__PACKAGE__::deep_merge_hash(
    { foo => undef, bar => 2 }
), { bar => 2 });

is_deeply(__PACKAGE__::deep_merge_hash(
    { foo => { bar => 3 } }, { foo => { baz => 4 } },
), { foo => { bar => 3, baz => 4 } });

is_deeply(__PACKAGE__::deep_merge_hash(
    { foo => 1, bar => [ ] }
), { foo => 1 });

=end testing

=cut

sub deep_merge_hash {
    my(@hashes) = @_;

    my %hash = map { $_ => 1 } (map { keys %$_ } @hashes);
    my @keys = keys %hash;

    my $ret = { };

    foreach my $k (@keys) {
        my @items = grep { defined } ( map { $_->{$k} } @hashes );
        next unless @items;
        if(UNIVERSAL::isa($items[0], 'HASH')) {
            $ret->{$k} = deep_merge_hash(@items);
        }
        else {
            $ret->{$k} = [
                map { UNIVERSAL::isa($_, 'ARRAY') ? @$_ : $_ } @items
            ];
            if(@{$ret->{$k}} == 1) {
                $ret->{$k} = $ret->{$k}->[0];
            }
            elsif(@{$ret->{$k}} == 0) {
                delete $ret->{$k};
            }                  
        }
    }

    return $ret;
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

