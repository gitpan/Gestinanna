####
# Functions implementing gst:* processing
####

package Gestinanna::XSM::Gestinanna;

use base qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/gestinanna';

sub start_document {
    return "#initialize gst namespace\n";
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
 
sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }
        
    if ($tag eq 'something') {
    }
}

sub end_element {
}

sub xsm_config($;$) {
    my $sm = shift;
    my $R = Gestinanna::Request -> instance;
    #warn "xsm_config(@_)\n";
    #return unless $axkit_cp;

    if(@_) {
        # find the particular site
    }
    else { # use current site
    #    use Data::Dumper;
    #    warn "returning " . Data::Dumper -> Dump([ $R -> config ]) . "\n";
        return $R -> config;
    }
}

sub xsm_alzabo_schema($) {
    my $R = Gestinanna::Request -> instance;
    return $R -> factory -> {alzabo_schema};
}

sub xsm_ldap_schema($) {
    my $R = Gestinanna::Request -> instance;
    return $R -> factory -> {ldap_schema};
}

sub xsm_ldap_rootdse($) {
    my $R = Gestinanna::Request -> instance;
    return $R -> factory -> {ldap} -> root_dse();
}

sub xsm_split_path($$) {
    my($sm, $path) = @_;
    my $ret = { };
    if($path =~ s{/(\d+(\.\d+)*)$}{}) {
        $ret -> {revision} = $1;
    }
    if($path =~ s{\.([^\./]+)$}{}) {
        $ret -> {type} = $1;
    }
    $ret -> {name} = $path;
    #$path =~ m{^(.*)(?:\.([^\./]*))?(?:/(\d+(?:\.\d+)*))?$};
    #my $ret = {
    #    name => $1,
    #    type => $2,
    #    revision => $3,
    #};
    #warn "split-path($path): $$ret{name} : $$ret{type} : $$ret{revision}\n";
    return $ret;
}

sub valid_filename {
    my( $filename ) = shift;

    return 0 if $filename =~ m{[/.]|\s};
    return 0 if $filename =~ m{^\d+(\.\d+)*$}; # looks like a revision number
    return 1;
}

sub filter_normalize_linebreaks {
    my $v = shift;

    # want to replace \r\n with \n, \n\r with \n, and \r with \n
    $v =~ s{ (?: (?<!\cJ) ((?:\cM\cJ)+)         )
           | (?: (?<!\cM) ((?:\cJ\cM)+)         )
           | (?: (?<!\cJ) (      \cM +) (?!\cJ) )
           }{
               (substr($1,0,1) eq "\cM")
                   ? (substr($1, -1, 1) eq "\cM")
                       ? ("\cJ" x length($1))
                       : ("\cJ" x (length($1) / 2))
                   : ("\cJ" x (length($1) / 2))
          }egsx; # make it canonical according to most UNIX systems/DOS/Windows/Mac
    return $v;
}

sub filter_multiline {
    my $v = shift;

    $v =~ s{ (?: (?<!\cJ) ((?:\cM\cJ)+)         )
           | (?: (?<!\cM) ((?:\cJ\cM)+)         )
           | (?: (?<!\cJ) (      \cM +) (?!\cJ) )
           }{
               (substr($1,0,1) eq "\cM")
                   ? (substr($1, -1, 1) eq "\cM")
                       ? ("\cJ" x length($1))
                       : ("\cJ" x (length($1) / 2))
                   : ("\cJ" x (length($1) / 2))
          }egsx;

    return [ split(/\cJ/, $v) ];
}

1;
