package Gestinanna::Shell::Package;

use File::Spec;
use Gestinanna::Schema;
use Gestinanna::Shell::Base;
use Gestinanna::Package;
use Gestinanna::PackageManager;
use Archive::Tar::File;

#use strict;
#use vars qw(@ISA %EXPORT_COMMANDS %COMMANDS);

@ISA = qw(Gestinanna::Shell::Base);

%EXPORT_COMMANDS = (
    package => \&do_package,
    packages => \&do_list_packages,
);

%COMMANDS = (
#    recommend => \&do_recommend,
    create => \&do_create,
    list => \&do_list,
#    load => \&do_load,
#    get => \&do_get,  # fetch from package database (configurable)
#    submit => \&do_submit, # upload a local package (must authenticate to remote site)
#    update => \&do_update, # compare local packages with package database and update (but not load)
    '?' => \&do_help,
    open => \&do_open,
    set => \&do_set,
#    add_tagged => \&do_add_tagged,
    write => \&do_write,
#    close => \&do_close,
    clear => \&do_clear,
    install => \&do_install,
    activate => \&do_activate,
#    deactivate => \&do_deactivate,
    edit => \&do_edit,   # edit/add file to package
    delete => \&do_delete,   # delete file from package
    view => \&do_view,
    store => \&do_store,
);

# variables used:
#  package_dir : ./packages   (for now)
#     this is the place we store packages for installation

sub do_help {
    my($shell, $prefix, $arg) = @_;

    print "The following commands are available for `package': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;
}

my(@variables) = sort(qw(
    name
    type
    version
    author_name
    author_email
    author_url
    update_url
    url
    support_email
    devel_email
));

sub do_set {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        my $vars = join("\n    ", @variables);

        print <<EOF;
package set <variable> <value>

Sets the corresponding variable in the current package.

The following variables are available:
    $vars

See also: package open; package create.
EOF
        return 1;
    }

    my $package = _get_package($shell);
    return unless $package;

    # set variable
    # re-write conf file in repository
    my($var, $val) = split(/\s/, $arg, 2);

    return unless grep { $var eq $_ } @variables;

    warn "Setting $var to $val\n";
    $package -> $var($val);
    $package -> write_configuration;
}

sub do_package {
    my($shell, $prefix, $arg) = @_;

    #if($arg =~ /\?$/) {
    #    return do_help($shell, $prefix, $arg);
    #}

    if($arg !~ /^\s*$/) {
        return __PACKAGE__ -> interpret($shell, $prefix, $arg);
    } 

    if($shell -> {_package}) {
        print "Current package: ", join(" ", $shell -> {_package} -> type, $shell -> {_package} -> name, $shell -> {_package} -> version), "\n";
    }
    else {
        print "There is no current package.\n";
    }
}

sub _get_package_manager {
    my $self = shift;

    return Gestinanna::PackageManager -> new(
        directory => ($Gestinanna::Shell::VARIABLES{package_dir} || File::Spec -> catdir(File::Spec -> curdir, 'packages')),
    );
}

=begin testing

# do_list_packages

shell_command_ok("set package_dir packages");
my $list = shell_command_ok("packages");

my @bits = split(/\n/, $list);
my %packages;
my $type;
while(@bits) {
    my $bit = shift @bits;
    if($bit =~ s{^\s+}{}) {
        next unless defined $type;
        my($pkg, $v) = split(/\s+/, $bit, 2);
        $packages{$type}{$pkg} = $v;
    }
    else {
        next unless defined $bit && length($bit) > 2;
        $type = substr($bit, 0, length($bit)-1);
    }
}

is($packages{'application'}{'base'}, '0.04');

=end testing

=cut

sub do_list_packages {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
packages

This will list the available packages known to Gestinanna.

See also: package list.
EOF
        return;
    }

    # assume './packages' for now
    my $pm = _get_package_manager($shell);

    my @types = $pm -> types;

    my %packages;
    foreach my $type (@types) {
        my $p = $pm -> packages($type);
        $packages{$type} = $p if defined $p;
    }

    my $string = '';

    foreach my $type (sort keys %packages) {
        $string .= "$type:\n";
        foreach my $package (sort keys %{$packages{$type}}) {
            next if ref $packages{$type}{$package};
            $string .= "  $package\t$packages{$type}{$package}\n";
        }
        $string .= "\n";
    }

    $shell -> page($string);
}

