package Gestinanna::Shell::Schema;

use Alzabo::Config;
use Alzabo::Create;
use Alzabo::Driver;
use File::Spec;
use Gestinanna::Schema;
use Gestinanna::Shell::Base;
use YAML ();

@ISA = qw(Gestinanna::Shell::Base);

%EXPORT_COMMANDS = (
    schema => \&do_schema,
    schemas => \&do_list,
);

%COMMANDS = (
    load => \&do_load,
    create => \&do_create,
    docs => \&do_docs,
    delete => \&do_delete,
    drop => \&do_drop,
    list => \&do_list,
    upgrade => \&do_upgrade,
    '?' => \&do_help,
);

sub do_help {
    my($shell, $prefix, $arg) = @_;

    print "The following commands are available for `schema': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;
}

sub do_schema {
    my($shell, $prefix, $arg) = @_;

    if($arg !~ /^\s*$/) {
        return __PACKAGE__ -> interpret($shell, $prefix, $arg);
    } 
    else {
        if($shell -> {alzabo_schema} -> {name}) {
            print "Current schema: ", $shell -> {alzabo_schema} -> {name}, "\n";
        }
        else {
            print <<1HERE1;
No schema is currently loaded.  Use `schema load <schema>' to load a 
schema or `schema create <schema> <optional schemas>' to create a new 
schema.
1HERE1
        }
    }
}

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<1HERE1;
schemas; schema list

This will list the available schemas known to Alzabo, whether or not 
they are valid Gestinanna schemas.  
1HERE1
        return;
    }

    my @schemas = Alzabo::Config -> available_schemas();

    print "  ", join("\n  ", sort @schemas), "\n";
}

sub do_load {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help
        print <<1HERE1;
schema load <schema>

Replace <schema> with the name of a pre-existing schema.  This will 
load the schema and make it the current schema for other commands 
which require a schema.

See also: schema create
1HERE1
        return 1;
    }

    Gestinanna::Schema -> make_methods(
        name => $arg
    );

    my %params;
    for(qw(host port user)) {
        next unless defined $Gestinanna::Shell::VARIABLES{$_};
        $params{$_} = $Gestinanna::Shell::VARIABLES{$_};
    }
    $params{password} = $Gestinanna::Shell::password if defined $Gestinanna::Shell::password;

    my $cs = Gestinanna::Schema -> load_schema_create(
        name => $arg,
        %params,
    );
    my $s = Gestinanna::Schema -> load_schema(  
        name => $arg,
        %params,
    );

    $shell -> {alzabo_schema} -> {create_schema} = $cs;
    $shell -> {alzabo_schema} -> {runtime_schema} = $s;
    $shell -> {alzabo_schema} -> {name} = $arg;
    # we want to load the classes used to create the schema also (serialized with YAML)
    $classfile = File::Spec -> catfile(Alzabo::Config -> schema_dir, $arg, "$arg.classes.gst");
    $shell -> {alzabo_schema} -> {classes} = YAML::LoadFile($classfile)
        if -f $classfile && -r _;
}

sub do_docs {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help
        print <<1HERE1;
schema docs

Displays the documentation for the methods created by Alzabo::MethodMaker 
for the currently loaded schema.

If the PAGER environment variable is not set (or set to a non-executable 
file), /usr/bin/less will be used.  If /usr/bin/less is not available, 
no paging will be done.
1HERE1
        return 1;
    }


    unless(defined $shell -> {alzabo_schema} -> {runtime_schema}) {
        warn "No schema has been loaded.  Use `schema load <schema>' first.\n";
        return 1;
    }

    eval { 
        require Pod::POM;
        require Pod::POM::View::Text;
    };
    if($@) {
        warn "Viewing the documentation requires Pod::POM.\n";
        return 1;
    }

    my $pod = $shell -> {alzabo_schema} -> {runtime_schema} -> docs_as_pod;
    my $pom = Pod::POM -> new -> parse_text($pod);
    __PACKAGE__ -> page(Pod::POM::View::Text -> print($pom));
    return 1;
}

