package Gestinanna::Shell::Schema;

use Alzabo::Config;
use Alzabo::Create;
use Alzabo::Driver;
use File::Spec;
use Gestinanna::SchemaManager;
use Gestinanna::Shell::Base;
use Gestinanna::Shell::Schema::Def;
use YAML ();

@ISA = qw(Gestinanna::Shell::Base);

%EXPORT_COMMANDS = (
    schema => \&do_schema,
    schemas => \&do_list,
);

%COMMANDS = (
    %Gestinanna::Shell::Schema::Def::EXPORT_COMMANDS,
    load => \&do_load,
    create => \&do_create,
    docs => \&do_docs,
    delete => \&do_delete,
    drop => \&do_drop,
    list => \&do_list,
    make_live => \&do_make_live,
    add_definitions => \&do_add_defs,
    '?' => \&do_help,
);

sub do_help {
    my($shell, $prefix, $arg) = @_;

    print "The following commands are available for `schema': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;
}

sub do_schema {
    my($shell, $prefix, $arg) = @_;

    $shell -> {schema_manager} ||= Gestinanna::SchemaManager -> new;

    if($arg !~ /^\s*$/) {
        return __PACKAGE__ -> interpret($shell, $prefix, $arg);
    } 
    else {
        if($shell -> {alzabo_schema} -> {name}) {
            print "Current schema: ", $shell -> {alzabo_schema} -> {name}, "\n";
        }
        else {
            print <<EOF;
No schema is currently loaded.  Use `schema load <schema>' to load a 
schema or `schema create <schema> <optional schemas>' to create a new 
schema.
EOF
        }
    }
}

sub do_add_defs {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
schema add <file|directory>

This will add all the schemas defined in the file or in application 
packages in the directory.
EOF
        return;
    }

    if(-d $arg) {
        # packages
        my $packages = Gestinanna::PackageManager -> new( directory => $arg );
        $shell -> {schema_manager} -> add_packages($packages);
    }
    else {
        $shell -> {schema_manager} -> add_file($arg);
    }
}

sub do_list {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
schemas; schema list

This will list the available schemas known to Alzabo, whether or not 
they are valid Gestinanna schemas.  
EOF
        return;
    }

    my @schemas = Alzabo::Config -> available_schemas();

    print "  ", join("\n  ", sort @schemas), "\n";
}

sub do_load {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help
        print <<EOF;
schema load <schema>

Replace <schema> with the name of a pre-existing schema.  This will 
load the schema and make it the current schema for other commands 
which require a schema.

See also: schema create
EOF
        return 1;
    }
#    elsif(!$shell -> {_dbh}) {
#        print <<EOF;
#No database resource is selected.  Make sure you have set the 
#`resources' and `dbi' variables.
#EOF
#        return 1;
#    }

# need to make this happen.... I think - though I don't use it (or shouldn't)
    #Gestinanna::SchemaManager -> make_methods(
    #    name => $arg
    #);

    my $params = $shell -> alzabo_params;
    #if($shell -> {_dbh}) {
    #    $params{dbh} = $shell -> {_dbh};
    #}
    #else {
    #    for(qw(host port user)) {
    #        next unless defined $Gestinanna::Shell::VARIABLES{$_};
    #        $params{$_} = $Gestinanna::Shell::VARIABLES{$_};
    #    }
    #    $params{password} = $Gestinanna::Shell::password if defined $Gestinanna::Shell::password;
    #}

    my $cs = $shell -> {schema_manager} -> create_schema(
        name => $arg,
        %$params,
    );
    my $s = $shell -> {schema_manager} -> load_schema(
        name => $arg,
        %$params,
    );

    $s -> set_referential_integrity(1); # we need this, though this might be bad if using PostgreSQL

    #print "Referential integrity on\n" if $s -> referential_integrity;

    $shell -> {alzabo_schema} -> {create_schema} = $cs;
    $shell -> {alzabo_schema} -> {runtime_schema} = $s;
    $shell -> {alzabo_schema} -> {name} = $arg;
    # we want to load the classes used to create the schema also (serialized with YAML)
    # need to do this in the Schema object, not here
    $classfile = File::Spec -> catfile(Alzabo::Config -> schema_dir, $arg, "$arg.classes.gst");
    $shell -> {alzabo_schema} -> {classes} = YAML::LoadFile($classfile)
        if -f $classfile && -r _;
}

