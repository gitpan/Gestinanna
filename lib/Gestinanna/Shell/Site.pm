package Gestinanna::Shell::Site;

use Gestinanna::Schema;
use Gestinanna::Shell::Base;

@ISA = qw(Gestinanna::Shell::Base);

%EXPORT_COMMANDS = (
    site => \&do_site,
    sites => \&do_list,
);

%COMMANDS = (
    create => \&do_create,
    select => \&do_select,
    delete => \&do_delete,
    list => \&do_list,
    uri => \&Gestinanna::Shell::Site::URI::do_uri,
    '?' => \&do_help,
);

sub do_help {
    my($shell, $prefix, $arg) = @_;

    print "The following commands are available for `site': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;
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
            print <<1HERE1;
No site is currently selected.  Use `site select <site>' to select a 
site or `site create' to create a new site.
1HERE1
        }
    }
}

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<1HERE1;
sites; site list

This will list the available sites known to Gestinanna.
1HERE1
        return;
    }

    my @sites = ( );
    my $table = $shell -> {alzabo_schema} -> {runtime_schema} -> Site;
    my $cursor = $table -> all_rows(order_by => $table -> column("site"));
    my $string = '';
    my $site;
    $string .= join("\t", $site -> site, $site -> name) . "\n"
        while $site = $cursor -> next;
    __PACKAGE__ -> page($string);
}

sub do_create {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help


        print <<1HERE1;
site create <name>

This will create a new site with the name <name>.

See also: site select
1HERE1
        return 1;
    }

    my $site = $shell -> {alzabo_schema} -> {runtime_schema} -> Site -> insert(
        values => {
            name => $arg,
        },
    );

    print "New site: ", $site -> site, "\t", $site -> name, "\n";
}

sub do_delete {
    my($shell, $prefix, $arg) = @_;
    
    if($arg =~ /\?$/) {
        print <<1HERE1;
site delete

This will remove the site from the database.  This will also 
delete any dependent information.
1HERE1
        return 1;
    }

    my $site = $shell -> {alzabo_schema} -> {runtime_schema} -> Site -> row_by_pk(pk => $shell -> {site} -> {site});

    return unless $site;

    $site -> delete;

    print "Site deleted\n";
    delete $shell -> {site};
}

sub do_select {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<1HERE1;
site select <site name|site number>

This will select the site for further processing.
1HERE1
        return 1;
    }

    my $site;
    if($arg =~ /^\d+$/) {
        # select by number
        $site = $shell -> {alzabo_schema} -> {runtime_schema} -> Site -> row_by_pk(pk => $arg);
    } 
    else {
        $site = $shell -> {alzabo_schema} -> {runtime_schema} -> Site -> one_row(
            where => [
                $shell -> {alzabo_schema} -> {runtime_schema} -> Site -> column("name"),
                '=',
                $arg
            ],
        );
    }
    return unless $site;

    $shell -> {site} -> {name} = $site -> name;
    $shell -> {site} -> {site} = $site -> site;
    print "Site set to: (", $site -> site, ") ", $site -> name, "\n";
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
#            print <<1HERE1;
#No site is currently selected.  Use `site select <site>' to select a
#site or `site create' to create a new site.
#1HERE1
#        }
#    }
}

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<1HERE1;
site uri list

Lists all the uri to filename mappings for the selected site.
1HERE1
        return;
    }

    my $cursor = $shell->{alzabo_schema} -> {runtime_schema} -> Uri_Map -> rows_where(
        where => [
            $shell->{alzabo_schema} -> {runtime_schema} -> Uri_Map -> column("site"), '=', $shell -> {site} -> {site}
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
        print <<1HERE1;
site uri add <uri> <filename>

Adds the uri to filename mapping.
1HERE1
        return;
    }

    my($uri, $file) = split(/\s+/, $arg, 2);

    $uri = "/$uri" if $uri !~ m{^/};

    my $u = $shell -> {alzabo_schema} -> {runtime_schema} -> Uri_Map -> insert(
        values => {
            site => $shell -> {site} -> {site},
            uri => $uri,
            file => $file,
        },
    );
}

sub do_delete {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<1HERE1;
site uri delete <uri>; site uri delete <filename>

This will delete either the uri or all uris associated with a 
filename.  Uris should start with a forward slash (/) to 
distinguish them from file names.
1HERE1
        return;
    }

    if($arg =~ m{^/}) {
        my $u = $shell -> {alzabo_schema} -> {runtime_schema} -> Uri_Map -> row_by_pk(
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
        my $cursor = $shell -> {alzabo_schema} -> {runtime_schema} -> Uri_Map -> rows_where(
            where => [
                [ $shell->{alzabo_schema} -> {runtime_schema} -> Uri_Map -> column("site"), '=', $shell -> {site} -> {site} ],
                [ $shell->{alzabo_schema} -> {runtime_schema} -> Uri_Map -> column("file"), '=', $arg ],
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
