package Gestinanna::XSM::Expression;

use Class::ISA;

=head1 NAME

Gestinanna::XSM::Expression - utilities for XSM expressions

=head1 SYNOPSIS

 $root = axis_self($root);
 @children = axis_child($root, $selector);
 @child_or_self = axis_child_or_self($root, $selector);
 @descendents = axis_descendent($root, $selector);

=head1 DESCRIPTION

These utility functions are used in compiled XSM expressions to handle 
the various axes as well as miscellanous things such as comparisons.

=head1 FUNCTIONS

=cut

%AXIS_HANDLERS = ( );

=head2 axis_self

 $root = axis_self($root, $selector);

Regardless of the selector, this will return to current position in 
the data structure pointed to by C<$root>.

=begin testing

# axis_self

ok(__PACKAGE__::axis_self('root') eq 'root');

=end testing

=cut

sub axis_self { $_[0] };

=head2 axis_child

 @children = axis_child($root, $selector);

Returns any immediate children of C<$root> which match the selector.  
If the root is an array, then the selector is expected to be numeric. 
If the root is a hash, then it is expected to be a string corresponding 
to a key within the hash.  If the root is an object, then the selector 
is expected to be the name of a method.  If the selector is C<*>, then 
all children are returned if the root is not an object.

=begin testing

# axis_child

is_deeply([__PACKAGE__::axis_child([ qw(1 2 3 4) ], 2)], [ 3 ]);
is_deeply([__PACKAGE__::axis_child({ foo => 'bar', baz => 'foo' }, 'baz')], ['foo']);

is_deeply([ __PACKAGE__::axis_child([qw(1 2 3 4)], '*') ], [qw(1 2 3 4)]);
ok(eq_set([ __PACKAGE__::axis_child({ foo => 'bar', baz => 'foo' }, '*') ], [qw(bar foo)]));

use File::Spec;
my $foo = bless { } => File::Spec;

is_deeply([__PACKAGE__::axis_child($foo, 'curdir')], [File::Spec -> curdir]);

my $root = { foo => { bar => 'foo' } };

is_deeply([ __PACKAGE__::axis_child($root, 'foo') ], [ $root->{'foo'} ]);

is_deeply([ __PACKAGE__::axis_child({ baz => 'buzz' }, 'baz') ], [ 'buzz' ]);

=end testing

=cut

sub axis_child {
    my $class = ref $_[0];
    my $name  = $_[1];

    if($class) {
        if($class eq 'ARRAY') {
            return @{$_[0]} if $name eq '*';
            return unless $name =~ m{^\s*\d+\s*$};
            return $_[0] -> [$name];
        }
        if($class eq 'HASH') {
            return values %{$_[0]} if $name eq '*';
            return $_[0] -> {$name};
        }
        if($AXIS_HANDLERS{$class}) {
            return $AXIS_HANDLERS{$class} -> axis_child(@_);
        }
        my @ret;
        my $method = $_[1];
        $method =~ tr[-][_];
        eval {@ret = $_[0] -> $method};
        return @ret unless $@;
        $method = "get_$method";
        eval {@ret = $_[0] -> $method};
        return @ret unless $@;
        #my $code = eval { $_[0] -> can($_[1]) } 
                #|| eval { $_[0] -> can('get_' . $_[1]) } 
                #|| UNIVERSAL::can($_[0], $_[1])
                #;
        #return $code -> (@_) if $code;
    }
    return; # no ref or no handler, no children
}

=head2 axis_child_or_self

 @children_or_self = axis_child_or_self($root, $selector);

This returns the same results as C<axis_child> except that the first 
element in the returned list is the root.

=begin testing

# axis_child_or_self

is_deeply([ __PACKAGE__::axis_child_or_self([qw(1 2 3)], '*') ], [ [qw(1 2 3)], qw(1 2 3) ]);

my $root = { foo => { bar => 'foo' } };
is_deeply([ __PACKAGE__::axis_child_or_self($root, 'foo') ],
          [ $root, $root -> {'foo'} ]);

=end testing

=cut

sub axis_child_or_self { ( $_[0], axis_child(@_) ) }

=head2 axis_descendent

=begin testing

# axis_descendent

