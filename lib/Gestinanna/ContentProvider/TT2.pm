package Gestinanna::ContentProvider::TT2;

use base qw(Gestinanna::ContentProvider);

use Template;
use Template::Exception;
use Apache::Template::Provider::Gestinanna;

sub content {
    my $self = shift;

    if($self -> {content}) {
        my $tt2_config = {

            POST_CHOMP => 1,

            (map { tr/-/_/; ( uc $_ => $self -> {config} -> {'template-toolkit'} -> {$_} ) }
                 keys %{$self -> {config} -> {'template-toolkit'} || {}}),

            INCLUDE_PATH => $self -> {include_path},
            INTERPOLATE => 0,
            EVAL_PERL => 0,
            RELATIVE => 1,
            ABSOLUTE => 1,
            POF_TYPE => $self -> {type},
        };
        $tt2_config -> {LOAD_TEMPLATES} = [ 
            Apache::Template::Provider::Gestinanna -> new(
                %$tt2_config,
#                AXKIT_CP => $self,
            ),
        ];

        my $template = Template -> new($tt2_config);

        my $output = '';
        eval {
            local $SIG{__DIE__};

            $template -> process(\($self -> {content} -> data), $self -> {args}, \$output)
                or ($output = "<container><title>Template Error</title><content><para>"
                              . $template -> error -> type() . ': '
                              . $template -> error -> info()
                              . "</para></content></container>");
        };

        if($@) {
            my $e = $@;
            $e =~ s{&}{&amp;};
            $e =~ s{<}{&lt;};
            $e =~ s{>}{&gt;};
            $output = "<container><title>Error</title><content><para>$e</para></content></container>";
        }

        #warn "output: $output\n";

        return \$output;
    }
    return;
}

1;

__END__

package Gestinanna::ContentProvider::TT2::TemplateProvider;

use strict;
use base qw( Template::Provider );
use Data::Dumper       qw( Dumper );
use Digest::MD5        qw();
use File::Spec         qw();

$Gestinanna::ContentProvider::TT2::TemplateProvider::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_MAX_CACHE_TIME       => 60 * 30;
use constant DEFAULT_TEMPLATE_EXTENSION   => 'view';
use constant DEFAULT_PACKAGE_TEMPLATE_DIR => '/';
use constant DEFAULT_TEMPLATE_TYPE        => 'repository';

# TODO: make this specific to Gestinanna (taken from OpenInteract)
# This is the level to set for $R->scrib -- if you set it to 0
# everything will be logged. (And this is a lot!)

my $DEBUG = 2;
sub DEBUG_LEVEL     { return $DEBUG }
sub SET_DEBUG_LEVEL { $DEBUG = $_[1] }

# Copied from Template::Provider since they're not exported

use constant PREV   => 0;
use constant NAME   => 1;
use constant DATA   => 2;
use constant LOAD   => 3;
use constant NEXT   => 4;
use constant STAT   => 5;

# This should return a two-item list: the first is the template to be
# processed, the second is an error (if any). $name is a simple name
# of a template, which in our case is often of the form
# 'package::template_name'.

