package Gestinanna::Shell::Site;

use Gestinanna::SchemaManager;
use Gestinanna::Shell::Base;
use XML::LibXML;

@ISA = qw(Gestinanna::Shell::Base);

%EXPORT_COMMANDS = (
    site => \&do_site,
    sites => \&do_list,
);

%COMMANDS = (
    create => \&do_create,
    clone => \&do_clone,
    select => \&do_select,
    delete => \&do_delete,
    list => \&do_list,
    uri => \&Gestinanna::Shell::Site::URI::do_uri,
    config => \&do_config,
    '?' => \&do_help,
);

sub do_help {
    my($shell, $prefix, $arg) = @_;

    print "The following commands are available for `site': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;
}

sub do_config {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
EOF
        return 1;
    }
    elsif(!defined $shell -> {site}) {
        print <<EOF;
No site is currently selected.  Use `site select <site>' to select a 
site or `site create' to create a new site.
EOF
        return 1;
    }

    my $config = $shell -> {site} -> {configuration};

    my $new_config = $shell -> edit_xml($config);


    if($new_config eq $config) {
        print "Configuration unchanged.\n";
        return 1;
    }

    my $site = $shell -> {alzabo_schema} -> {runtime_schema} -> table('Site') -> row_by_pk( pk => $shell -> {site} -> {site} );
    $site -> update(
        configuration => $new_config
    );
    $shell -> {site} -> {configuration} = $new_config;
    load_site_config($shell);
}

sub do_site {
    my($shell, $prefix, $arg) = @_;

    unless($arg =~ /\?$/ || defined $shell -> {alzabo_schema} -> {runtime_schema}) {
        warn "No schema has been loaded.  Use `schema load <schema>' first.\n";
        return;
    }

    if($arg !~ /^\s*$/) {
        return __PACKAGE__ -> interpret($shell, $prefix, $arg);
    } 
    else {
        if($shell -> {site} -> {name}) {
            print "Current site: (", $shell -> {site} -> {site}, ") ", $shell -> {site} -> {name}, "\n";
        }
        else {
            print <<EOF;
No site is currently selected.  Use `site select <site>' to select a 
site or `site create' to create a new site.
EOF
        }
    }
}

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
sites; site list

This will list the available sites known to Gestinanna.
EOF
        return;
    }

    my @sites = ( );
    my $table = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site");
    my $cursor = $table -> all_rows(order_by => $table -> column("site"));
    my $string = '';
    my $site;
    $string .= join("\t", $site -> select(qw(site name))) . "\n"
        while $site = $cursor -> next;
    __PACKAGE__ -> page($string);
}

sub do_clone {
    my($shell, $prefix, $arg) = @_;

    unless($arg =~ /\?$/ || $shell -> {site} -> {name}) {
        print "No site has been selected.  Please select a site.  See `site select'.\n";
        return;
    }
     
    if($arg =~ /\?$/) {
        print <<EOF;
site clone <name>

This will create a new site with the name <name> and the configuration 
copied from the currently selected site.  Any uri mappings and 
embeddings specific to the currently selected site will also be copied 
to the new site.

See also: site create, site select
EOF
        return 1;
    }

    my $site = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> insert(
        values => {
            name => $arg,
            configuration => '<configuration/>',
            parent => $shell -> {site} -> {site},
        },
    );

    unless($site -> is_live) {
        die "Unable to create site.\n";
        return;
    }

    print "New site: ", $site -> site, "\t", $site -> name, "\n";
}

