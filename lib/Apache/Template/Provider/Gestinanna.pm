package Apache::Template::Provider::Gestinanna;

use strict;

use base qw( Template::Provider );
use Digest::MD5 ();
use Gestinanna::Request;

use constant DEFAULT_MAX_CACHE_TIME       => 60 * 30;
use constant DEFAULT_TEMPLATE_EXTENSION   => 'view';
use constant DEFAULT_PACKAGE_TEMPLATE_DIR => '';
use constant DEFAULT_TEMPLATE_TYPE        => 'repository';

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

#names:
#  type::{abs,rel}path(:revision)?
#  {abs,rel}path(:revision)?  -> type defaults to DEFAULT_TEMPLATE_EXTENSION
#  type is the factory type for retrieving the template
#  revision defaults to the tag_path

# This should return a two-item list: the first is the template to be
# processed, the second is an error (if any). $name is a simple name
# of a template, which in our case is often of the form
# 'package::template_name'.

sub fetch {
    my ( $self, $text ) = @_;
    my $R = Gestinanna::Request->instance;

    my ( $name );

    #warn "Fetching [$text]\n";
    # if scalar or glob reference, then get a unique name to cache by

    if ( ref( $text ) eq 'SCALAR' ) {
        #warn "Passed in string: [$$text]\n";
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "anonymous template passed in" );
        $name = $self->_get_anon_name( $text );
    }
    elsif ( ref( $text ) eq 'GLOB' ) {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "GLOB passed in to fetch" );
        $name = $self->_get_anon_name( $text );
    }

    # Otherwise, it's a 'package::template' name or a unique filename
    # found in '$WEBSITE_DIR/template', both of which are handled in
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

    #warn "name: $name\n";

    # If we have a directory to compile the templates to, create a
    # unique filename for this template

    # Just keep the compile name the same as the name passed
    # in, replacing '::' with '-'

    my ( $compile_file, $compile_name, $ext );

    if ( $self->{COMPILE_DIR} ) {
        $ext = $self->{COMPILE_EXT} || '.ttc';
        $compile_name = $name;
        $compile_name =~ s/::/-/g;
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "compiled output filename ",
        #                        "[$compile_file]" );
    }

    my ( $data, $error );

    # caching disabled (cache size is 0) so load and compile but don't cache

    if ( !defined($self -> {SIZE}) || $self->{SIZE} == 0 ) {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [caching disabled]" );
        ( $data, $error ) = $self->_load( $name, $text );
        $compile_file = File::Spec->catfile( $self->{COMPILE_DIR}, $data -> {type},
                                            $compile_name , $data -> {rev} . $ext ) if $self -> {COMPILE_DIR};
       ( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
       $data = $data->{data}                                               unless ( $error );
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
        my $rev = $data -> {rev};
        my $type = $data -> {type};
        $compile_file = File::Spec->catfile( $self->{COMPILE_DIR}, $type,
                                            $compile_name , $rev . $ext ) if $self -> {COMPILE_DIR};
    ( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
    $data = $self->_store( $type. '/' . $name . '/' . $rev, $data )     unless ( $error );
    }

    #warn "Returning: ", Data::Dumper -> Dump([$data]);

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
            #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "No name passed in and ",
            #                        "TOLERANT set, so decline" );
            return ( undef, Template::Constants::STATUS_DECLINED );
        }
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "No name passed in and TOLERANT ",
        #                        "not set, so return error" );
        return ( "No template", Template::Constants::STATUS_ERROR );
    }

    # is this an anonymous template? if so, return it

    # Note: it would be cool if we could figure out where 'name' is
    # passed to and have it deal with references properly, and then
    # propogate that reference through to processing, etc.

    if ( ref( $content ) eq 'SCALAR' ) {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "Nothing to load since ",
        #                        "template is scalar ref." );
        return ({ 'name' => $name,
                  'text' => $$content,
                  'time' => time,
                  'load' => 0 }, undef );
    }

    if ( ref( $content ) eq 'GLOB' ) {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template is glob (file) ",
        #                        "ref, so read in" );
        local $/ = undef;
        return ({ 'name' => 'file handle',
                  'text' => <$content>,
                  'time' => time,
                  'load' => 0 }, undef );
    }

    my ( $content_template, $data );
    my $factory = $R -> factory;
    my $type = $self -> {POF_TYPE} || 'view'; # best we can do for now (sets the default type)
    if($name =~ m{^([^:]+):([^:]+)$}) {
        $type = $1;
        $name = $2;
    }
    my @path = ref($self -> {INCLUDE_PATH}) 
                   ? @{$self -> {INCLUDE_PATH}} 
                   : split(/:/, $self -> {INCLUDE_PATH});

    push @path, '/sys/default'; # always the last resort -- may want to make this configurable
    warn "Path: ", join(":", @path), "\n";

    eval {
        while(@path && !($content_template && $content_template -> is_live)) {
            my $p = shift @path;
            warn "trying $p/$name\n";
            $content_template = $factory -> new(
                $type => object_id => "$p/$name",
            );
        }
        unless ( $content_template ) {
            die "Template with name [$name] not found.\n";
        }
        $data = { 'name' => $content_template->name,
                  'text' => $content_template->data,
                  #'time' => $content_template->modified_on, # need to translate to epoch seconds
                  'time' => time,
                  'load' => time,
                  'type' => $type,
                  'rev'  => $content_template->revision,
                };

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
    #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "_refresh([ @$slot ])" );

    # If the cache time has expired reload the entry

    my $do_reload = 0;
    my $max_cache_time = $R->config->{cache}{template}{expire}
                         || DEFAULT_MAX_CACHE_TIME;
    if ( ( $slot->[ DATA ]->{'time'} - time ) > $max_cache_time ) {
        #$R->DEBUG && $R->scrib( DEBUG_LEVEL, "Refreshing cache for template: ",
        #                        $slot->[ NAME ] );
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
    #warn "key : $key\n";
    return $ANON_TEMPLATE{ $key } if ( exists $ANON_TEMPLATE{ $key } );
    return $ANON_TEMPLATE{ $key } = 'anon_' . ++$ANON_NUM;
}


1;