sub do_docs {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        # do help
        print <<EOF;
schema docs

Displays the documentation for the methods created by Alzabo::MethodMaker 
for the currently loaded schema.

If the PAGER environment variable is not set (or set to a non-executable 
file), /usr/bin/less will be used.  If /usr/bin/less is not available, 
no paging will be done.
EOF
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


        print <<EOF;
schema create <rdbms> <name>

This will create a new schema with the name <name> using the relational 
database system <rdbms>.

Valid values for <rdbms>: $drivers.

Schema definitions may be added to the schema.  Use `schema make_live' 
to instantiate the schema in the chosen RDBMS.

See also: schema load, schema make_live, schema def
EOF
        return 1;
    }
#    elsif(!$shell -> {_dbh}) {
#        print <<EOF;
#No database resource is selected.  Make sure you have set the 
#`resources' and `dbi' variables.
#EOF
#        return 1;
#    }


    my($rdbms, $name, @classes) = split(/\s+/, $arg);
    unless($drivers{$rdbms}) {
        print <<EOF;
`$rdbms' is not a valid driver.  Please choose from one of the 
following: $drivers.
EOF
        return 1;
    }

    my($s, $schemas);
    my $params = $shell -> alzabo_params;
#    for(qw(host port user)) {
#        next unless defined $Gestinanna::Shell::VARIABLES{$_};
#        $params{$_} = $Gestinanna::Shell::VARIABLES{$_};
#    }
#    $params{password} = $Gestinanna::Shell::password if defined $Gestinanna::Shell::password;

    delete $params->{user} if $rdbms eq 'SQLite'; # doesn't allow a user
#    $params{dbh} = $shell -> {_dbh};

    eval {
        $s = $shell -> {schema_manager} -> create_schema(
            name => $name,
            rdbms => $rdbms,
            %$params,
        );
    };

    if($@) {
        warn "Unable to create schema: $@\n",
        return 1;
    }

    $shell -> {alzabo_schema} -> {create_schema} = $s;
    $shell -> {alzabo_schema} -> {name} = $name;

    #Gestinanna::Schema -> make_methods(
    #    name => $name
    #);

    #$s = Gestinanna::Schema -> load_schema(
    #    name => $name,
    #    %$params,
    #);
    #$shell -> {alzabo_schema} -> {runtime_schema} = $s;

    # we want to save @found_classes somewhere
    return 1;
}

sub do_make_live {
    my($shell, $prefix, $arg) = @_;

    if($shell -> {alzabo_schema} -> {create_schema}) {
        my $params = $shell -> alzabo_params;
        delete $params->{user} if $rdbms eq 'SQLite'; # doesn't allow a user

        $shell -> {alzabo_schema} -> {create_schema} -> make_live(%$params);

        my $s = $shell -> {schema_manager} -> load_schema(
            name => $shell -> {alzabo_schema} -> {name},
            %{$params},
        );

        $shell -> {alzabo_schema} -> {runtime_schema} = $s;
    }
    return 1;
}

sub do_drop {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
schema drop

This will remove the database from the RDBMS where it was created.  It 
will not remove the schema definition files.

See also: schema delete
EOF
        return;
    }

    unless(defined $shell -> {alzabo_schema} -> {create_schema}) {
        warn "No schema has been loaded.  Use `schema load <schema>' first.\n";
        return;
    }

    my $params = $shell -> alzabo_params;
    delete $params->{user} if $rdbms eq 'SQLite'; # doesn't allow a user

    $shell -> {alzabo_schema} -> {create_schema} -> drop(%$params);
}

sub do_delete {
    my($shell, $prefix, $arg) = @_;
    
    if($arg =~ /\?$/) {
        print <<EOF;
schema delete

This will remove the schema definition files.  This will not remove 
the database from the RDBMS.

See also: schema drop
EOF
        return 1;
    }

    unless(defined $shell -> {alzabo_schema} -> {create_schema}) {
        warn "No schema has been loaded.  Use `schema load <schema>' first.\n";
        return;
    }
                                                                                                                          
    $shell -> {alzabo_schema} -> {create_schema} -> delete;

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