sub do_create {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help


        print <<EOF;
site create <name>

This will create a new site with the name <name>.

See also: site select
EOF
        return 1;
    }

    

    $shell -> {alzabo_schema} -> {runtime_schema} ->set_referential_integrity(0);
    my $site = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> insert(
        values => {
            name => $arg,
            configuration => '<configuration/>',
            parent_site => 0,
        },
    );

    unless($site -> is_live) {
        die "Unable to create site.\n";
        return;
    }
    $shell -> {alzabo_schema} -> {runtime_schema} ->set_referential_integrity(1);

    my $site_number = $site -> select('site');
    my $schema_name = $shell -> {alzabo_schema} -> {runtime_schema} -> name;
    my $driver_name = $shell -> {alzabo_schema} -> {runtime_schema} -> driver -> driver_id;

    $site -> update(
        configuration => <<EOXML,
<configuration
  package="Gestinanna::Sites::${schema_name}::Site_${site_number}"
>
  <tagpath>
    <production>
      <tag>production_tag</tag>
    </production>
  </tagpath>
  <themes default="_default">
    <theme id="_default"/>
  </themes>
  <session>
    <cookie name="SESSION_ID"/>
    <store
      store="${driver_name}"
      lock="${driver_name}"
      generate="MD5"
      serialize="Storable"
    />
  </session>

  <data-type id="alzabo" class="Gestinanna::POF::Alzabo"/>
  <data-type id="ldap"   class="Gestinanna::POF::LDAP"/>
  <data-type id="repository" class="Gestinanna::POF::Repository"/>

  <security-type id="read-write" class="Gestinanna::POF::Secure::Gestinanna"/>
  <security-type id="read-only" class="Gestinanna::POF::Secure::ReadOnly"/>

  <content-type id="tt2" class="Gestinanna::ContentProvider::TT2"/>
  <content-type id="xsm" class="Gestinanna::ContentProvider::XSM"/>
  <content-type id="portal" class="Gestinanna::ContentProvider::Portal"/>
  <content-type id="document" class="Gestinanna::ContentProvider::document"/>

  <content-provider
    type="document"
    content-type="document"
  />
  <content-provider
    type="xslt"
    content-type="document"
  />

  <!--
     provides content of type xsm
     default data provider is `xsm'
     base class is Gestinanna::ContentProvider::XSM
     uses views from the `view' content provider
     uses data provider `context' to manage contexts
     caches compiled xsm in /data/gestinanna/${schema_name}/site_${site_number}
    -->
  <content-provider
    type="xsm"
    content-type="xsm"
    view-type="view"
    context-type="context"
  > 
    <config>
      <cache dir="/data/gestinanna/${schema_name}/site_${site_number}"/>
      <taglib class="Gestinanna::XSM::Auth"/>
      <taglib class="Gestinanna::XSM::Authz"/>
      <taglib class="Gestinanna::XSM::ContentProvider"/>
      <taglib class="Gestinanna::XSM::Diff"/>
      <taglib class="Gestinanna::XSM::Digest"/>
      <taglib class="Gestinanna::XSM::Gestinanna"/>
      <taglib class="Gestinanna::XSM::POF"/>
      <taglib class="Gestinanna::XSM::StateMachine"/>
      <taglib class="Gestinanna::XSM::Script"/>
      <taglib class="Gestinanna::XSM::SMTP"/>
    </config>
  </content-provider>

  <!--
     provides content of type view
     default data provider is `view'
     base class is Gestinanna::ContentProvider::TT2
    -->
  <content-provider
    type="view"
    content-type="tt2"
  />

  <content-provider
    type="portal"
    content-type="portal"
  />
    
  <!--
     provides data of type xsm
     stores the data in a repository
     the base name for the repository tables is XSM
     uses read-write security
    -->
  <data-provider
    type="xsm"
    data-type="repository"
    repository="XSM"
    description="eXtensible State Machine"
    security="read-write"
  />
  <data-provider
    type="document"
    data-type="repository"
    repository="Document"
    description="Document"
    security="read-write"
  />
  <data-provider
    type="portal"
    data-type="repository"
    repository="Portal"
    description="Portal"
    security="read-write"
  />
  <data-provider
    type="view"
    data-type="repository"
    repository="View"
    description="View"
    security="read-write"
  />
      
  <!--
     provides data of type context
     stores data in an RDBMS table using Alzabo
     uses the table named Context
    -->
  <data-provider
    type="context"
    data-type="alzabo"
    table="Context"
  />
       
  <data-provider   
    type="site"
    data-type="alzabo"
    table="Site"
  />
  <data-provider   
    type="uri-map"
    data-type="alzabo"
    table="Uri_Map"
  />
  <data-provider
    type="user"
    data-type="alzabo"
    table="User"
    security="read-write"
  />   
  <!-- an actor is a read-only user object, basicly -->
  <data-provider
    type="actor"
    data-type="alzabo"
    table="User"
    security="read-only"
  />
      
  <data-provider
    type="username"
    data-type="alzabo"
    table="Username"
    security="read-write"
  />
  <data-provider
    type="xslt"
    data-type="repository"
    repository="XSLT"
    description="XSLT"
    security="read-write"
  />
  <data-provider
    type="folder"
    data-type="alzabo"
    table="Folder"
    security="read-write"
  />
</configuration>
EOXML
    );

    print "New site: ", $site -> select('site'), "\t", $site -> select('name'), "\n";
}

sub do_delete {
    my($shell, $prefix, $arg) = @_;
    
    if($arg =~ /\?$/) {
        print <<EOF;
site delete

This will remove the site from the database.  This will also 
delete any dependent information.
EOF
        return 1;
    }

    my $site = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> row_by_pk(pk => $shell -> {site} -> {site});

    return unless $site;

    $site -> delete;

    print "Site deleted\n";
    delete $shell -> {site};
}

