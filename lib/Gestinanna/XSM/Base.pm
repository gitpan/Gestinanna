# the ::CC package avoids a couple of greps and ->can() on @ISA
package Gestinanna::XSM::Base::CC;

use strict;
no strict 'refs';
use vars qw(@ISA $DEBUG);

@ISA = qw(Class::Container);

sub _generate_states { }

sub _transit_hasa { }

#$DEBUG = 1;

sub _DEBUG {
    return unless $DEBUG;
    warn @_;
}

sub can {
    my($self) = shift;

    return $self -> SUPER::can(@_) if @_ != 2;
}

sub filename { return; }

sub get_super_path { return (); }

package Gestinanna::XSM::Base;
    
use Data::FormValidator ();
use Data::Dumper;  # here for testing/development - comment out for release
use Gestinanna::Util qw(:hash);
use Storable ();
use Class::Container;
use Params::Validate qw(:types);
use Gestinanna::Request;
use Apache::Log;

use strict;
no strict 'refs';
use vars qw(@ISA $VERSION $REVISION $DEBUG);
    
@ISA = qw(Gestinanna::XSM::Base::CC);
    
__PACKAGE__ -> valid_params(
    context => { type => SCALAR, default => Storable::nfreeze({}), optional => 1 },
    _factory => { isa => 'Gestinanna::POF', optional => 1 },
);  
    
$VERSION = '0.06';
        
{ no warnings;
$REVISION = sprintf("%d.%d", q$Id: Base.pm,v 1.4 2004/06/25 08:02:22 jgsmith Exp $ =~ m{(\d+).(\d+)});
}
    
#$DEBUG = 1;
        
sub _DEBUG {
    return unless $DEBUG;
    warn @_;
}

=begin testing

# log

__OBJECT__ -> __METHOD__(debug => 'debug');

is(__OBJECT__ -> __METHOD__, 'debug');

=end testing

=cut

sub log {
    my $self = shift;

    #warn "$self -> log(" . join(",", @_) . ")\n";

    return join("\n", @{$self -> {debug_log} || []})  unless @_;

    my $level = shift;

    if($level eq 'debug') {
        push @{$self -> {debug_log} ||= []}, @_;
    }
    #warn "@_\n";
    if(Gestinanna::Request -> in_mod_perl) {
        Apache -> request -> log -> $level(@_);
    }
}

=begin testing

# filename

$My::XSM::Test::FILENAME = $My::XSM::Test::FILENAME = 'filename';

@My::XSM::Test::ISA = qw(__PACKAGE__);

is(__PACKAGE__::__METHOD__('My::XSM::Test'), 'filename');

my $o = bless { } => 'My::XSM::Test';

is($o -> __METHOD__, 'filename');

=end testing

=cut

sub filename {
    no strict 'refs';

    my $class = ref $_[0] || $_[0];

    return ${"${class}::FILENAME"};
}
        
=begin testing

# can

=end testing

=cut

sub can {
    my($self) = shift;

    return $self -> SUPER::can(@_) if @_ != 2;

    # we want to find the code that should be run from state1 to state2
    my($ostate, $nstate) = @_;
    # we cache this in ${class}::CAN;
    my $class = ref $self || $self;

    #_DEBUG("Looking for ${ostate}:${nstate} in $class\n");
    $ostate = "" unless defined $ostate;
    $nstate = "" unless defined $nstate;
    my $code = ${"${class}::CAN"}{"${ostate}:${nstate}"};
    _DEBUG("Found code ($code) for ${ostate}:${nstate} in cache\n") if $code;
    return $code if $code && !$DEBUG;

    if($ostate) {
        if($code = $self -> can("${ostate}_to_${nstate}")) {
             _DEBUG("${ostate}_to_${nstate} is found in $class\n");
             ${"${class}::CAN"}{"${ostate}:${nstate}"} = $code;
             return $code;
        }
        else {
            _DEBUG("$ostate -> $nstate\n");
            my($prcode, $pocode) = ($self -> can("pre_${nstate}"), $self -> can("post_${ostate}"));
            $prcode = $self -> _can_hasa(undef, $nstate) unless $prcode;
            _DEBUG("$ostate -> $nstate\n");
            $pocode = $self -> _can_hasa($ostate, undef) unless $pocode;
            _DEBUG("$ostate -> $nstate\n");
            return $self -> _can_hasa($ostate, $nstate) unless $prcode || $pocode;
            _DEBUG("Found pre_${nstate} ($prcode) and post_${ostate} ($pocode) for $class\n");
            $code = _make_can_code($prcode, $pocode);
            ${"${class}::CAN"}{"${ostate}:${nstate}"} = $code;
            return $code;
        }
    }
    else {
        if($code = $self->can("pre_${nstate}")) {
            _DEBUG("Found pre_${nstate} for $class\n");
            ${"${class}::CAN"}{"${ostate}:${nstate}"} = $code;
            return $code;
        }
    }
            
    $code = $self -> _can_hasa($ostate, $nstate);
    ${"${class}::CAN"}{"${ostate}:${nstate}"} = $code;
    return $code;
}

=begin testing

# _make_can_code

my($a, $b) = (0, 0);

my $code = __PACKAGE__::__METHOD__(undef, undef);
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);

$code = __PACKAGE__::__METHOD__(sub { $a = 1 }, undef );
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok($a && !$b);

$a = $b = 0;

$code = __PACKAGE__::__METHOD__(sub { $a = 1 }, sub { $b = 1} );
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok($a && $b);

$a = $b = 0;

$code = __PACKAGE__::__METHOD__(sub { $b = 1} );
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok(!$a && $b);

my $i = 0;
my @t = ( 0, 0 );

$code = __PACKAGE__::__METHOD__(sub { $t[$i++] = 1; }, sub { $t[$i++] = 2; });
ok(UNIVERSAL::isa($code, 'CODE'));
eval { $code -> ( ); };
ok(!$@);
ok($t[0] == 2 && $t[1] == 1);

