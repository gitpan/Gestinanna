package Gestinanna::XSM::DefaultHandler;

*makeSingleQuoted = \&Gestinanna::XSM::makeSingleQuoted;

sub _undouble_curlies {
    my $value = shift;
    $value =~ s/\{\{/\{/g;
    $value =~ s/\}\}/\}/g;
    return $value;
}

sub _attr_value_template {
    my ($e, $value) = @_;

    return '';
}

sub start_element {
    my ($e, $node) = @_;

    return '';
}

sub end_element {
    my ($e, $element) = @_;

    return '';
}

sub characters {
    my ($e, $node) = @_;

    return '';
}

sub comment {
    return '';
}

sub processing_instruction {
    return '';
}

package Gestinanna::XSM::Op;

# used to preemptively do something else
sub throw {
    my($class, %params) = @_;

    if(@_ > 1) {
        if(ref $class) {
            $params{op} ||= $class -> {op};
        }
        $class = ref $class || $class;
        my $self = bless { } => $class;

        $self -> {op} = $params{op};
        $self -> {arg} = $params{arg};

#        Carp::cluck "Throwing $params{op}\n";
        die $self;
    }
    use Carp ();
#    Carp::cluck "Rethrowing " . $class -> {op} . "\n" if ref $class;
    die $class if ref $class;
    die bless { op => 'noop', args => { } } => $class;
}

sub op { return $_[0] -> {op}; }

sub arg { return $_[0] -> {arg} -> {$_[1]}; }

sub AUTOLOAD {
    our $AUTOLOAD;
    my $class = shift;
    return if ref $class;
    
    my($op) = $AUTOLOAD =~ /::([^:]+)$/;
    
    return if $op eq 'DESTROY';
    
    my $self = bless { } => $class;

    $self -> {op} = $op;
    $self -> {arg} = { @_ };

#    Carp::cluck "Throwing $op\n";
    die $self;
}


1;

__END__