sub fetch {
my ( $self, $text ) = @_;
    #my $R = Gestinanna::Request->instance;

    my ( $name );

    # if scalar or glob reference, then get a unique name to cache by

    if ( ref( $text ) eq 'SCALAR' ) {
	#$R->DEBUG && $R->debug( DEBUG_LEVEL, "anonymous template passed in" );
	$name = $self->_get_anon_name( $text );
    }
    elsif ( ref( $text ) eq 'GLOB' ) {
	#$R->DEBUG && $R->scrib( DEBUG_LEVEL, "GLOB passed in to fetch" );
        $name = $self->_get_anon_name( $text );
    }

    # Otherwise, it's a 'type::template' name or a unique filename
    # found in the search path, both of which are handled in
    # _load() below. Also check that the template name doesn't have
    # any invalid characters (e.g., '../../../etc/passwd')

    else {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "info passed in is site filename or package::template;",
        #                                     "will check file system or database for ($text)" );
        $name = $text;
        undef $text;
        eval { $self->_validate_template_name( $name ) };
        if ( $@ ) { return ( $@, Template::Constants::STATUS_ERROR ) }
    }

    # If we have a directory to compile the templates to, create a
    # unique filename for this template

    # Just keep the compile name the same as the name passed
    # in, replacing '::' with '-'

    my ( $compile_file );

    if ( $self->{COMPILE_DIR} ) {
        my $ext = $self->{COMPILE_EXT} || '.ttc';
        my $compile_name = $name;
        $compile_name =~ s/::/-/g;
        $compile_file = File::Spec->catfile( $self->{COMPILE_DIR},
                                             $compile_name . $ext );
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "compiled output filename ",
        #                        "[$compile_file]" );
    }

    my ( $data, $error );

    # caching disabled (cache size is 0) so load and compile but don't cache

    if ( $self->{SIZE} == 0 ) {
	#$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [caching disabled]" );
        ( $data, $error ) = $self->_load( $name, $text );
        ( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
        $data = $data->{data}                                       unless ( $error );
    }

    # cached entry exists, so refresh slot and extract data

    elsif ( $name and ( my $cache_slot = $self->{LOOKUP}{ $name } ) ) {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [cached (limit: $self->{SIZE})]" );
        ( $data, $error ) = $self->_refresh( $cache_slot );
        $data = $cache_slot->[ DATA ] unless ( $error );
    }

	# nothing in cache so try to load, compile and cache

    else {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [uncached (limit: $self->{SIZE})]" );
        ( $data, $error ) = $self->_load( $name, $text );
        ( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
        $data = $self->_store( $name, $data )                       unless ( $error );
    }

    return( $data, $error );
}


# NOTE: You should NEVER even check to see if $name exists anywhere
# else on the filesystem besides under the $WEBSITE_DIR. The
# SiteTemplate object takes care of this, but it's just another
# warning...
#
# From Template::Provider -- here's what the hashref includes:
#
#   name    filename or $content, if provided, or 'input text', etc.
#   text    template text
#   time    modification time of file, or current time for handles/strings
#           (we also use this for the 'last_update' field of an SPOPS object)
#   load    time file/object was loaded (now!)

sub _load {
    my ( $self, $name, $content ) = @_;

    my $R = Gestinanna::Request->instance;
    #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "_load(@_[1 .. $#_])\n" );

    # If no name, $self->{TOLERANT} being true means we can decline
    # safely. Otherwise return an error. We might modify this in the
    # future to not even check TOLERANT -- if it's not defined we
    # don't want anything to do with it, and nobody else should either
    # (NYAH!). Note that $name should be defined even if we're doing a
    # scalar ref or glob template

    unless ( defined $name ) {
        if ( $self->{TOLERANT} ) {
#            $R->DEBUG && $R->scrib( DEBUG_LEVEL, "No name passed in and ",
#                                    "TOLERANT set, so decline" );
            return ( undef, Template::Constants::STATUS_DECLINED );
        }
#        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "No name passed in and TOLERANT ",
#                                "not set, so return error" );
        return ( "No template", Template::Constants::STATUS_ERROR );
    }

    # is this an anonymous template? if so, return it

    # Note: it would be cool if we could figure out where 'name' is
    # passed to and have it deal with references properly, and then
    # propogate that reference through to processing, etc.

    if ( ref( $content ) eq 'SCALAR' ) {
#        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Nothing to load since ",
#                                "template is scalar ref." );
        return ({ 'name' => $name,
                  'text' => $$content,
                  'time' => time,
                  'load' => 0 }, undef );
    }

    if ( ref( $content ) eq 'GLOB' ) {
#        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template is glob (file) ",
#                                "ref, so read in" );
        local $/ = undef;
        return ({ 'name' => 'file handle',
                  'text' => <$content>,
                  'time' => time,
                  'load' => 0 }, undef );
    }

    my ( $content_template, $data );
    eval {
        $content_template = $R -> factory -> new( 'view', $name );
        #$content_template = $R->site_template->fetch( $name );
        unless ( $content_template ) {
            die "Template with name [$name] not found.\n";
        }
        $data = { 'name' => $content_template->full_filename,
                  'text' => $content_template->contents,
                  'time' => $content_template->modified_on,
                  'load' => time };

    };
    if ( $@ ) {
        return ( $@, Template::Constants::STATUS_ERROR );
    }
    return ( $data, undef );
}


# Override so we can use OI-configured value for seeing whether we
# need to refresh

sub _refresh {
	my ( $self, $slot ) = @_;
	my ( $head, $file, $data, $error );

    my $R = Gestinanna::Request->instance;
#    $R->DEBUG && $R->scrib( DEBUG_LEVEL, "_refresh([ @$slot ])" );

    # If the cache time has expired reload the entry

    my $do_reload = 0;
    my $max_cache_time = $R->CONFIG->{cache}{template}{expire}
                         || DEFAULT_MAX_CACHE_TIME;
    if ( ( $slot->[ DATA ]->{'time'} - time ) > $max_cache_time ) {
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Refreshing cache for template: ",
                                $slot->[ NAME ] );
        ( $data, $error ) = $self->_load( $slot->[ NAME ] );
        ( $data, $error ) = $self->_compile( $data )  unless ( $error );
        unless ( $error ) {
            $slot->[ DATA ] = $data->{ data };
            $slot->[ LOAD ] = $data->{ time };
        }
    }

    # remove existing slot from usage chain...

    if ( $slot->[ PREV ] ) {
        $slot->[ PREV ][ NEXT ] = $slot->[ NEXT ];
    }
    else {
        $self->{ HEAD } = $slot->[ NEXT ];
    }

    if ( $slot->[ NEXT ] ) {
        $slot->[ NEXT ][ PREV ] = $slot->[ PREV ];
    }
    else {
        $self->{ TAIL } = $slot->[ PREV ];
    }

    # ... and add to start of list
    $head = $self->{ HEAD };
    $head->[ PREV ] = $slot if ( $head );
    $slot->[ PREV ] = undef;
    $slot->[ NEXT ] = $head;
    $self->{ HEAD } = $slot;

    return ( $data, $error );
}


# Ensure there aren't any funny characters

sub _validate_template_name {
    my ( $self, $name ) = @_;
    if ( $name =~ m|\.\.| ) {
        die "Template name must not have any directory tree symbols (e.g., '..')";
    }
    if ( $name =~ m|^/| ) {
        die "Template name must not begin with an absolute path symbol";
    }
    return 1;
}

########################################
# ANONYMOUS TEMPLATE NAME

# store names for non-named templates by using a unique fingerprint of
# the template text as a hash key

my $ANON_NUM      = 0;
my %ANON_TEMPLATE = ();

sub _get_anon_name {
    my ( $self, $text ) = @_;
    my $key = Digest::MD5::md5_hex( ref( $text ) ? $$text : $text );
    return $ANON_TEMPLATE{ $key } if ( exists $ANON_TEMPLATE{ $key } );
    return $ANON_TEMPLATE{ $key } = 'anon_' . ++$ANON_NUM;
}

1;

__END__