=end testing

=cut

sub _make_can_code {
    my($prcode, $pocode) = @_;

    return sub { $pocode->(@_) if $pocode; $prcode->(@_) if $prcode; };
}

=begin testing

# _can_hasa

@My::Had::XSM::ISA = qw(__PACKAGE__);
@My::Has::XSM::ISA = qw(__PACKAGE__);

=end testing

=cut

sub _can_hasa {
    my($self, $ostate, $nstate) = @_;

    my $class = ref $self || $self;
    #_DEBUG("_can_hasa($class, $ostate, $nstate)\n");
    my $code = 0;

    # looks like HASAs are expensive
    foreach my $p (@{"${class}::HASA_KEYS_SORTED"}) {
        _DEBUG("Looking at $class\n");
        next unless $nstate =~ m{^${p}_};
    
        bless $self => ${"${class}::HASA"}{$p};
   
        my($realoldstate, $realnewstate) = ($ostate, $nstate);
        $nstate =~ s{^${p}_}{};
        $ostate =~ s{^${p}_}{};
    
        $code = $self -> can($ostate, $nstate);
        bless $self => $class;
        return $class -> _make_hasa_can_code(${"${class}::HASA"}{$p}, $p, $code) if $code;
    }

    foreach my $c (@{"${class}::ISA"}) {
        bless $self => $c;
        $code = $self -> can($ostate, $nstate);
        bless $self => $class;
        return $code if $code;
    }
}

=begin testing

# _make_hasa_can_code

my $a = '';
my @args = ( );

my $code = __PACKAGE__ -> __METHOD__('My::Test::XSM', 'test', sub {
    my $self = shift;
    $a = ref $self;
    @args = @_;
});

ok(UNIVERSAL::isa($code, 'CODE'));

my $self = bless { } => __PACKAGE__;

$code -> ($self, qw(1 2 3));

is($a, 'My::Test::XSM');
is_deeply([@args], [qw(1 2 3)]);
is(ref $self, q(__PACKAGE__));

$code = __PACKAGE__ -> _make_hasa_can_code('My::Test::XSM', 'test', sub {
    die "Help!\n";
});

eval { $code -> ($self, qw(1 2 3)) };
ok($@ eq "Help!\n");

