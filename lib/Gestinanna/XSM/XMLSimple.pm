####
# Functions implementing pof:* processing
####

package Gestinanna::XSM::XMLSimple;

use XML::Simple ();
use IO::String;

use strict;

use base qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/xml-simple';

sub start_document {
    return "#initialize pof namespace\n";
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
        
    if ($tag eq 'parse') {
        # get (some) options as attributes
        my $code = 'do { my(%options); my $xml = join("",' . Gestinanna::XSM::compile_expr($e, $attribs{select}) . ');';
        $code .= '$options{suppressempty} = undef;';
        if(defined $attribs{'force-array'}) {
            my $forcearray = $attribs{'force-array'};
            if($forcearray =~ m{\|}) {
                my @bits = split(/\|/, $forcearray);
                $forcearray = '[' . join(', ', map { "\"\Q$_\E\"" } @bits) . ']';
            }
            elsif($forcearray !~ m{^[01]$}) {
                $forcearray = "[ \"\Q$forcearray\E\" ]";
            }
            $code .= "\$options{'forcearray'} = $forcearray;";
        }
        if($attribs{'no-key-attr'}) {
            $code .= '$options{keyattr} = [];';
        }
        foreach my $opt (qw(no-attr suppress-empty force-content content-key normalize-space)) {
            my $popt = $opt;
            $popt =~ s{-}{}g; # make life easier for xml writers
            if(defined $attribs{$opt}) {
                $code .= "\$options{'$popt'} = \"\Q$attribs{$opt}\E\";";
            }
        }
        $code .= 'my $fh = IO::String->new($xml);'; # make sure we are not going to the filesystem
        return $code;
    }
    if($tag eq 'deparse') {
        my $code = 'do { my(%options) = (suppressempty => undef);  my $data = (' . Gestinanna::XSM::compile_expr($e, $attribs{select}) . ')[0];';
        if($attribs{'no-key-attr'}) {
            $code .= '$options{keyattr} = [];';
        }
        foreach my $opt (qw(no-attr root-name content-key xml-decl no-escape suppress-empty)) {
            if(defined $attribs{$opt}) {
                my $popt = $opt;
                $popt =~ s{-}{}g; # make life easier for xml writers
                $code .= "\$options{'$popt'} = \"\Q$attribs{$opt}\E\";";
            }
        }
        return $code;
    }
    if($tag eq 'key-attr') {
        my $element = $attribs{element};
        my $attribute = $attribs{attribute};
        if(defined $element) {
            return "\$options{'keyattr'}{\"\Q$element\E\"} = \"\Q$attribute\E\";";
        }
        return '$options{keyattr} ||= { };';
    }
    if($tag eq 'group-tag') {
        my $group = $attribs{group};
        my $tag = $attribs{tag};
        if(defined $group) {
            return "\$options{'grouptags'}{\"\Q$group\E\"} = \"\Q$tag\E\";";
        }
        return '$options{grouptags} ||= { };';
    }
    if($tag eq 'force-array') {
        my $element = $attribs{element};
        return '' unless defined $element && $element ne '';
        return "push \@{\$options{'force-array'} ||= []}, \"\Q$element\E\" unless defined(\$options{'force-array'} && UNIVERSAL::isa(\$options{'force-array'}) ne 'ARRAY';";
    }
    else {
        warn("Unrecognised tag: $tag");
    }

    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};

    if($tag eq 'parse') {
        return 'XML::Simple::XMLin($fh, %options); }' . $e -> semi;
    }
    elsif($tag eq 'deparse') {
        return 'XML::Simple::XMLout($data,%options); }' . $e -> semi;
    }

    return '';
}

1;
