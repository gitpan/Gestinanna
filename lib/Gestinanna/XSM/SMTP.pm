####
# Functions implementing smtp:* processing
####

package Gestinanna::XSM::SMTP;

use base qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/smtp';

sub start_document {
    return "#initialize smtp namespace\n";
}

sub end_document {
    return '';
}

sub comment {
    return '';
}
        
sub processing_instruction {
    return '';
}
            
sub characters {
    my ($e, $text) = @_;
 
    $e -> append_state('text', $text);

    return '';
}

my %test_types = qw( lt < le <= gt > ge >= eq = ne != );
 
sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    if($tag eq 'message' || $tag eq 'send-mail') {
        $e -> push_state;
        $e -> reset_state('in-expression');
        $e -> enter_state('in-smtp');
        my $var = '$smtp_msg' . $e -> state('in-smtp');
        return "do { my $var = new Gestinanna::XSM::SMTP::Message; ";
    }
    else {
        #warn("Unrecognised tag: $tag");
        # assume it's a header tag
        my $select = Gestinanna::XSM::compile_expr($e, $attribs{select});
        $select .= "," if defined $select && $select ne '';
        my $var = '$smtp_msg' . $e -> state('in-smtp');
        my $method = "add_$tag";
        $method =~ s{[^a-zA-Z0-9_]}{_}g;
        $method =~ tr[A-Z][a-z];
        if($e -> state('in-expression')) {
            $e -> enter_state('in-expression');
            return "(($var -> can('$method')) ? $var -> $method($select";
        }
        else {
            $e -> enter_state('in-expression');
            return "$var -> $method($select";
        }
    }

    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};

    if($tag eq 'send-mail' || $tag eq 'message') {
        my $code = $e -> state('script');
        my $var = '$smtp_msg' . $e -> state('in-smtp');
        $e -> pop_state;
        $e -> set_state('script', $code);
        # magic goes here
        if($tag eq 'send-mail') {
            return "$var -> send; }" . $e -> semi;
        }
        else {
            return "$var; }" . $e -> semi;
        }
    }
    else {
        $e -> leave_state('in-expression');
        my $method = "add_$tag";
        $method =~ s{[^a-zA-Z0-9_]}{_}g;
        $method =~ tr[A-Z][a-z];
        my $var = '$smtp_msg' . $e -> state('in-smtp');
        if($e -> state('in-expression')) {
            return ") : ())" . $e -> semi;
        }
        else {
            return ") if $var -> can('$method')" . $e -> semi;
        }
    }
    return '';
}

use Email::Valid;

sub message {
    my $info = shift;

    return Gestinanna::XSM::SMTP::Message -> new ($info);
}

sub sendmail {
    my $info = shift;

    my $msg = message($info);
    if($msg) {
        $msg -> send;
    }
}

package Gestinanna::XSM::SMTP::Message;

sub new {
    my $class = shift;
    my $info = shift;

    my @address_errors;

    # need to default From: to something
    # can From: have more than one address?
    my $self = bless { } => $class;

    foreach my $addr_type (qw(to cc bcc from)) {
        if($info -> {$addr_type}) {
            eval {
                $self -> add_address($addr_type, @{$info -> {$addr_type}});
            };
            push @address_errors, $@ if $@;
        }
    }

    $self -> add_message($_) foreach @{$info -> {message}||[]};

    if(@address_errors) {
        die join(" ", @address_errors); # need to throw an object aggregating any errors
    }

    return $self;
}

sub add_attachment {
    my $self = shift;

    # do stuff to add file
}

use Mail::Sendmail;
use Apache::AxKit::CharsetConv;

sub send {
    my $self = shift;

    # do stuff to send message
    $info -> {'content-type'} = ($self -> {'content-type'}) ? $self -> {'content-type'} -> [0] : 'text/plain';

    $info -> {'charset'} = ($self -> {'charset'}) ? $self -> {'charset'} -> [0] : 'utf-8';
    $info -> {'content-type'} .= '; charset=' . $info -> {'charset'};

    # munge the text if it needs to be
    # or, we can treat each member of message as a different part of a multipart message
    if ($info->{'charset'} and lc($info->{'charset'}) ne 'utf-8') {
        my $conv = Apache::AxKit::CharsetConv->new('utf-8',$info->{'charset'})
                or die "No such charset: $info->{'charset'}"; # throw an object
        $info->{'message'} = $conv->convert(join("\n", @{$self->{'message'}||[]}));
    }
    else {
        $info -> {'message'} = join("\n", @{$self -> {'message'}});
    }

    $info -> {subject} = join(" ", @{$self -> {subject}||[]});
    for my $addr (qw(from to bcc cc reply-to)) {
        next unless $self -> {$addr};
        $info -> {$addr} = join(", ", @{$self -> {$addr}});
    }

    warn "Info: " . Data::Dumper -> Dump([$info]);

    # we don't handle attachments yet...
    sendmail( %{$info} ) || die $Mail::Sendmail::error; # again, throw an object
}

sub add_to {
    my $self = shift;
    return $self -> add_address('to', @_);
}

sub add_cc {
    my $self = shift;
    return $self -> add_address('cc', @_);
}

sub add_bcc {
    my $self = shift;
    return $self -> add_address('bcc', @_);
}

sub add_from {
    my $self = shift;
    warn "$self -> add_from(" . join(", ", @_) . ")\n";
    return $self -> add_address('from', @_);
}

sub add_address {
    my($self, $header, @list) = @_;
    my @address_errors;
    my @valid;
    foreach my $addr (@list) {
        warn "Testing [$addr] for $header\n";
        if(Email::Valid -> address($addr)) {
            push @valid, $addr;
            next;
        }
        push @address_errors, "Address $addr in '$addr_type' element failed $Email::Valid::Details check.";
    }
    if(@valid) {
        push @{$self -> {$header}||=[]}, @valid;
        warn "Adding ", join(", ", @valid), " to $header\n";
    }

    die join(" ", @address_errors) if @address_errors; # need to throw an object that can be caught
}

sub set_address {
    my($self, $header, @list) = @_;

    my @address_errors;
    my @valid;
    foreach my $addr (@{$info -> {$addr_type}||[]}) {
        if(Email::Valid -> address($addr)) {
            push @valid, $addr;
            next;
        }
        push @address_errors, "Address $addr in '$addr_type' element failed $Email::Valid::Details check.";
    }

    die join(" ", @address_errors) if @address_errors; # need to throw an object that can be caught

    if(@valid) {
        $self -> {$header} = \@valid;
    }
}

sub set_to {
    my $self = shift;
    return $self -> set_address('to', @_);
}

sub set_cc {
    my $self = shift;
    return $self -> set_address('cc', @_);
}

sub set_bcc {
    my $self = shift;
    return $self -> set_address('bcc', @_);
}

sub set_from {
    my $self = shift;
    return $self -> set_address('from', @_);
}

sub add_message {
    my $self = shift;
    push @{$self -> {message} ||= []}, @_;
}

*add_body = \&add_message;

sub add_reply_to {
    my $self = shift;
    $self -> add_address('reply-to', @_);
}

sub add_subject {
    my $self = shift;

    push @{$self -> {subject} ||= []}, @_;
}

1;
