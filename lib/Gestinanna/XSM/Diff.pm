####
# Functions implementing diff:* processing
####

package Gestinanna::XSM::Diff;

use Algorithm::Diff ();
use Algorithm::Merge ();

our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/diff';

__PACKAGE__ -> register;

sub start_document {
    return "#initialize diff namespace\n";
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
        
    #else {
        warn("Unrecognised tag: $tag");
    #}

#           [ AND => (
#                [ 'name', '=', 'some name' ],
#                [ OR => (
#                     [ 'age',  '<', '40' ],
#                     [ 'postalcode', '=', '12345' ]
#                  )
#                ]
#              )
#            ]


    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};

    return '';
}

my $split_regex = qr{ (?: (?<!\cJ) (?:\cM\cJ)(?:\cM(\cJ))*         )
                    | (?: (?<!\cM) (?:\cJ\cM)(?:(\cJ)\cM)*         )
                    | (?: (?<!\cJ)       \cM               (?!\cJ) )
                    | (?: (?<!\cM)       \cJ               (?!\cM) )
                  }x;

sub _split {
    return [ ( map { s{[\cJ\cM]+}{}g; $_ } grep { defined } split(/$split_regex/, $_[0]) ) ];
}

sub xsm_two_way_s($$$) {
    my($sm, $left, $right) = @_;

#    my @left = grep { defined } split(/$split_regex/, $left);
#    my @right = grep { defined } split(/$split_regex/, $right);

#    return Algorithm::Diff::sdiff(\@left, \@right);
    return Algorithm::Diff::sdiff(_split($left), _split($right));
}

sub xsm_two_way($$$) {
    my($sm, $left, $right) = @_;

    return Algorithm::Diff::diff(_split($left), _split($right));

    #my @left = grep { defined } split(/$split_regex/, $left);
    #my @right = grep { defined } split(/$split_regex/, $right);

    #return Algorithm::Diff::diff(\@left, \@right);
}

sub xsm_three_way($$$$) {
    my($sm, $middle, $left, $right) = @_;
    
    return Algorithm::Merge::diff3(_split($middle), _split($left), _split($right));
    #my @left = grep { defined } split(/$split_regex/, $left);
    #my @right = grep { defined } split(/$split_regex/, $right);
    #my @middle = grep { defined } split(/$split_regex/, $middle);

    #return Algorithm::Merge::diff3(\@middle, \@left, \@right);
}

sub xsm_three_way_middle_revision($$$) {
    my($sm, $left, $right) = @_;

    my @left = split(/\./, $left);
    my @right = split(/\./, $right);
    if($left[0] != $right[0]) {
        # there's no common revision possible
        return '';
    }

    my @middle;
    while($left[0] == $right[0]) {
        push @middle, shift @left;
        shift @right;
    }
    if(@middle % 2 == 1) { # odd number, so we're in the right branch...
        if($left[0] < $right[0]) {
            push @middle, $left[0];
        }
        else {
            push @middle, $right[0];
        }
    }
    return join(".", @middle);
}

1;