sub do_select {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
site select <site name|site number>

This will select the site for further processing.
EOF
        return 1;
    }

    my $site;
    if($arg =~ /^\d+$/) {
        # select by number
        $site = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> row_by_pk(pk => $arg);
    } 
    else {
        $site = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> one_row(
            where => [
                $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> column("name"),
                '=',
                $arg
            ],
        );
    }
    return unless $site;

    
    $shell -> {site} -> {name} = $site -> select('name');
    $shell -> {site} -> {site} = $site -> select('site');
    $shell -> {site} -> {configuration} = $site -> select('configuration');
    load_site_config($shell); # handles parent configs as well
    print "Site set to: (", $site -> select('site'), ") ", $site -> select('name'), "\n";
}

sub load_site_config {
    my($shell) = @_;

    my @parents;
    my $s = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> row_by_pk(pk => $shell -> {site} -> {site});
    push @parents, $s;
    while($s -> select('parent_site')) {
        $s = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Site") -> row_by_pk(pk => $s -> select('parent_site'));
        push @parents, $s;
    }
    my $sc;
    while(@parents) {
        my $s = pop @parents;
        $sc = Gestinanna::SiteConfiguration -> new(site => $s -> select('site'), parent => $sc);
        $sc -> parse_config($s -> select('configuration'));
    } 
    $shell -> {site} -> {site_config} = $sc;
    $sc -> build_factory;
}

package Gestinanna::Shell::Site::URI;

@ISA = qw(Gestinanna::Shell::Base);

%COMMANDS = (
    delete => \&do_delete,
    add => \&do_add,
    list => \&do_list,
    uri => \&Gestinanna::Shell::Site::URI::do_uri,
    '?' => \&do_help,  
);
    
sub do_help {
    my($shell, $prefix, $arg) = @_;
        
    print "The following commands are available for `site uri': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;                                                                                                                  
}
    
sub do_uri {
    my($shell, $prefix, $arg) = @_;

    unless($arg =~ /\?$/ || $shell -> {site} -> {name}) {
        print "No site has been selected.  Please select a site.  See `site select'.\n";
        return;
    }

    if($arg !~ /^\s*$/) {
        return __PACKAGE__ -> interpret($shell, $prefix, $arg);
    }
#    else {
#        if($shell -> {site} -> {name}) {
#            print "Current site: ", $shell -> {site} -> {name}, "\n";
#        }
#        else {
#            print <<EOF;
#No site is currently selected.  Use `site select <site>' to select a
#site or `site create' to create a new site.
#EOF
#        }
#    }
}

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
site uri list

Lists all the uri to filename mappings for the selected site.
EOF
        return;
    }

    my $cursor = $shell->{alzabo_schema} -> {runtime_schema} -> table("Uri_Map") -> rows_where(
        where => [
            $shell->{alzabo_schema} -> {runtime_schema} -> table("Uri_Map") -> column("site"), '=', $shell -> {site} -> {site}
        ]
    );

    my $string = '';
    my $u;
    $string .= join("\t", $u->uri, $u -> file) . "\n"
        while $u = $cursor -> next;
    __PACKAGE__->page($string);
}

sub do_add {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
site uri add <uri> <type> <filename>

Adds the uri to filename mapping.
EOF
        return;
    }

    my($uri, $type, $file) = split(/\s+/, $arg, 3);

    $uri = "/$uri" if $uri !~ m{^/};

    my $u = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Uri_Map") -> insert(
        values => {
            site => $shell -> {site} -> {site},
            uri => $uri,
            file => $file,
            type => $type,
        },
    );
}

sub do_delete {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
site uri delete <uri>; 
site uri delete <filename>; site uri delete <type> <filename>

This will delete either the uri or all uris associated with a 
filename.  Uris should start with a forward slash (/) to 
distinguish them from file names.
EOF
        return;
    }

    if($arg =~ m{^/}) {
        my $u = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Uri_Map") -> row_by_pk(
            pk => {
                site => $shell -> {site} -> {site},
                uri => $arg,
            },
        );
        return unless $u;
        print "deleting ", $u -> uri, "\n";
        $u -> delete;
    }
    else {
        my($type, $file) = split(/\s+/, $arg, 2);
        ($type, $file) = (undef, $file) if $file =~ m{^\s*$};
        my $table = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Uri_Map");
        my $cursor = $table -> rows_where(
            where => [
                [ $table -> column("site"), '=', $shell -> {site} -> {site} ],
                [ $table -> column("file"), '=', $file ],
                ( (defined $type) ? ( [ $table -> column("type"), '=', $type ] ) : () ),
            ],
        );
        my $u;
        while($u = $cursor -> next) {
            print "deleting ", $u -> uri, "\n";
            $u -> delete;
        }
    }
}

1;

__END__

=head1 NAME  
        
Gestinanna::Shell::Site - site commands
        
=head1 SYNOPSIS
        
 perl -MGestinanna -e shell
         
=head1 DESCRIPTION

This module defines all the C<site> commands in the Gestinanna shell.

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