sub do_create {
    my($shell, $prefix, $arg) = @_;

    my %drivers = map {$_ => 1} Alzabo::Driver -> available;
    my $drivers = join(", ", sort keys %drivers) || "not available";

    if($arg =~ /\?$/) {
        # do help


        print <<1HERE1;
schema create <rdbms> <name> <optional list of classes and namespaces>

This will create a new schema with the name <name> using the relational 
database system <rdbms>.  If the optional list of classes and namespaces 
is specified, they will be added to the list of classes which define the 
schema.

Valid values for <rdbms>: $drivers.

A namespace is a Perl package name ending with two colons (::).  A class 
is just a regular Perl package name.

See also: schema load
1HERE1
        return 1;
    }

    my($rdbms, $name, @classes) = split(/\s+/, $arg);
    unless($drivers{$rdbms}) {
        print <<1HERE1;
`$rdbms' is not a valid driver.  Please choose from one of the 
following: $drivers.
1HERE1
        return 1;
    }

    my @found_classes = grep { m{[^:]$} && eval "require $_" } @classes;

    push @found_classes, map { Gestinanna::Schema -> find_schemas(substr($_, 0, -2)) } (grep { m{::$} } @classes);

    my($s, $schemas);
    my %params;
    for(qw(host port user)) {
        next unless defined $Gestinanna::Shell::VARIABLES{$_};
        $params{$_} = $Gestinanna::Shell::VARIABLES{$_};
    }
    $params{password} = $Gestinanna::Shell::password if defined $Gestinanna::Shell::password;

    delete $params{user} if $rdbms eq 'SQLite'; # doesn't allow a user

    eval {
        ($s, $schemas) = Gestinanna::Schema -> create_schema(
            name => $name,
            rdbms => $rdbms,
            classes => \@found_classes,
            %params,
        );
    };

    if($@) {
        warn "Unable to create schema: $@\n",
        return 1;
    }

    $shell -> {alzabo_schema} -> {create_schema} = $s;
    $shell -> {alzabo_schema} -> {name} = $name;

    Gestinanna::Schema -> make_methods(
        name => $name
    );

    $s = Gestinanna::Schema -> load_schema(
        name => $name,
        %params,
    );
    $shell -> {alzabo_schema} -> {runtime_schema} = $s;

    # we want to save @found_classes somewhere
    $shell -> {alzabo_schema} -> {classes} = $schemas;

    my $classfile = File::Spec -> catfile(Alzabo::Config -> schema_dir, $name, "$name.classes.gst");
    YAML::DumpFile($classfile, $shell -> {alzabo_schema} -> {classes});

    return 1;
}

sub do_upgrade {
    my($shell, $prefix, $arg) = @_;
     
    if($arg =~ /\?$/) {
        # do help
      
        print <<1HERE1;
schema upgrade <optional list of classes and namespaces>
        
This will upgrade the loaded schema.  If the optional list of 
classes and namespaces is specified, they will be added to the 
list of classes which define the schema.
      
A namespace is a Perl package name ending with two colons (::).  A class
is just a regular Perl package name.
        
See also: schema create, schema load
1HERE1
        return 1;
    }

    my $name = $shell -> {alzabo_schema} -> {name};

    my @found_classes = ();
 
    my(@classes) = @{$shell -> {alzabo_schema} -> {classes}||[]}, split(/\s+/, $arg);

    push @found_classes, grep { m{[^:]$} && eval "require $_" } @classes;
 
    push @found_classes, map { Gestinanna::Schema -> find_schemas(substr($_, 0, -2)) } (grep { m{::$} } @classes);

    my $s = $shell -> {alzabo_schema} -> {create_schema};
     
    my($schemas);
    eval {
        ($s, $schemas) = Gestinanna::Schema -> upgrade_schema(
            schema => $s,
            classes => \@found_classes,
            host => $Gestinanna::Shell::VARIABLES{host},
            port => $Gestinanna::Shell::VARIABLES{port},
            user => $Gestinanna::Shell::VARIABLES{user},
            password => $Gestinanna::Shell::password,
        );
    };

    if($@) {
        warn "Unable to upgrade schema: $@\n",
        return 1;
    }

    Gestinanna::Schema -> make_methods(
        name => $name
    );

    $s = Gestinanna::Schema -> load_schema(
        name => $name,
        host => $Gestinanna::Shell::VARIABLES{host},
        port => $Gestinanna::Shell::VARIABLES{port},
        user => $Gestinanna::Shell::VARIABLES{user},
        password => $Gestinanna::Shell::password,
    );
    $shell -> {alzabo_schema} -> {runtime_schema} = $s;

    # we want to save @found_classes somewhere
    $shell -> {alzabo_schema} -> {classes} = $schemas;

    my $classfile = File::Spec -> catfile(Alzabo::Config -> schema_dir, $name, "$name.classes.gst");
    YAML::DumpFile($classfile, $shell -> {alzabo_schema} -> {classes});

    return 1;
}

sub do_drop {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<1HERE1;
schema drop

This will remove the database from the RDBMS where it was created.  It 
will not remove the schema definition files.

See also: schema delete
1HERE1
        return;
    }

    unless(defined $shell -> {alzabo_schema} -> {create_schema}) {
        warn "No schema has been loaded.  Use `schema load <schema>' first.\n";
        return;
    }

    Gestinanna::Schema -> drop_schema(
        schema => $shell -> {alzabo_schema} -> {create_schema},
        host => $Gestinanna::Shell::VARIABLES{host},
        port => $Gestinanna::Shell::VARIABLES{port},
        user => $Gestinanna::Shell::VARIABLES{user},
        password => $Gestinanna::Shell::password,
    );
}

sub do_delete {
    my($shell, $prefix, $arg) = @_;
    
    if($arg =~ /\?$/) {
        print <<1HERE1;
schema delete

This will remove the schema definition files.  This will not remove 
the database from the RDBMS.

See also: schema drop
1HERE1
        return 1;
    }

    unless(defined $shell -> {alzabo_schema} -> {create_schema}) {
        warn "No schema has been loaded.  Use `schema load <schema>' first.\n";
        return;
    }
                                                                                                                          
    Gestinanna::Schema -> delete_schema(
        schema => $shell -> {alzabo_schema} -> {create_schema},
    );

    delete $shell -> {alzabo_schema};
}

1;

__END__

=head1 NAME  
        
Gestinanna::Shell::Schema - schema commands
        
=head1 SYNOPSIS
        
 perl -MGestinanna -e shell
         
=head1 DESCRIPTION

This module defines all the C<schema> commands in the Gestinanna shell.

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