is_deeply([ __PACKAGE__::axis_descendent({ foo => 'bar' }, 'foo') ], [ 'bar' ]);

is_deeply([ __PACKAGE__::axis_descendent({ foo => { bar => 'baz' } }, 'bar') ], [ 'baz' ]);

is_deeply([ __PACKAGE__::axis_descendent({ foo => { bar => { baz => 'buzz' } } }, 'baz')], [ 'buzz' ]);

ok(eq_set([ __PACKAGE__::axis_descendent({ foo => { bar => [ { baz => 'buzz' }, { baz => 'ing' } ] } }, 'baz') ],
          [ qw(buzz ing) ]));

my $fs = bless { } => File::Spec;

ok(eq_set([ __PACKAGE__::axis_descendent({ foo => { curdir => 'curdir', bar => $fs } }, 'curdir') ], ['curdir', $fs -> curdir ]));

=end testing

=cut

sub axis_descendent {
    my @keepers;

    my @stack = $_[0];
    my $c;

    while(@stack) {
        $c = shift @stack;
        push @stack, axis_child($c, '*');
        push @keepers, axis_child($c, $_[1]);
    }

    return grep { defined } @keepers;
}

=head2 axis_descendent_or_self

=begin testing

# axis_descendent_or_self

my $root = { foo => { bar => { baz => 'buzz' } } };
is_deeply([ __PACKAGE__::axis_descendent_or_self($root, 'baz')], [ $root, 'buzz' ]);

=end testing

=cut

sub axis_descendent_or_self { ( $_[0], axis_descendent(@_) ) }

=head2 axis_method

=begin testing

# axis_method

is(__PACKAGE__::axis_method('File::Spec', 'curdir'), File::Spec -> curdir);

is_deeply([ __PACKAGE__::axis_method('File::Spec', 'curdir') ], [ File::Spec -> curdir ]);

=end testing

=cut

sub axis_method { # do we want to consider allowing arguments for these? >:)
    my $code;
    #warn "axis_method(" . join(", ", @_) . ")\n";
    my $object = shift;
    my $method = shift;
    $method =~ tr[-][_];
    my(@ret, $ret);
    if(defined wantarray) {
        if(wantarray) {
            eval { @ret = $object -> $method(@_); };
            return @ret unless $@;
        }
        else {
            eval { $ret = $object -> $method(@_); };
            return $ret unless $@;
        }
    }
    else {
        eval { $object -> $method(@_); };
        return unless $@;
    }
    $code = eval { $object -> can($method) } || UNIVERSAL::can($object, $method);
    return unless $code;
    if(defined wantarray) {
        if(wantarray) {
            eval { @ret = $code -> ($object, @_); };
            return @ret unless $@;
        }
        else {
            eval { $ret = $code -> ($object, @_); };
            return $ret unless $@;
        }
    }
    else {
        eval { $code -> ($object, @_); };
        return unless $@;
    }
    return ;
}

=head2 axis_attribute

=begin testing

# axis_attribute

is_deeply( [ __PACKAGE__::axis_attribute('File::Spec', 'isa') ], [ Class::ISA::self_and_super_path('File::Spec') ] );

is_deeply( [ __PACKAGE__::axis_attribute('File::Spec', 'version') ], [ File::Spec -> VERSION ] );

sub My::Testing::Dummy::s { };

is_deeply( [ sort { $a cmp $b } __PACKAGE__::axis_attribute('My::Testing::Dummy', 'can') ] , [ sort { $a cmp $b } qw(s VERSION isa can import) ] );

=end testing

=cut

sub axis_attribute {
# @isa, @can, @version
    for($_[1]) {
        /^isa$/ and return Class::ISA::self_and_super_path($_[0]);
        /^can$/ and do {
            my @classes = Class::ISA::self_and_super_path($_[0]);
            my %methods;
            foreach my $class (@classes, 'UNIVERSAL') {
                my @methods = grep { $class -> can($_) } keys %{"${class}::"};
                @methods{@methods} = undef;
            }
            return keys %methods;
        }; # need to find all the methods available
        /^version$/ and return UNIVERSAL::VERSION($_[0]); # may want to work on this
    }
    return;
}

=head2 set_element

=begin testing

# set_element

my $root = { };

__PACKAGE__::set_element($root, [qw( foo )], 'bar');

