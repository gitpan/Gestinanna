package Gestinanna::ContentProvider;

use Gestinanna::Request;

sub init {
    my($class, %params) = @_;

    my $self = bless { %params } => $class;
    #warn "created $self\n";
    #warn "params: ", join(", ", keys %params), "\n";

    my $content = $self -> retrieve_content($params{filename});

    return unless $self -> is_content_good($content);

    $self -> {content} = $content;

    return $self;
}

use Carp ();
sub retrieve_content { 
    my($self, $factory, $type, $filename);

    my $R = Gestinanna::Request -> instance;

    if(@_ > 2) {
        Carp::cluck "retrieve_content called with deprecated number of arguments";
        ($factory, $type, $filename) = @_[1..3];
    }
    else {
        $self = shift;
        ($factory, $type) = ($R -> factory, $self -> {type});
        $filename = shift;
    }

    return $factory -> new($type => object_id => $filename);
}

sub is_content_good { $_[1] && $_[1] -> is_live }

sub may_exec { # checks for exec attribute
    my $self = shift;

    return unless $self -> {content};

    return $self -> {content} -> has_access(undef, [qw(exec)])
}

sub mtime { time }

sub dom {
    my $self = shift;

    require XML::LibXML;

    my $parser = XML::LibXML->new();
    #$parser -> expand_entities(0);

    my $doc;

#    eval { $doc = $parser->parse_string(q{<?xml version="1.0" ?>
#<!DOCTYPE stylesheet [
#  <!ENTITY nbsp "<nbsp/>">
#]>
#} . ${$self -> content || \"<container/>"}); };
    eval { $doc = $parser->parse_string(${$self -> content || \"<container/>"}); };
    warn "$@\n" if $@;

    return $doc;
}

1;

__END__
