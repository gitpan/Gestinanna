####
# Functions implementing digest:* processing
####

package Gestinanna::XSM::Digest;
use base qw(Gestinanna::XSM);
use strict;

=begin testing

# BEGIN

__OBJECT__ = bless { } => __PACKAGE__;

=end testing

=cut

use base qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/digest';

=begin testing

# start_document

is(__PACKAGE__::start_document, "#initialize digest namespace\n");

=end testing

=cut

sub start_document {
    return "#initialize digest namespace\n";
}

=begin testing

# end_document

is(__PACKAGE__::end_document, '');

=end testing

=cut

sub end_document {
    return '';
}

=begin testing

# comment

is(__PACKAGE__::comment, '');

=end testing

=cut

sub comment {
    return '';
}
        
=begin testing

# processing_instruction

is(__PACKAGE__::processing_instruction, '');

=end testing

=cut

sub processing_instruction {
    return '';
}

=begin testing

# characters

__OBJECT__ -> set_state('text', '');

is(__OBJECT__ -> characters('text text'), '');

is(__OBJECT__ -> state('text'), 'text text');

=end testing

=cut
            
sub characters {
    my ($e, $text) = @_;
 
    $e -> append_state('text', $text);

    return '';
}

#my %test_types = qw( lt < le <= gt > ge >= eq = ne != );

=begin testing

# start_element

is(__OBJECT__ -> start_element({ Name => 'name', Attributes => [] }), '');

=end testing

=cut
 
sub start_element {
    return '';
}

=begin testing

# end_element

is(__OBJECT__ -> end_element({ Name => 'name', Attributes => [] }), '');

=end testing

=cut
 
sub end_element {
    return '';
}

BEGIN {

=begin testing

# xsm_has_digest

#main::diag(Data::Dumper -> Dump([\%Gestinanna::XSM::Digest::])); # -> {"Gestinanna::"}->{"XSM::"}->{"Digest::"}]));
#main::diag(Data::Dumper -> Dump([\%__PACKAGE__::]));
#main::diag(Data::Dumper -> Dump([\%__PACKAGE__::DIGESTS]));

is(__PACKAGE__::xsm_has_digest({ }, 'md5'), (defined(&__PACKAGE__::xsm_md5) ? 1 : 0));
is(__PACKAGE__::xsm_has_digest({ }, 'sha1'), (defined(&__PACKAGE__::xsm_sha1) ? 1 : 0));

=end testing

=cut

    my %DIGESTS = ( MD5 => 0, SHA1 => 0 );

    sub xsm_has_digest ($$) { return $DIGESTS{uc $_[1]}; }

=begin testing

# xsm_digests

my %DIGESTS = map { $_ => __PACKAGE__::xsm_has_digest({ }, $_) } qw(
    MD5
    SHA1
);

ok(eq_set([ __PACKAGE__::xsm_digests({ }) ], [ grep { 1 == $DIGESTS{$_} } keys %DIGESTS ]));

=end testing

=cut

    sub xsm_digests    ($) { return grep { 1 == $DIGESTS{$_} } keys %DIGESTS; }

    eval "require Digest::MD5";

    unless($@) {
        $DIGESTS{'MD5'} = 1;

=begin testing

# xsm_md5_hex

if(__PACKAGE__::xsm_has_digest({ }, 'md5')) {
    is(__PACKAGE__::xsm_md5_hex({ }, 'some text'), Digest::MD5::md5_hex('some text'));
}

=end testing

=cut

        *xsm_md5_hex = sub ($$) { Digest::MD5::md5_hex($_[1]); };

=begin testing

# xsm_md5

if(__PACKAGE__::xsm_has_digest({ }, 'md5')) {
    is(__PACKAGE__::xsm_md5({ }, 'some text'), Digest::MD5::md5('some text'));
}

=end testing

=cut

        *xsm_md5     = sub ($$) { Digest::MD5::md5($_[1]); };
    }

    eval "require Digest::SHA1";

    unless($@) {
        $DIGESTS{'SHA1'} = 1;

=begin testing

# xsm_sha1_hex

if(__PACKAGE__::xsm_has_digest({ }, 'sha1')) {
    is(__PACKAGE__::xsm_sha1_hex({ }, 'some text'), Digest::SHA1::sha1_hex('some text'));
}

=end testing

=cut

        *xsm_sha1_hex = sub ($$) { Digest::SHA1::sha1_hex($_[1]); };

=begin testing

# xsm_sha1
     
if(__PACKAGE__::xsm_has_digest({ }, 'sha1')) {   
    is(__PACKAGE__::xsm_sha1({ }, 'some text'), Digest::SHA1::sha1('some text'));
}

=end testing

=cut

        *xsm_sha1     = sub ($$) { Digest::SHA1::sha1($_[1]); };

    }
}

1;