sub do_install {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help

        print <<EOF;
package install <type> <name>

This will install the package in the repository and tag it with the 
type, name, and version number of the package.

For example, if the following is available from the `packages' command:

 theme:
   foo  1.04

then `package install theme foo' will result in a set of objects added 
to the repository with the revisions tagged as `theme-foo-1.04'.

See: packages; package list
EOF
        return 1;
    }

    my($type, $name) = split(/\s/, $arg);

    my $pm = _get_package_manager($shell);

    my $package = $pm -> load($type, $name);

    if(!$package) {
        warn "Unable to find $type $name\n";
        return;
    }

    my $factory = $shell -> {site} -> {site_config} -> factory -> new(_factory => (
        alzabo_schema => $shell -> {alzabo_schema} -> {runtime_schema}
    ));

    $package -> install( $factory );

    # now handle security
    my $security = $package -> security_struct;
}

=begin testing

# do_create

# tests the full package creation through to write and then deletes the package

shell_command_ok("package create application gst_testing 0.$$");

my $pkg = shell_command_ok("package");

my @bits = split(/\s+/, $pkg);
is($bits[2], 'application');
is($bits[3], 'gst_testing');
is($bits[4], "0.$$");

my $manifest = shell_command_ok("package view MANIFEST");

my $list = shell_command_ok("package list");

ok(eq_set([ split(/\n/, $manifest) ], [ split(/\n/, $list) ]));

=end testing

=cut

sub do_create {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help

        print <<EOF;
package create <type> <name> <version>

This will create a new package for further processing.

The <type> should be application or theme.

See also: package open.
EOF
        return 1;
    }

    my($type, $name, $version) = split(/\s/, $arg, 3);

    my $pm = _get_package_manager($shell);

    my $package;
    if($pm) {
        # pulls in all the config file contents so we don't have to re-enter them
        my $old_package = $pm -> load($type, $name);
        if($old_package) {
            $package = $old_package -> new(
                version => $version
            );
        }
        else {
            $package = Gestinanna::Package -> new(
                name => $name,
                type => $type,
                version => $version
            );
            $package -> type($type);
        }
    }
    else {
        $package = Gestinanna::Package -> new(
            name => $name,
            type => $type,
            version => $version
        );
        $package -> type($type);
    }

    $shell -> {_package} = $package;
    return 1;
}

=begin testing

# do_open

shell_command_ok("package open application base");

=end testing

=cut

sub do_open {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
package open <type> <name>

This will open for further processing the most recent locally stored 
version of an existing package.

See also: package create.
EOF
        return 1;
    }

    my($type, $name, $version) = split(/\s/, $arg, 3);
    my $pm = _get_package_manager($shell);

    my $package;
    if($version) {
        $package = $pm -> load($type, $name, $version);
    }
    else {
        $package = $pm -> load($type, $name);
    }

    if(!$package) {
        die "Unable to find $type $name\n";
        return;
    }

    $shell -> {_package} = $package;
}

sub _get_package {
    my $shell = shift;

    if(!$shell -> {_package}) {
        print <<EOF;
There is no current package.  Please create or open a package using
`package create' or `package open.'
EOF
        return;
    }

    return $shell -> {_package};
}

=begin testing

# do_list

my $list = shell_command_ok("package list");

our %files = map { $_ => 1 } split(/\n/, $list);

ok($files{'conf/package.conf'}, "conf/package.conf exists");
ok($files{'MANIFEST'}, "MANIFEST exists");

=end testing

=cut

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
package list

This will list the contents of the current package.

See also: packages.
EOF
        return 1;
    }

    my $package = _get_package($shell);

    return unless $package;

    my @files = $shell -> {_package} -> list_files;

    $shell -> page(join("\n", sort @files));
}

