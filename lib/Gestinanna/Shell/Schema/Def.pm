package Gestinanna::Shell::Schema::Def;

use Gestinanna::Shell::Base;

@ISA = qw(Gestinanna::Shell::Base);

%EXPORT_COMMANDS = (
    def => \&do_def,
    defs => \&do_list,
);

%COMMANDS = (
    list => \&do_list,
    add => \&do_add,
    '?' => \&do_help,
);

sub do_help {
    my($shell, $prefix, $arg) = @_;

    print "The following commands are available for `schema def': ", join(", ", sort grep { $_ ne '?' } keys %COMMANDS), "\n";
    1;
}

sub do_def {
    my($shell, $prefix, $arg) = @_;

    if($arg !~ /^\s*$/) {
        return __PACKAGE__ -> interpret($shell, $prefix, $arg);
    }
}

sub do_add {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
schema def add <schema> <variables>

This will add a schema (set of table definitions) to the currently 
loaded RDBMS schema.  Some schemas allow variables to be set, changing 
their definition slightly.  You will need to check the application
documentation to find out which variables are available.

For example,

 schema def add repository prefix=View

will add a set of three tables to the loaded schema: View, View_Tag, 
and View_Description.

Separate multiple variable definitions by whitespace.
EOF
        return;
    }

    my @bits = split(/\s+/, $arg);
    my $schema = shift @bits;
    my %params = map { split(/=/, $_, 2) } @bits;

    $shell -> {alzabo_schema} -> {create_schema} -> add_schema($schema, %params);
}

1;

__END__