$code = __PACKAGE__ -> __METHOD__('My::Test::XSM', 'test', sub {
    throw StateMachine::Gestinanna::Exception(
        -state => 'ing',
        -data => [ @_[1 .. $#_] ],
    )
});

eval { $code -> ($self, qw(1 2 3)) };
my $e = $@;
ok(UNIVERSAL::isa($e, 'StateMachine::Gestinanna::Exception'));
is($e -> state, 'test_ing');
is_deeply($e -> data, [qw(1 2 3)]);

=end testing

=cut

sub _make_hasa_can_code {
    my($oldclass, $newclass,$p,$code) = @_;

    return sub {
        my $self = shift;
        bless $self => $newclass;
        my $ret;
        eval { $ret = $code -> ($self, @_); };
        bless $self => $oldclass;
        if($@) {
            die $@ unless ref $@;
            die $@ unless $@ -> isa('StateMachine::Gestinanna::Exception');
            throw StateMachine::Gestinanna::Exception (
                -state => $p . "_" . $@->state,
                -data => $@ -> data
            );
        }
        return $ret;
    };
}

=begin testing

# _transit

my($a, $b);

{ package My::__METHOD__::SM;
  our @ISA = qw(__PACKAGE__);

  sub pre_a { $a = 'pre' };
  sub post_a { $a = 'post' };
  sub pre_b { $b = 'pre' };
  sub post_b { $b = 'post' };
  sub a_to_b { $a = 'from'; $b = 'to' };
  sub b_to_a { $a = 'to'; $b = 'from' };
}

my $sm = My::__METHOD__::SM -> new;

$sm -> _transit(qw(a b));
ok($a eq 'from' && $b eq 'to');

$sm -> _transit(qw(b a));
ok($a eq 'to' && $b eq 'from');

$sm -> _transit(qw(a c));
ok($a eq 'post');

$sm -> _transit(qw(c a));
ok($a eq 'pre');

=end testing

=cut

# _transit() will try to go the new new $nstate but will throw an exception if unable to do so.
# $nstate - state we are going to
# $ostate - state we are going from
# $trans_func - transition code from $ostate to $nstate
# $pre_func - code to run on transition to $nstate
# $post_func - code to run on transition from $ostate
# $trans_func has precedence over ${pre|post}_func
sub _transit {
    my($self, $ostate, $nstate) = @_;

    my $code_run = 0;
    my $ret;

    if(defined $ostate) {
        $ret = $self -> $code_run() if $code_run = $self -> can($ostate, $nstate);
    }
    else {
        $ret = $self -> $code_run() if $code_run = $self -> can("pre_${nstate}");
    }

    return $ret;
}

=begin testing

# transit

=end testing

=cut

# transit() will try to go to the new $nstate, and will process any ErrorState transitions requested
# $nstate - state we are transitioning to
# we will transition until we have a successful transition or $nstate 
# is undefined (in which case we should remain in our original state)
sub transit {
    my($self, $nstate) = @_;

    #_DEBUG("transit($self, $nstate)\n");
    my $ostate = $self -> state;
    $nstate = '' unless defined $nstate;
    $ostate = '' unless defined $ostate;
    #_DEBUG("Transit: $ostate -> $nstate\n");
    return if $ostate eq $nstate;
    my $ret;
    while(defined $nstate) {
        $ret = undef;
        eval { 
#            _DEBUG("Transit: $ostate -> $nstate\n");
            $ret = $self -> _transit($ostate, $nstate);
            #_DEBUG("Transition returns [$ret]\n");
            $self -> state($nstate) unless $ret;
        };
        my $e = $@;
        if($e && UNIVERSAL::isa($e, 'Gestinanna::XSM::Op')) {
            $nstate = $self -> alias_state($nstate);
            $self -> state($nstate) if defined $nstate;
            $e -> throw;
        }
        elsif($e) {
             # need to define which state/view to use if there's an error
            last unless $e;
            die $e unless ref $e;
            die $e unless $e->isa('StateMachine::Gestinanna::Exception');
            $ostate = $self -> state;
            $nstate = $e -> state;
            $self -> {context} -> {data} -> {error} = $e -> data;
        }
        elsif($ret) {
            _DEBUG("Using \$ret to define next state\n");
            $ostate = $nstate; #$self -> state;
            $nstate = $ret;
        }
        else {
            $nstate = undef;
        }
        # check aliases
        $nstate = $self -> alias_state($nstate) if defined $nstate;
    }
}

# undef == state doesn't exist
# 0 == state exists but no transitions
# 1 == state exists and has transitions
sub is_not_terminal_state {
    my($self, $state) = @_;

    my $package = ref($self) || $self;
    no strict 'refs';
    #warn "package: $package\n";

    #warn Data::Dumper -> Dump([\%{"${package}::EDGES_CACHE"}]), "\n";

    return unless exists ${"${package}::EDGES_CACHE"}{$state};
    my @states = keys %{ ${"${package}::EDGES_CACHE"}{$state}{'profile'} || {} };
    #warn "Found ", scalar(@states), " states to transition to\n";
    return 0 != scalar(keys %{ ${"${package}::EDGES_CACHE"}{$state}{'profile'} || {}});
}

=begin testing

# alias_state

%My::Test::XSM::ALIASES = %My::Test::XSM::ALIASES = (
   '_begin' => 'start',
);
@My::Test::XSM::ISA = @My::Test::XSM::ISA = qw(__PACKAGE__);

is(__PACKAGE__::__METHOD__('My::Test::XSM', '_begin'), 'start');
is(__PACKAGE__::__METHOD__('My::Test::XSM', '_end'), '_end');

my $self = bless { } => 'My::Test::XSM';

is($self -> __METHOD__('_begin'), 'start');
is($self -> __METHOD__('_end'), '_end');

is(__PACKAGE__::alias_state(undef, ''), undef);

=end testing

=cut

sub alias_state {
    my($self, $state) = @_;

    return unless defined $self;
    my $package = $self;
    $package = ref $self if ref $self;
    #warn "aliases: $package - $state\n";
    return ${"${package}::ALIASES"}{$state} if exists ${"${package}::ALIASES"}{$state};
    return $state;
}

=begin testing

# state

my $self = bless { } => 'My::Test::XSM';

$self -> __METHOD__('_begin');
is($self -> __METHOD__, 'start');

my $old = $self -> __METHOD__('_end');
is($old, 'start');

is($self -> __METHOD__, '_end');

=end testing

=cut

# get/set the current state -- no transition is implied
sub state { 
    my $self = shift;
    return $self -> {context} -> {state} unless @_; 
    #warn "setting state to $_[0] : ", $self -> alias_state($_[0]), "\n";
    my $prev = $self -> {context} -> {state};
    $self -> {context} -> {state} = $self -> alias_state(shift);
    return $prev;
    return( (
        ($self -> {context} -> {state}),
        ($self -> {context} -> {state} = $self -> alias_state(shift)),
    )[0]);
}

sub view {
    my $self = shift;

    my $state = $self -> state;
    my $package = ref($self) || $self;
    return ${"${package}::VIEWS_CACHE"}{$state} if exists ${"${package}::VIEWS"}{$state};
    return $state;
}

=begin testing

# data

{ package My::__METHOD__::SM;
  our @ISA = qw(__PACKAGE__);
}

my $sm = My::__METHOD__::SM -> new;

$sm -> add_data('in', { foo => 'bar' } );
$sm -> add_data('in.baz', { bar => 'foo' } );
$sm -> add_data('in.baz.foo', { bar => 2 } );

is_deeply($sm -> __METHOD__('in'), {
    foo => 'bar',
    baz => {
      bar => 'foo',
      foo => { bar => 2 },
    },
});

is_deeply($sm -> __METHOD__('in.baz'), {
    bar => 'foo',
    foo => { bar => 2 },
});

=end testing

=cut

sub data {
    my($self, $root) = @_;

    return $self -> {context} -> {data} ||= { } unless defined $root;

    my @bits = split(/\./, $root);
    my $t = $self -> {context} -> {data};
    #warn "top: $t\n";
    while(@bits) {
        my $b = shift @bits;
        $t -> {$b} = { } unless exists $t->{$b};
        $t = $t -> {$b};
        #warn "  $b: $t\n";
    }
    return $t;
}

=begin testing

# clear_data

{ package My::__METHOD__::SM;
  our @ISA = qw(__PACKAGE__);
}

my $sm = My::__METHOD__::SM -> new;

$sm -> clear_data;

is_deeply($sm -> {context} -> {data}, {
    in => { }, out => { },
});

=end testing

=cut

# clear data made available to the transition code
sub clear_data {
    my($self, $root) = @_;

    #warn "clear_data($self, $root) called from " . join("; ", caller) . "\n";

    $root = '' unless defined $root;
    my @bits = split(/\./, $root);
    if(@bits > 1) {
        my $t = $self -> {context} -> {data};
        while(@bits > 1) {
            my $b = shift @bits;
            $t -> {$b} = { } unless exists $t->{$b};
            $t = $t -> {$b};
        }
        $t->{$bits[0]} = { };
    }
    elsif(@bits == 1) {
        $self -> {context} -> {data} -> {$bits[0]} = { };
    }
    else {
        $self -> {context} -> {data} = { 
            in => { },
            out => { },
        };
    }
}

=begin testing

# add_data

{ package My::__METHOD__::SM;
  our @ISA = qw(__PACKAGE__);
}

my $sm = My::__METHOD__::SM -> new;

$sm -> clear_data;

$sm -> add_data('in', {
    foo => 'bar'
});

is($sm -> {context} -> {data} -> {in} -> {foo}, 'bar');

$sm -> add_data('in.baz', {
    foo => 'bar'
});

is($sm -> {context} -> {data} -> {in} -> {baz} -> {foo}, 'bar');

=end testing

=cut

# add the data to the context under the specified root
# $prefix - root in the data tree
# $args - data to be added
sub add_data {
    my($self, $prefix, $args) = @_;

    return unless UNIVERSAL::isa($args, 'HASH');
    my $base = $self -> {context} -> {data} ||= { };
    if($prefix) {
        my @bits = split(/\./, $prefix);
        foreach my $b (@bits) {
            if(exists $base->{$b}) {
                unless(UNIVERSAL::isa($base->{$b}, "HASH")) {
                    $base->{$b} = {
                        value => $base->{$b},
                    };
                }
            }
            else {
                $base->{$b} = { };
            }
            $base = $base -> {$b};
        }
    }
  
    my $hash;
    foreach my $k (sort keys %$args) {
        my @bits = split /\./, $k;
        $hash = $base;
        my $b;  
        while(@bits > 1) {
            $b = shift @bits;
            if(exists $hash->{$b}) {
                unless(UNIVERSAL::isa($hash->{$b}, "HASH")) {
                    $hash->{$b} = {
                        value => $hash->{$b},
                    };
                }
            }
            else {
                $hash->{$b} = { };
            }
            $hash = $hash->{$b};
        }
        $hash -> {$bits[0]} = $$args{$k};
    }
}

sub transitioned { $_[0] -> {_transitioned} };

sub process {
    my($self, $args) = @_;

    #warn "Args: ", Data::Dumper -> Dump([$args]);
    delete @$args{grep { !defined($$args{$_}) || $$args{$_} eq '' }
                       keys %$args};

    $self -> clear_data('in');
    $self -> clear_data('messages');
    $self -> {_transitioned} = 0;

    _DEBUG("$self -> process($args)\n$args: ", Data::Dumper -> Dump([$args]), "\n");
    $self -> add_data('in', $args);


    my $best = $self -> select_state;
    #warn "Best: ", Data::Dumper -> Dump([$best]);

    $self -> add_data('messages', $best -> {messages});
    $self -> add_data('out', $best -> {valid});
    if($best -> {num_missing} || $best -> {num_invalid}) {
        $self -> add_data('missing', { map { ( $_ => 1 ) } @{$best -> {missing}||[]} });
        $self -> add_data('invalid', $best -> {invalid});
    }
    else {
        $self -> transit($best -> {state});
        $self -> {_transitioned} = 1;
    }
}

=begin testing

# _flatten_hash

is_deeply(__PACKAGE__::__METHOD__({
   foo => 2, bar => 3
}), { foo => 2, bar => 3 });

is_deeply(__PACKAGE__::__METHOD__({
    foo => { baz => 2 }, bar => 3, fud => { food => { flood => 5 }, flaunt => 6 }
}), { qw(
    foo.baz 2
    bar     3
    fud.food.flood  5
    fud.flaunt      6
)});

=end testing

=cut

sub _flatten_hash {
    local($_);
    my $a = shift;

    my %h;

    foreach my $k (keys %$a) {
        if(UNIVERSAL::isa($a->{$k}, "HASH")) {
            my $i = _flatten_hash($a -> {$k});
            my $l;
            $h{"${k}.${_}"} = $i->{$_}
                for keys %$i;
        }
        else {
            $h{$k} = $a->{$k};
        }
    }
    return \%h;
}

=begin testing

# get_super_path

%My::get_super_path::Test::EDGES_CACHE = %My::get_super_path::Test::EDGES_CACHE = (
    test_state => { super_path => [ qw(1 2 3) ] },
);

ok(eq_set([__PACKAGE__::__METHOD__('My::get_super_path::Test', 'test_state')], [qw(1 2 3)]));

=end testing

=cut

sub get_super_path {
    my($self, $state) = @_;

    #warn "Looking for the super_path for $state in $self\n";
    return () unless defined $state;

    my $class = ref $self || $self;
    #warn "Edges Cache: " . Data::Dumper -> Dump([${"${class}::EDGES_CACHE"}]);
    return @{${"${class}::EDGES_CACHE"}{$state}{super_path} || []};
}

=begin testing

# select_state

=end testing

=cut

# TODO: investigate using AI::DecisionTree to rank potential transitions for testing
sub select_state {
    my $self = shift;

    # $self is the context object
    # ${"${class}::VALIDATORS"}{$self -> state} is the validator to use

    my $args = _flatten_hash($self->data('in'));

    my $na = scalar(keys %$args)+1;
    my $best = { score => -1, state => $self->state }; # , num_missing => scalar(keys %$args), };

    $self -> {context} -> {best} = \%{ $best };

    return $best unless $na > 1;
    
    my $class = ref $self || $self;
    my $validator = ${"${class}::VALIDATORS"}{$self -> state};

    return $best unless $validator;

     my $cache = ${"${class}::EDGES_CACHE"}{$self -> state};
    _DEBUG("cache for $class - ", $self -> state, ": ", Data::Dumper -> Dump([$cache]), "\n");
    my @states = keys %{$cache -> {profile}};
    return $best unless @states;

    my $na2 = $na*$na;
    my $bestscore = $na * $na2;

    #warn "Best score: $bestscore\n";

    foreach my $v (@states) {
        _DEBUG("$validator -> validate(..., $v); ... => \n", Data::Dumper->Dump([{ %$args, %{ $cache->{overrides}->{$v} || {}}}]), "\n");
        my($valid, $missing, $invalid, $unknown) = ({ }, [ ], { }, { });
        my $results;
        eval {
            #($valid, $missing, $invalid, $unknown) = 
            $results = $validator->check({ %$args, %{ $cache->{overrides}->{$v} || {}}}, $v); 
        };
        if($@) {
            warn "$@\n";
            next;
        }

        _DEBUG("Validator: ", Data::Dumper -> Dump([$validator]), "\n");
                
        my($nv, $nm, $ni, $nu) = (0) x 4;

        $nv = scalar keys %{$valid = $results -> valid };

        $nm = scalar(@{$missing = $results -> missing })
            if $results -> has_missing;

        $ni = scalar keys %{$invalid = $results -> invalid}
            if $results -> has_invalid;

        $nu = scalar keys %{$unknown = $results -> unknown}
            if $results -> has_unknown;

        my $score = ($nv+1) * $na2;
        $score /= ($nm+1);
        $score /= ($ni+1);
        $score /= ($nu+1);

        #warn "$v scores $score\n";
        #warn "$v: missing $nm  invalid $ni  unknown $nu  valid $nv\n";
        #warn "missing: ", join(", ", @$missing), "\n";
        #warn "best score: $$best{score} ; best missing: $$best{num_missing}\n";
        if($best->{score} == -1 
           || ($score >= $best->{score} 
               && (!(defined($nm) 
                     && defined($best -> {num_missing})
                    ) 
                  || $nm <= $best -> {num_missing}
                  )
              )
          ) {
            if($ni) {
                #$best -> {invalid} = $invalid;
            }
            else {
                
                $best = { 
                    score => $score,
                    valid => $valid,
                    missing => $missing,
                    invalid => $invalid,
                    unknown => $unknown,
                    messages => $results -> msgs,
                    state => $v,
                    num_missing => $nm,
                    num_invalid => $ni,
                    num_valid => $nv,
                    num_unknown => $nu,
                };
            }
            last if $score >= $bestscore;
        }
    }

    $self -> {context} -> {best} = {
        missing => $best -> {missing},
        invalid => $best -> {invalid},
        unknown => $best -> {unknown},
        state   => $best -> {state},
    };


    return $best;
}

=begin testing

# selected_state

=end testing

=cut

sub selected_state { $_[0] -> {context} -> {best} -> {state} }

=begin testing

# missing

=end testing

=cut

sub missing { $_[0] -> {best} -> {missing} || [] }

=begin testing

# invalid

=end testing

=cut

sub invalid { $_[0] -> {best} -> {invalid} || [] }

=begin testing

# unknown

=end testing

=cut

sub unknown { $_[0] -> {best} -> {unknown} || [] }

=begin testing

# messages

=end testing

=cut

sub messages { $_[0] -> {best} -> {messages} || { } }

=begin testing

# generate_validators

{ package My::__METHOD__::Test1;
  our @ISA = __PACKAGE__;
                    
  our %EDGES = (
    state1 => {     
        state2 => {
            required => [qw(one two)],
            optional => [qw(three)],
        },          
    },
    state2 => {
        state1 => {
            required => [qw(four five)],
        }   
    }
  );    
}

My::__METHOD__::Test1 -> generate_validators;

my $vs = \%My::__METHOD__::Test1::VALIDATORS;

ok(eq_set([keys %$vs], [qw(state1 state2)]));

isa_ok($vs -> {'state1'}, 'Data::FormValidator');
isa_ok($vs -> {'state2'}, 'Data::FormValidator');

=end testing

=cut

sub generate_validators {
    my($class) = shift;

    $class = ref $class || $class;

    $class -> _generate_states;

    my $states = \%{"${class}::EDGES_CACHE"};
    %{"${class}::VALIDATORS"} = ( );
    @{"${class}::HASA_KEYS_SORTED"} = sort { length $b <=> length $a } keys %{"${class}::HASA"};
    my $vs = \%{"${class}::VALIDATORS"};

    foreach my $state (keys %$states) {
        delete $states -> {$state} ->{profile} -> {$_} -> {overrides} foreach keys %{$states -> {$state} ->{profile}||{}};

        $vs->{$state} = Data::FormValidator->new($states -> {$state} ->{profile});
    }
}

=begin testing

# _generate_states

{ package My::__METHOD__::Test1;
  our @ISA = __PACKAGE__;

  our %EDGES = (
    state1 => {
        state2 => {
            required => [qw(one two)],
            optional => [qw(three)],
        },
    },
    state2 => {
        state1 => {
            required => [qw(four five)],
        }
    }
  );
}

{ package My::__METHOD__::Test_ALL;
  our @ISA = qw(My::__METHOD__::Test1);

  our %EDGES = (
    _INHERIT => 'ALL',
    state1 => {
      state3 => {
          required => [qw(six)],
      },
      state2 => {
          required => [qw(three)],
      }
    },
  );
}

{ package My::__METHOD__::Test_SUPER;
  our @ISA = qw(My::__METHOD__::Test1);

  our %EDGES = (
    _INHERIT => 'SUPER',
    state1 => {
      state3 => {
          required => [qw(six)],
      },
      state2 => {
          required => [qw(three)],
      }
    },
  );
}

{ package My::__METHOD__::Test_NONE;
  our @ISA = qw(My::__METHOD__::Test1);

  our %EDGES = (
    _INHERIT => 'NONE',
    state1 => {
      state3 => {
          required => [qw(six)],
      },
      state2 => {
          required => [qw(three)],
      }
    },
  );
}

My::__METHOD__::Test_ALL -> _generate_states;

#diag(Data::Dumper -> Dump([\%My::__METHOD__::Test_ALL::EDGES_CACHE]));

is_deeply(\%My::__METHOD__::Test_ALL::EDGES_CACHE, {
  state1 => { 
    profile => {
      state2 => {
        required => [qw(three one two)],
        optional => q(three),
      },
      state3 => {
        required => q(six),
      },
    },
    overrides => { 
      state2 => { },
      state3 => { },
    },
    super_path => [
      [ 'My::__METHOD__::Test1', 'state1' ],
    ],
  },
  state2 => { 
    profile => {
      state1 => {
        required => [qw(four five)],
      }
    },
    overrides => { 
      state1 => { },
    },
    super_path => [
      [ 'My::__METHOD__::Test1', 'state2' ],
    ],
  },
});

My::__METHOD__::Test_SUPER -> _generate_states;

is_deeply(\%My::__METHOD__::Test_SUPER::EDGES_CACHE, {
  state1 => {
    profile => {
      state2 => {
        required => [qw(three one two)],
        optional => q(three),
      },
      state3 => {
        required => q(six),
      },
    },
    overrides => {
      state2 => { },
      state3 => { },
    },
    super_path => [
      [ 'My::__METHOD__::Test1', 'state1' ],
    ],
  },
  state2 => {
    profile => {
      state1 => {
        required => [qw(four five)],
      }
    },
    overrides => {
      state1 => { },
    },
    super_path => [
      [ 'My::__METHOD__::Test1', 'state2' ],
    ],
  },
});

My::__METHOD__::Test_NONE -> _generate_states;

is_deeply(\%My::__METHOD__::Test_NONE::EDGES_CACHE, {
  state1 => {
    profile => {
      state2 => {
        required => q(three),
      },
      state3 => {
        required => q(six),
      },
    },
    overrides => {
      state2 => { },
      state3 => { },
    },
    super_path => [
    ],
  },
  state2 => {
    profile => { },
    overrides => { },
  },
});

=end testing

=cut

sub _generate_states {
    my($class) = shift;
    local($_);

    $class = ref $class || $class;

    return if !$DEBUG && defined %{"${class}::EDGES_CACHE"};

    # need to collect state transitions and feed them into Data::FormValidator
    # able to inherit: SUPER, ALL, NONE (ALL is default for now)
    # need this at the state->state level
    $_ -> _generate_states foreach @{"${class}::ISA"};
    ${"${class}::HASA"}{$_} -> _generate_states(${"${class}::HASA"}{$_}) 
        foreach keys %{"${class}::HASA"};

    %{"${class}::EDGES_CACHE"} = ( );

    %{"${class}::EDGES"} = ( ) unless keys %{"${class}::EDGES"};

    my $cache = \%{"${class}::EDGES_CACHE"};
    my $states = \%{"${class}::EDGES"};
    %{"${class}::VIEWS_CACHE"} = %{"${class}::VIEWS"}; # TODO: make inheritable
    my $inherit = [$states -> {_INHERIT} || 'ALL'];
    my @states;

    {
        my %hash = map { $_ => 1 } 
                       (map { keys %{"${_}::EDGES_CACHE"} } 
                            @{"${class}::ISA"}
                       )
                   ;

        @hash{
            grep { $_ ne '_INHERIT' } 
                 keys %$states
        } = ( );

        @states = keys %hash;
    }

    foreach my $state (@states) {
        next if $state eq '_INHERIT';
        _DEBUG("Working on generating states for ${class}::${state}\n");
        my $def = $states -> {$state};
        my %cdef = ( );
        my @defs = ( );
        unshift @$inherit, ($def -> {_INHERIT}) if defined $def -> {_INHERIT};

        @defs = grep { exists ${"${_}::EDGES_CACHE"}{$state} } @{"${class}::ISA"};
        for($inherit->[0]) {
            /^SUPER$/ && do { @defs = ($defs[0]); last; };
            /^ALL$/ && last;
            /^NONE$/ && do { @defs = ( ); last; };
        }
        $cache->{$state}->{super_path} = [ map { ([ $_ => $state ], $_ -> get_super_path($state)) } @defs ];
        $cache->{$state}->{profile} = _merge_state_defs(
            $inherit,
            (map { ${"${_}::EDGES_CACHE"}{$state}{profile} } @defs), 
            $def
        );
        $cache->{$state}->{overrides} = _merge_state_defs(
            $inherit,
            (map { ${"${_}::EDGES_CACHE"}{$state}{overrides} } @defs),
            {
                map { $_ => $def -> {$_} -> {overrides} } keys %$def
            },
        );
        delete $cache->{$state}->{profile} -> {overrides};
        shift @$inherit if defined $def -> {_INHERIT};
    }

    while(my($p, $h) = each %{"${class}::HASA"}) {
        @states = keys %{"${h}::EDGES_CACHE"};

        foreach my $state (@states) {
            next if $state eq '_INHERIT';
            my $def = $states->{"${p}_${state}"};
            my %cdef = ( );
            my @defs = ( );
            unshift @$inherit, ($def -> {_INHERIT}) if defined $def -> {_INHERIT};

            @defs = ( 
                      ${"${h}::EDGES_CACHE"}{$state}{profile},
                    );
            for($inherit->[0]) {
                /^SUPER$/ && do { @defs = ($defs[0]); last; };
                /^ALL$/ && last;
                /^NONE$/ && do { @defs = ( ); last; };
            }
            for($inherit->[0]) {
                /^SUPER$/ && do 
                             { 
                                 push @{$cache->{"${p}_${state}"}->{super_path}||=[]}, 
                                      [ $h => $state ], $h -> get_super_path($state); 
                                 last; 
                             };
                /^ALL$/ && last;
                /^NONE$/ && last;
            }
            my $tc = _merge_state_defs(
                $inherit,
                #(map { ${"${_}::EDGES_CACHE"}{$state} } @defs),
                @defs,
                $def
            );
            delete $tc -> {overrides};
            $cache->{"${p}_${state}"}->{profile}->{"${p}_$_"} = $tc->{$_}
                for keys %$tc;
            @defs = (
                      ${"${h}::EDGES_CACHE"}{$state}{overrides},
                    );
            $tc = _merge_state_defs(
                $inherit,
                @defs,
                $def->{overrides}
            );
            $cache->{"${p}_${state}"}->{overrides}->{"${p}_$_"} = $tc->{$_}
                for keys %$tc;
            shift @$inherit if defined $def -> {_INHERIT};
        }
    }
    #warn "Edges cache for $class: " . Data::Dumper -> Dump([$cache]);
}

=begin testing

# _merge_state_defs

is_deeply(__PACKAGE__::__METHOD__([qw(ALL)],
   { a => { b => 2 }, b => { a => 1 } },
   { a => { b => 3 }, b => { c => 2 } },
   { c => { a => 2 } },
), {
    a => { b => [3, 2] },
    b => { a => 1, c => 2 },
    c => { a => 2 }
});

is_deeply(__PACKAGE__::__METHOD__([qw(SUPER)],
   { a => { b => 2 }, b => { a => 1 } },
   { a => { b => 3 }, b => { c => 2 } },
   { c => { a => 2 } },
), {
    a => { b => [3, 2] },
    b => { a => 1, c => 2 },
    c => { a => 2 }
});

is_deeply(__PACKAGE__::__METHOD__([qw(NONE)],
   { a => { b => 2 }, b => { a => 1 } },
   { a => { b => 3 }, b => { c => 2 } },
   { c => { a => 2 } },
), {
    a => { b => 2 },
    b => { a => 1 },
    c => { a => 2 },
});


=end testing

=cut

sub _merge_state_defs {
    my $inherit = shift;
    my(@defs) = reverse @_;

    return { } unless @defs;

    my %hash = map { $_ => 1 } (map { keys %$_ } @defs);

    my @states = keys %hash;

    my $ret = { };

    foreach my $state (@states) {
        my @parts = grep {defined} (map { $_->{$state} } @defs);
        for($inherit->[0]) {
            /^SUPER$/ && do { @parts = ((@parts > 1 ? $parts[0] : ()), $parts[-1]); last; };
            /^ALL$/ && last;
            /^NONE$/ && do { @parts = ($parts[-1]);  last; }; 
        }
        $ret -> {$state} = deep_merge_hash(@parts);
    }

    return $ret;
}

sub new {
    my $class = shift;

    $class = ref $class || $class;

    $class -> generate_validators unless defined ${"${class}::VALIDATORS"};
 
    my $self = $class -> SUPER::new(@_);

    $self -> context($self -> {context}) if $self->{context};

    return $self;
}

=begin testing

# clear_context

{ package My::__METHOD__::SM;
  our @ISA = qw(__PACKAGE__);
  our %EDGES = ( );
}

my $sm = My::__METHOD__::SM -> new;

$sm -> clear_context;

is_deeply($sm -> {context}, {
    data => {
      in => { }, out => { },
    },
    saved_context => undef,
});

=end testing

=cut

sub clear_context {
    my $self = shift;

    $self -> {context} = { 
        data => {
            in => { },
            out => { },
        },
        saved_context => $self -> {context} -> {saved_context},
    };
}

=begin testing

# context

my $sm = bless { } => __PACKAGE__;

my $context = {
    in => { a => 'b' },
    out => { foo => 'bar' },
};

$sm -> context(Storable::nfreeze($context));
is_deeply(Storable::thaw($sm -> context), $context);

=end testing

=cut

sub context {
    my $self = shift;

    return Storable::nfreeze($self->{context}) unless @_;

    $self -> {context} = Storable::thaw($_[0]);
}

package StateMachine::Gestinanna::Exception;

use vars qw(@ISA);

use Error ();

@StateMachine::Gestinanna::Exception::ISA = qw(Error);

use overload 'bool' => 'bool';
use strict;

sub bool { 1; }

sub state {
    my $self = shift;

    return $self -> {'-state'};
}

sub data {
    my $self = shift;

    return $self -> {'-data'} || { };
}

1;

__END__

=head1 NAME

Gestinanna::XSM::Base - provides context and state machine for wizard-like applications

=head1 SYNOPSIS

 package My::Wizard;

 @ISA = qw(StateMachine::Gestinanna);

 %EDGES => {
     # state edge descriptions
     start => {
         show => {
             # conditions for transition
         },
         .
         :
     },
     .
     :
 };

 # code for state transitions
 sub start_to_show {
     my $statemachine = shift;
     # do something if going from start to show
 }

 ###
 
 package main;

 my $sm = new My::Wizard(context => $context);
 $sm -> process($data);
 my $state = $sm -> state;
 my $view = $sm -> view;

=head1 DESCRIPTION

StateMachine::Gestinanna is designed to make creation of web-based 
wizards almost trivial.  The module supports inheritance of state 
information and methods so classes of wizards may be created.

StateMachine::Gestinanna inherits from L<Class::Container|Class::Container>.  
This allows specialized state machine classes to be created that 
do more than just manage a state.  For example, the 
L<Gestinanna web application framework|Gestinanna>
specializes StateMachine::Gestinanna to 
provide support for views using the Template Toolkit.

=head1 CREATING A STATE MACHINE

The state machine consists of two parts: the conditions for 
transitioning between states (the edges), and the code that is 
run when there is a state transition.  The meaning of a 
particular state (e.g., displaying a web page) is left to the 
application using the state machine.  This allows for maximum 
flexibility in user interfaces.

=head2 Edge Descriptions

The package variable C<%EDGES> contains the edge descriptions.  
The keys of the hash are the states the edges are from and refer 
to a hash whose keys are the states the edges are to.  These keys 
then point to a hash with a description of the requirements for 
an edge transition

In addition to requirements that should be suitable for 
L<Data::FormValidator|Data::FormValidator> (see 
L<Data::FormValidator> for more information) the C<overrides> key is available.
This is a hash of variables to values.  The values will override 
any data associated with the variables for deciding if that 
particular transition is appropriate.  The data is passed along 
to the transition handler.  See L<StateMachine::Gestinanna::Examples::MailForm> 
for an example of how this can be used.

=head2 Code Run During a Transition

Three different methods may be associated with a transition.  In 
this section, replace C<from> and C<to> in the method names with 
the names of the appropriate states.

If the code needs to preempt the expected target state, it can 
return the name of the new
state.  The state machine will start over with the new target state.

When no error states are returned (C<undef> is returned) and the 
transition is successful, the state machine will halt.

Data associated with the error state may be stored in the `error' data root before returning the error state.

 $sm -> add_data('error', { hash of data };

=over 4

=item from_to_to

This method handles the complete transition and is the only method used 
if it is available.  The name of this method is based on the name 
of the two states: C<${from_state}_to_${to_state}>.  For example, if 
we are transitioning from the C<foo> state to the C<bar> state, 
this method would be named C<foo_to_bar>.

=item post_from

If the C<from_to_to> method is unavailable, this method is called, 
if it is available.  

=item pre_to

If the C<from_to_to> method is unavailable, this method is called, 
if it is available.  

=back

=head2 Throwing Exceptions

The state machine will catch any exceptions of the StateMachine::Gestinanna::Exception 
class and try to extract a new target state and supplimental data.  
This exception class inherits from the L<Error|Error> module.

=head2 Inheritance

State machines have two forms of inheritance: ISA and HASA.

=head3 ISA Inheritance

State machines can inherit all, some, or none of the edges in 
their inheritance tree.  The default is to merge all the edges 
from all the super-classes.  This behavior may be changed by using 
the C<_INHERIT> key.

 %EDGES = (
     _INHERIT => 'SUPER',
     .
     :
 );

The following values are recognized.

=over 4

=item ALL

This is the default behavior.  All edges from all the classes in 
C<@ISA> are inherited.  If the same edge is in multiple classes, 
the requirements are merged (may be modified by specifying the 
_INHERIT flag in the requirements section for a particular edge).

=item SUPER

This is similar to inheritance in Perl.  The first class in the 
C<@ISA> tree that has a particular edge describes that edge.

=item NONE

This is used to keep any edges from being inherited.

=back

Note that this setting does not affect the inheritance of class 
methods.  The code triggered by a transition follows the 
inheritance rules of Perl.

=head3 HASA Inheritance

A state machine may contain copies of other state machines and put 
their state names in their own name space.  For example, if a module 
by the name of C<My::First::Machine> has a state of C<step1> and a 
second module has the following HASA definition, then C<step1> 
becomes the new state of C<first_step1> in C<My::Second::Machine>.

 package My::Second::Machine;

 %HASA = (
    first => 'My::First::Machine',
 );

The methods called on transition may be overridden in the parent 
machine by defining them with the prefix: 
My::Second::Machine::first_state1_to_first_state2 overrides 
My::First::Machine::state1_to_state2.  This is done outside Perl's 
inheritance mechanisms, so calling the method on the state machine 
object will not show the same behavior.

=head1 METHODS

=head2 add_data ($root, $data)

This will add the information in $data to the internal data 
stored in the state machine.  The data will be placed under 
$root.  If $root contains periods (.), it will be split on them 
and serve as a set of keys into a multi-dimensional hash.

=head2 can ($old_state, $new_state)

This will return a code reference if code is defined to be run on 
a transition from C<$old_state> to C<$new_state>.  This will follow 
ISA and HASA inheritance.  Code references are cached.

If called with one argument, this will defer to C<UNIVERSAL::can>.  
This will not follow HASA inheritance.

=head2 clear_data ($root)

This will remove all data under $root that is stored in the state 
machine.

=head2 context ($context)

If called with no arguments, returns a string representing the 
current context of the state machine.  If called with a single 
argument, restores the state machine to the context represented 
by C<$context>.

The context is serialized using L<Storable|Storable>.

=head2 data ($root)

This will retrieve a hash of data stored in the state machine.  
The $root can be used to retrieve only a sub-set of the data.

Parts of the $root may be separated by periods (.).  For example,
C<data("foo.bar")> will return $data{foo}{bar}.  C<data("foo")> 
will retrieve anything added with C<add_data("foo", {})>.

The following roots are used by the state machine:

=over 4

=item in

This is the data given to the C<process> method.  This is used to 
determine which state the machine should transition to.

=item out

This is the data processed by the Data::FormValidator object for 
the selected state.  Additional processing may take place in the 
code triggered by the transition.

=item error

This is any data specified for the error state transition
(the returned error state from a transition handler).

=back

=head2 invalid ( )

Returns a reference to a list of keys in the input data that are 
considered invalid by the validator for the new state.

=head2 missing ( )

Returns a reference to a list of keys that are missing in the 
input data as determined by the validator for the new state.

=head2 new (%config)

Constructs a new state machine instance.  Any class initialization 
will take place also the first time the class is used.  This 
involves caching inherited information and creating the 
validators.  Any changes to the %EDGES hash will be ignored after 
this takes place.

The %config hash may have the following items.  Note that 
L<Class::Container|Class::Container> is used as the parent class.

=over 4

=item context

This is a string previously returned by the C<context> method.  
This can be used to set the machine to a previous state.

=item state

This will set the machine to the given state regardless of the 
context.

=back

=head2 process ($data)

Given a reference to a hash of data, this will select the 
appropriate state to transition to, and then transition to the 
new state.  This is usually the method you need.

=head2 select_state ( )

Given the data and current state in the context, selects the new 
state.  This is used internally by C<process>.

=head2 selected_state ( )

Returns the state most recently selected by the C<select_state> 
method.  If no state was selected, it will return C<undef> or the 
current state, depending on what C<select_state> decides.

=head2 state ($state)

If called without an argument, returns the current state.  If 
called with an argument, sets the state to the argument and 
returns the previous state.

=head2 transit ($state)

This will try and transition from the current state to the new 
state C<$state>.  If there are any errors, error states may be 
processed.  This is used internally by C<process>.

=head2 unknown ( )

Returns a reference to a list of keys in the input data that are unknown to the 
validator for the new state.

=head1 SEE ALSO

L<Class::Container>,
L<Data::FormValidator>,
L<Error>,
L<StateMachine::Gestinanna::Examples::MailForm>,
L<Storable>,
the test scripts in the distribution.

=head1 AUTHOR

James G. Smith <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