sub do_edit {
    my($shell, $prefix, $arg) = @_;

    # only repository/ items may be edited
    # .xslt, .xsm files are checked by trying to parse them
    if($arg =~ /\?$/) {
        print <<EOF;
package edit <filename>.<type>

This will edit an already existing file or create a new file in the 
current package.  If the file is of type xslt or xsm, then the file 
will be parsed to ensure it is correctly formed XML.

See also: package view, package delete.
EOF
       return 1;
    }

    my $package = _get_package($shell);
    return unless $package;

    my $file = $arg;
    my $type;
    my $content;
    if(lc $file eq 'readme' || lc $file eq 'changes') {
        $file = uc $file;
        $type = '';
        $content = $package -> get_content($file);
    }
    elsif($file eq 'description' || $file eq 'notes') {
        $type = '';
        $content = $package -> $file;
    }
    elsif($file eq 'security' || $file eq 'urls' || $file eq 'embeddings') {
        $type = 'xml';
        $content = $package -> $file;
        $content =~ s{^\s*<$file>\s*}{}s;
        $content =~ s{\s*</$file>\s*$}{}s;
    }
    elsif($file !~ m{^repository/}) {
        warn "Only able to edit files under repository/.\n";
        return 1;
    }
    elsif($file !~ m{^repository/(.*)\.([^.]+)$}) {
        warn "Unable to edit a folder ($file).\n";
        return 1;
    }
    else {
        $file = $1;
        $type = $2;
        $content = $package -> get_content("repository/${file}.${type}");
    }

    my $new_content;
    if($type eq 'xsm' || $type eq 'xslt' || $type eq 'xml') {
        $new_content = $shell -> edit_xml($content);
    }
    else {
        $new_content = $shell -> edit($content);
    }

    if($new_content eq $content) {
        warn "No changes.\n";
        return;
    }
    if($file eq 'README' || $file eq 'CHANGES') {
        $package -> add_file(lc $file, $new_content);
    }
    elsif($file eq 'description' || $file eq 'notes') {
        $package -> $file($new_content);
        $package -> write_configuration;
    }
    elsif($file eq 'security' || $file eq 'urls' || $file eq 'embeddings') {
        $new_content = "<$file>\n$new_content\n</$file>";
        $package -> $file($new_content);
        $package -> write_configuration;
    }
    else {
        $package -> add_file('repository', $type, $file, $new_content);
    }
}

=begin testing

# do_view

my $manifest = shell_command_ok("package view MANIFEST");

ok(eq_set([ keys %files ], [ split(/\n/, $manifest) ]));

=end testing

=cut

sub do_view {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
package view <filename>.<type>

This will view an already existing file in the current package.
    
See also: package edit, package delete.
EOF
       return 1;
    }

    my $package = _get_package($shell);
    return unless $package;

    if($arg =~ m{^/image/}) {
        warn "Unable to view images.\n";
        return 1;
    }

    my $content = $package -> get_content($arg);

    return unless defined $content;

    $shell -> page($content);
}

=begin testing

# do_write

shell_command_ok("package create application gst_testing 0.$$");

shell_command_ok("package write"); 

my $filename = File::Spec -> catfile(qw(packages application), "gst_testing-0.$$.tgz");
      
ok(-e $filename && -f _ && -r _, "Tarball created and readable: $filename");

shell_command_ok("package open application gst_testing");
            
$pkg = shell_command_ok("package");
          
@bits = split(/\s+/, $pkg);
is($bits[2], 'application');
is($bits[3], 'gst_testing');
is($bits[4], "0.$$");
    
unlink $filename;

=end testing

=cut

sub do_write {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
package write

This will write the current package out to a file.  The name of the 
file is <type>/<name>-<version>.tgz.  If compression is not available, 
then it is not compressed and the .tar extension is used instead.

Compressed packages may have either the .tgz or .tar.gz extension, but 
for compatibility with MS Windows, only the .tgz extension is used 
when writing new packages.

See also: package create, package open.
EOF
        return 1;
    }

    my $package = _get_package($shell);
    my $pm = _get_package_manager($shell);
    return unless $package;

    $pm -> write($package);
}

