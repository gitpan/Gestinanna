####
# Functions implementing digest:* processing
####

package Gestinanna::XSM::Digest;

our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/digest';

__PACKAGE__ -> register;

sub start_document {
    return "#initialize digest namespace\n";
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

#my %test_types = qw( lt < le <= gt > ge >= eq = ne != );
 
sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    #else {
        warn("Unrecognised tag: $tag");
    #}

    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};

    return '';
}

BEGIN {
    our %DIGESTS;

    sub xsm_has_digest ($) { return $DIGESTS{uc $_[0]}; }
    sub xsm_digests    ($) { return grep { $DIGESTS{$_} } keys %DIGESTS; }

    eval "require Digest::MD5";
    $DIGESTS{'MD5'} = 1 unless $@;

    if($DIGESTS{'MD5'}) {
        *xsm_md5_hex = sub ($$) { Digest::MD5::md5_hex($_[1]); };
        *xsm_md5     = sub ($$) { Digest::MD5::md5($_[1]); };
    }

    eval "require Digest::SHA1";
    $DIGESTS{'SHA-1'} = 1 unless $@;

    if($DIGESTS{'SHA-1'}) {
        *xsm_sha1_hex = sub ($$) { Digest::SHA1::sha1_hex($_[1]); };
        *xsm_sha1     = sub ($$) { Digest::SHA1::sha1($_[1]); };
    }
}

1;
