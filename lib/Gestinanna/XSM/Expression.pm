package Gestinanna::XSM::Expression;

use Class::ISA;

%AXIS_HANDLERS = ( );

sub axis_self { $_[0] };

sub axis_child {
    my $class = ref $_[0];
    my $name  = $_[1];

    #warn "axis_child($class, $name)\n";
    if($class) {
        if($class eq 'ARRAY') {
            return @{$_[0]} if $name eq '*';
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

sub axis_child_or_self { ( $_[0], axis_child(@_) ) }

sub axis_descendent {
    my @keepers;

    my @stack = $_[0];
    my $c;

    #warn "axis_descendent($_[0], $_[1])\n";
    while(@stack) {
        $c = shift @stack;
        push @stack, axis_child($c, '*');
        push @keepers, axis_child($c, $_[1]);
    }

    return @keepers;
}

sub axis_descendent_or_self { ( $_[0], axis_descendent(@_) ) }

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
                $root -> {$bit} ||= { };
                $root = $root -> {$bit}
            }
            elsif(UNIVERSAL::isa($root, 'ARRAY')) {
                $root -> [$bit] ||= { };
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
    elsif($root eq 'ARRAY') {
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
    return @$a <=> @$b;  # for now
}

sub xsm_range {
    my($a, $b) = @_[0,1];

    if($a <= $b) {
        return $a .. $b;
    }
    else {
        return reverse $b .. $a;
    }
}

1;