is($root -> {foo}, 'bar');

__PACKAGE__::set_element($root, [qw( baz 2 )], 'boo');

isa_ok($root -> {baz}, 'ARRAY');

is($root -> {baz} -> [2], 'boo');

=end testing

=cut

sub set_element {
    my $root = shift;
    my @bits = grep { defined } @{shift || []};

    my $bit = shift @bits;

    foreach my $next_bit (@bits) {
        #warn "Looking at $bit\n";
        my @p = grep { defined } Gestinanna::XSM::Expression::axis_child($root, $bit);
        if(@p) {
            $root = $p[0];
        }
        else {
            if(UNIVERSAL::isa($root, 'HASH')) {
                $root -> {$bit} ||= (($next_bit =~ m{^\s*\d+\s*$}) ? [] : { });
                $root = $root -> {$bit}
            }
            elsif(UNIVERSAL::isa($root, 'ARRAY')) {
                $root -> [$bit] ||= { };
                $root -> [$bit] ||= (($next_bit =~ m{^\s*\d+\s*$}) ? [] : { });
                $root = $root -> [$bit]
            }
        }
        $bit = $next_bit;
    }

    #warn "Setting [$bit]\n";
    #warn "value: " . join("; ", @_) . "\n";

    #$root should now have the thing we need to set
    if(ref $root eq 'HASH') {
        $root -> {$bit} = (@_ > 1 ? [ @_ ] : $_[0]);
    }
    elsif(ref $root eq 'ARRAY') {
        $root -> [$bit] = (@_ > 1 ? [ @_ ] : $_[0]);
    }
    elsif(ref $root) {
        my $method = $bit;
        $method =~ tr[-][_];
        #warn "Trying method $method\n";
        eval {@ret = $root -> $method(@_)};
        return @ret unless $@;
        $method = "set_$method";
        #warn "Trying method $method\n";
        eval {@ret = $root -> $method(@_)};
        return @ret unless $@;
    }
}

=head2 xsm_cmp

=begin testing

# xsm_cmp

is(__PACKAGE__::xsm_cmp([10], [10]), 0);
is(__PACKAGE__::xsm_cmp([10], [12]), 10 <=> 12);
is(__PACKAGE__::xsm_cmp([12], [10]), 12 <=> 10);
is(__PACKAGE__::xsm_cmp(['a'],[10]), -1);
is(__PACKAGE__::xsm_cmp([10], ['a']), 1);
is(__PACKAGE__::xsm_cmp(['a'], ['b']), 'a' cmp 'b');
is(__PACKAGE__::xsm_cmp([qw(a b c)], ['a']), 0);
is(__PACKAGE__::xsm_cmp([qw(a b c)], ['d']), 3 <=> 1);
is(__PACKAGE__::xsm_cmp(['a'], [qw(a b c)]), 0);
is(__PACKAGE__::xsm_cmp(['d'], [qw(a b c)]), 1 <=> 3);

=end testing

=cut

sub xsm_cmp {
    my($a, $b) = @_[0,1];

    if(@$a == 1 && @$b == 1) {
        $a = $a->[0]; $b = $b -> [0];
        if($a !~ m{^\s*([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\s*$}) {
            return $a cmp $b if $b !~ m{^\s*([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\s*$};
            return -1;
        }
        return 1 if $b !~ m{^\s*([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\s*$};
        return $a <=> $b;
    }
    if(@$b == 1) {
        # see if @$a contains $b->[0]
        xsm_cmp([ $_ ], $b) || return 0 for @$a; # useful for attributes -- @isa = 'class'
    }
    elsif(@$a == 1) {
        # see if @$b contains $a->[0]
        xsm_cmp($a, [ $_ ]) || return 0 for @$b;
    }
    return @$a <=> @$b;  # for now
}

=head2 xsm_range

=begin testing

# xsm_range

is_deeply([ __PACKAGE__::xsm_range(0, 10) ], [ 0 .. 10 ]);
is_deeply([ __PACKAGE__::xsm_range(10, 0) ], [ reverse 0 .. 10 ]);

=end testing

=cut

sub xsm_range {
    my($a, $b) = @_[0,1];

    return $a .. $b if $a <= $b;
    return reverse $b .. $a;
}

1;