sub do_activate {
    my($shell, $prefix, $arg) = @_;

#    unless($arg =~ /\?$/ || $shell -> {site} -> {name}) {
#        print "No site has been selected.  Please select a site.  See `site select'.\n";
#        return;
#    }

    if($arg =~ m{\?$}) {
        print <<EOF;
package activate <type> <name> {urls|embeddings|security}

Activates a package for the currently selected site.  The package 
should already be installed.  This will install the uri mappings and 
other site-specific information.

If no site is selected, then activation is done for *all* sites within 
the schema.

See also: package install, site select.
EOF

        return;
    }

    my $pm = _get_package_manager($shell);

    my($type, $name, $part) = split(/\s/, $arg, 3);
    
    my $package = $pm -> load($type, $name);
    unless($package) {
        print <<EOF;
Unable to find the package $arg.
EOF
        return;
    }

    my($site_number, $site_name) = (0, 'all sites');
    if($shell -> {site}) {
        $site_number = $shell -> {site} -> {site};
        $site_name   = $shell -> {site} -> {name};
    }

    my $doc = '';
    my $preamble = '';

    if($part eq 'urls') {
        $preamble = <<EOF;
Url mappings for site $site_number ($site_name).

The following objects need urls.  To accept the default values, simply
exit your editor without making any changes.  Only objects that are in
this package and marked as needing urls will be accepted.  All other
objects will be ignored.

Urls ending in /* are understood to accept anything in place of the
asterisk (*) as extra path information or as a virtual directory
structure.

Urls are relative to the location of the site but do have a leading
slash (/).
EOF

        my $uris = $package -> url_struct;

        foreach my $uri (keys %$uris) {
            $doc .= join(":", @{$uris -> {$uri}})   
                 .  "\t$uri\n";
        }
        chomp $doc;
    }
    elsif($part eq 'embeddings') {
        # now need to handle embeddings - these aren't installer editable

        $preamble = <<EOF;
Embeddings for site $site_number ($site_name).

Objects referenced using urls that match the following paths will be 
embedded within the object associated with that path.  Paths which 
match more objects embed paths which match fewer objects and are 
contained within the more-inclusive path.

To accept the default values, simply exit your editor without making 
any changes.  Only objects that are in this package and marked as 
allowing embedding will be accepted.  All other objects will be ignored.

Paths are in an XPath-like syntax.  For example, //*/ matches any 
directory-like url.  //* matches any document-like url.  The 
combination `//*/ | //*' matches both.  Use literal names to match 
literal parts of the url.  For example, `/news//* | /news//*/' will 
match any url beginning with /news/, directory or document.

Paths are relative to the location of the site but do have a leading
slash (/).  Paths match the urls, not the object names.  See the url 
mapping for information on how urls map to objects.
EOF

        my $struct = $package -> embedding_struct;
        my $theme;
        if($package -> type eq 'theme') {
            $theme = $package -> name;
        }
        else {
            $theme = '*';
        }

        if($theme eq '*' && keys %$struct) {
            foreach my $uri (keys %$struct) {
                $doc .= "$uri\t"
                     .  join(":", @{$struct -> {$uri}}) . "\n";
            }
        }
        else {
            foreach my $uri (keys %$struct) {
                $doc .= "$uri\t"
                     .  join(":/theme/$theme", @{$struct -> {$uri}}) . "\n";
            }
        }
        chomp $doc;

    }
    elsif($part eq 'security') {
        $preamble = <<EOF;
Security recommendations.

Security recommendations affect all sites and may not be restricted by 
site.
EOF

        my $sec = $package -> security_struct;
        #$doc = Data::Dumper -> Dump([ $sec ]);
        #$doc .= "\n" . $package -> security;
        foreach my $rt (keys %{$sec -> {attributes}}) {
            foreach my $rid (keys %{$sec -> {attributes}{$rt} || {}}) {
                foreach my $ut (keys %{$sec -> {attributes}{$rt}{$rid}||{}}) {
                    foreach my $uid (keys %{$sec -> {attributes}{$rt}{$rid}{$ut}||{}}) {
                        foreach my $attr (keys %{$sec -> {attributes}{$rt}{$rid}{$ut}{$uid}||{}}) {
                            $doc .= "$rt:$rid\t$ut:$uid\t$attr=" . $sec -> {attributes}{$rt}{$rid}{$ut}{$uid}{$attr}
                                 . "\n";
                        }
                    }
                }
            }
        }
    }
    else {
        print "Unknown part to activate.\n";
        return;
    }

    my $new_uri_doc = $shell -> edit(<<EOF);
$preamble
===========================================================================
$doc
EOF

    $new_uri_doc =~ s{^.*={75}\s*}{}s;

    my $new_struct = { };

    my @lines = split(/\n/, $new_uri_doc);

    if($part eq 'urls') {
        foreach my $line (@lines) {
            my($ob, $uri) = split(/\t/, $line);
            my($type, $id) = split(/:/, $ob);
            $new_struct -> {$uri} = [ $type, $id ];
        }

        # need to insert these into the Uri_Map table
        my $table = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Uri_Map");

        foreach my $uri (keys %$new_struct) {
            my $uri_r = $table -> row_by_pk(
                pk => {
                    site => $site_number,
                    uri => $uri,
                },
            );
            if($uri_r) {
                $uri_r -> update(
                    type => $new_struct -> {$uri} -> [0],
                    file => $new_struct -> {$uri} -> [1],
                );
            }
            else {
                $table -> insert(
                    values => {
                        site => $site_number,
                        uri => $uri,
                        type => $new_struct -> {$uri} -> [0],
                        file => $new_struct -> {$uri} -> [1],
                    }
                );
            }
        }
    }
    elsif($part eq 'embeddings') {
        my $theme;
        if($package -> type eq 'theme') {
            $theme = $package -> name;
        }
        else {      
            $theme = '*';
        }     

        foreach my $line (@lines) {
            my($path, $ob) = split(/\t/, $line);
            my($type, $id) = split(/:/, $ob);
            $new_struct -> {$path} = [ $type, $id ];
        }

        # need to make sure type:id is in the original list
        $struct = $new_struct;

        $table = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Embedding_Map");

        # need to edit if an application since paths may change

        # need to remove any old theme embeddings if theme is not *
        if($theme ne '*') {
            my $rows = $table -> rows_where(
                where => [
                    [ $table -> column('site'), '=', $site_number ],
                    [ $table -> column('theme'), '=', $theme ],
                ]
            );
            my $row;
            while($row = $rows -> next) {
                $row -> delete;
            }
        }

        foreach my $path (keys %$struct) {
            my $embedding = $table -> row_by_pk(
                pk => {
                    site => $site_number,
                    path => $path,
                    theme => $theme,
                },
            );
            if($embedding) {
                $embedding -> update(
                    type => $struct -> {$path} -> [0],
                    file => $struct -> {$path} -> [1],
                );
            }
            else {
                $table -> insert(
                    values => {
                        theme => $theme,
                        site => $site_number,
                        path => $path,
                        type => $struct -> {$path} -> [0],
                        file => $struct -> {$path} -> [1],
                    }
                );
            }
        }
    }
    elsif($part eq 'security') {
        my $table = $shell -> {alzabo_schema} -> {runtime_schema} -> table("Attribute");
        foreach my $line (@lines) {
            my($resource, $user, $pair) = split(/\s+/, $line, 3);
            my($rt, $rid) = split(/:/, $resource, 2);
            my($ut, $uid) = split(/:/, $user, 2);
            my($attr, $v) = split(/=/, $pair, 2);
            $table -> insert(
                values => {
                    resource_type => $rt,
                    resource_id => $rid,
                    user_type => $ut,
                    user_id => $uid,
                    attribute => $attr,
                    value => $v,
                },
            );
        }
    }

    if($part ne 'security') {
        my $tag = join("-", $package -> type, $package -> name, $package -> version);
        my $package_type = $package -> type;

        if($site_number) {
            print <<EOF;
You may need to add the following tag to the <tagpath/> configuration 
section for this site:

    $tag
EOF
        }
        else {
            print <<EOF;
You may need to add the following tag to the <tagpath/> configuration 
section for each site which needs this $package_type:

    $tag
EOF
        }
    }
}

sub do_clear {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
package clear

This will clear out all the contents of the package except the 
configuration file, which is rewritten to the new archive.

See also: package create, package delete.
EOF
        return 1;
    }

    my $package = _get_package($shell);
    return unless $package;

    $package = $package -> new;
    $package -> create; # does the same thing, pretty much - except recreates the conf file
    $shell -> {_package} = $package;
}

sub do_store {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
package store <package>

This will copy the package to the package store for installation.

See also: package install.
EOF
        return 1;
    }

    my $pm = _get_package_manager($shell);

    $pm -> store($arg);
}

1;

__END__
