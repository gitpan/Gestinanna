package Gestinanna::Shell::Base;

=begin testing

# BEGIN

use Expect;

our $exp = Expect -> new;
$exp -> spawn("perl",
                  "-Iblib/lib",
                  "-It/lib",
                  "-MGestinanna",
                  "-e",
                  "shell",
                  "--",
                  "-p",
                  "-f t/gstrc")
        or die "Cannot spawn: $!\n";
$exp -> stty(qw(echo));
$exp -> log_stdout(1);

sub shell_command_ok {
    my($command) = shift;

    return if $command =~ m{^\s*#}
           || $command =~ m{^\s*$};

    $exp -> expect(20, -re => 'gst>')
        or die "Unable to find prompt\n";
    print $exp "$command\r";
    eval {
        $exp -> expect(20,
            [
             qr'NOT OK:',
             sub {
                 die "Command ($command) did not complete successfully";
             },
            ],
            [
             qr'Unknown command',
             sub {
                 die "Unknown command - error in test script";
             },  
            ],
            [
             qr'OK',
             sub {
                 die "Command completed successfully";
             },
            ],
        ) or die "Unable to find OK\n";
    };
    my $e = $@;
    if($e !~ m{Command completed successfully}) {
        ok(0, $command);
        main::diag($e);
    }
    else {
        ok(1, $command);
    }
    my @bits = split(/[\n\r]+/, $exp -> before());
    shift @bits;
    my $out = join("\n", @bits);
    chomp($out);
    return $out;
}
    
END { 
    our $exp;
    if($exp) {
        print $exp "quit\r";
        eval {
            $exp -> do_soft_close;
            undef $exp;
        };
    }
}

=end testing

=cut

use Apache::Gestinanna;
use Cwd;  # qw(chdir cwd);

=begin testing

# INIT

use Expect;

our $exp = Expect -> new;
$exp -> spawn("perl",
                  "-Iblib/lib",
                  "-It/lib",
                  "-MGestinanna",
                  "-e",
                  "shell",
                  "--",
                  "-p",
                  "-f t/gstrc")
        or die "Cannot spawn: $!\n";
$exp -> stty(qw(echo));
$exp -> log_stdout(1);

sub shell_command_ok { 
    my($command) = shift;

    return if $command =~ m{^\s*#}
           || $command =~ m{^\s*$};

    $exp -> expect(20, -re => 'gst>')
        or die "Unable to find prompt\n";    
    print $exp "$command\r";
    eval {    
        $exp -> expect(20,    
            [    
             qr'NOT OK:',    
             sub {    
                 die "Command ($command) did not complete successfully";    
             },    
            ],    
            [    
             qr'Unknown command',    
             sub {    
                 die "Unknown command - error in test script";    
             },    
            ],    
            [    
             qr'OK',    
             sub {    
                 die "Command completed successfully";    
             },    
            ],    
        ) or die "Unable to find OK\n";    
    };
    my $e = $@;
    if($e !~ m{Command completed successfully}) {
        ok(0, $command);
        main::diag($e);
    }
    else {
        ok(1, $command);
    }
    my @bits = split(/[\n\r]+/, $exp -> before());
    shift @bits;
    my $out = join("\n", @bits);
    chomp($out);
    return $out;
}

END {
    our $exp;
    if($exp) {
        print $exp "quit\r";
        eval {
            $exp -> do_soft_close;
            undef $exp;
        };
    }
}

=end testing

=cut

our $password;
 
our %EXPORT_COMMANDS = (
    bug => \&do_bug,
    set => \&do_set,
    quit => \&do_quit,
    '?' => \&do_help,
    'cd' => \&do_cd,
    'pwd' => \&do_pwd,
    '.' => \&do_readfile,
    );

=begin testing

# init_commands

my $cmds = { };
__PACKAGE__ -> __METHOD__($cmds);

ok(eq_set([ keys %$cmds ], [qw(
    bug
    set
    quit
    ?
    cd
    pwd
    .
)]));

=end testing

=cut

sub init_commands {
    my($class, $cmds) = @_;

    @{$cmds}{keys %{"${class}::EXPORT_COMMANDS"}}
        = values %{"${class}::EXPORT_COMMANDS"};
}

sub page {
    my($shell, $string) = @_;

    if($shell -> {suppress_pager}) {
        print $string;
        return 1;
    }

    eval { require Term::Size; };

    unless($@) {
        my ($columns, $rows) = Term::Size::chars(*STDOUT{IO});
        my $lines = $string =~ tr[\n][\n];
        if($lines + 1 < $rows) {
            chomp $string;
            print $string, "\n";
            return 1;
        }
    }

    my $PAGER = (-x $ENV{PAGER} ? $ENV{PAGER} : '') || "/usr/bin/less";
    open my $pager, "|-", $PAGER or do {
        print $string;
        return 1;
    };

    { local($SIG{PIPE}) = 'IGNORE';
        print $pager $string;
    };
    close $pager;
}

sub edit {
    my($shell, $string) = @_;

    open my $fh, ">", "/tmp/gst.edit.$$" or die "Unable to open temporary file for editing.\n";
    print $fh $string;
    close $fh;
    system($ENV{EDITOR}||'vi',"/tmp/gst.edit.$$");
    open $fh, "<", "/tmp/gst.edit.$$" or die "Unable to open temporary file to retrieve edited content.\n";
    local($/);
    my $filled_out_report = <$fh>;
    close $fh;
    return $filled_out_report;
}

sub edit_xml {
    my($shell, $string) = @_;

    my $new_string = $shell -> edit($string);


    if($new_string eq $string || $new_string =~ m{^\s*$}) {
        return $string;
    }

    my $parser = XML::LibXML -> new();
    # need to make sure it parses
    eval {
        $parser -> parse_xml_chunk($new_string);
    };

    my $e = $@;
    $e =~ s{\s*at /.*?/Base.pm line \d+\s*$}{}s;
    while($e) {
        my $newer_string = $shell -> edit(<<EOF);
The following errors were found when parsing the XML:
$e
===========================================================================
Everything above the following line of `=' will be removed when you are
finished editing.  You do not need to remove the top of this document.
===========================================================================
$new_string
EOF

        $newer_string =~ s{^.*?={75}\n.*?={75}\n}{}s;
        if($newer_string =~ m{^\s*$}s || $newer_string eq $string) {
            return $string;
        }
        $new_string = $newer_string;
        $e = '';
        eval {
            $parser -> parse_string($new_string);
        };
        $e = $@;
        $e =~ s{\s*at /.*?/Base.pm line \d+\s*$}{}s;
    }

    return $new_string;
}

=begin testing

# do_help

my $t = shell_command_ok("?");

ok($t =~ m{The following commands are available:});
ok($t =~ m{\bbug\b});
ok($t =~ m{\bset\b});
ok($t =~ m{\bquit\b});
ok($t =~ m{\bcd\b});
ok($t =~ m{\bpwd\b});

=end testing

=cut

sub do_help {
    my($shell, $prefix, $arg) = @_;

    if($arg !~ /^\s*$/) {
        return $shell -> interpret("$arg ?");
    }

    print "The following commands are available: ", join(", ", sort grep { $_ ne '?' } keys %Gestinanna::Shell::COMMANDS), "\n";
}

sub do_readfile {
    my($shell, $prefix, $arg) = @_;

    if($arg =~ /\?$/) {
        print <<EOF;
. <file> <args>

Reads and interprets the named file as if its contents were typed on 
the console.  Variables and not localized.  The arguments are available 
as \$(1), \$(2), ....  The name of the file is \$(0).
EOF
        return;
    }

    my @bits = split(/\s+/, $arg);

    local(@Gestinanna::Shell::VARIABLES{0..@bits-1}) = (@bits);

    $shell -> read_file($bits[0]);
}

=begin testing

# do_cd

shell_command_ok("cd t");

=end testing

=cut

sub do_cd {
    my($shell, $prefix, $arg) = @_;

    chdir($arg) or print "Unable to change to \"$arg\".\n";
}

=begin testing

# do_pwd

my $pwd = shell_command_ok("pwd");

my @bits = File::Spec -> splitdir($pwd);
ok($bits[$#bits] eq 't');

=end testing

=cut

sub do_pwd {
    my($shell, $prefix, $arg) = @_;

    print cwd(), "\n";
}    

sub do_bug {
    my($shell, $prefix, $arg) = @_;
    my $DEV_LIST = "gestinanna-devel\@lists.sourceforge.net";
    my($to, $where) = split(/@/, $DEV_LIST, 2);
    my $date = scalar gmtime() . " GMT";
    my $executable = $0;
    my $config = '';

    if($arg =~ /\?$/) {
        print <<EOF;
bug

Sends a bug report to $DEV_LIST.
EOF
        return;
    }

    $config = "module\t\tversion\trevision\n\n";
    foreach my $m (sort qw-
        Gestinanna
        Gestinanna::POF
        Gestinanna::POF::Repository
        Template
        Alzabo
        AxKit
        mod_perl
    -) {
        eval "require $m";
        if($@) {
            $config .= "$m\t---\n";
        }
        else {
            $config .= "$m\t" . ${"${m}::VERSION"} . "\t" . ${"${m}::REVISION"} . "\n";
        }
    }

    $bug_report = <<EOF;
One line description:
  [ONE LINE DESCRIPTION HERE]

-------------8<---------- Start Bug Report ------------8<----------
1. Problem Description:

  [DESCRIBE THE PROBLEM HERE]

2. Used Components and their Configuration:

$config

  [ADDITIONAL CONFIGURATION INFORMATION HERE]

3. This is the core dump trace: (if you get a core dump):

  [CORE TRACE COMES HERE]

This report was generated by $executable on $date.

-------------8<---------- End Bug Report --------------8<----------

Note: Complete the rest of the details and post this bug report to
$to <at> $where. To subscribe to the list send 
an empty email to $to-subscribe\@$where.

EOF

    my $filled_out_report = $shell -> edit($bug_report);
    #open my $fh, ">", "/tmp/gst.bug.$$" or return 1;
    #print $fh $bug_report;
    #close $fh;
    #system($ENV{EDITOR}||'vi',"/tmp/gst.bug.$$");
    #open $fh, "<", "/tmp/gst.bug.$$" or return 1;
    #local($/);
    #my $filled_out_report = <$fh>;
    #close $fh;

    if($filled_out_report eq $bug_report) {
        print "Nothing was changed.  Aborting.\n";
    }
    else {
        my $subject;
        if($filled_out_report =~ m{One line description:\n(.*?)\n}) {
            $subject = $1;
            $subject =~ s{^\s*\[}{};
            $subject =~ s{]\s*$}{};
            $subject = "Bug Report" if $subject eq 'ONE LINE DESCRIPTION HERE';
        }
        else {
            $subject = "Bug Report";
        }
        if($filled_out_report =~ m{-------------8<---------- Start Bug Report ------------8<----------(.*)-------------8<---------- End Bug Report --------------8<----------}s) {
            $filled_out_report = $1;
        }
        print "Filled out report:\n\nSubject: $subject\n\n$filled_out_report\n\n";
    }

    1;
}

=begin testing

# do_set

__PACKAGE__::__METHOD__({ }, '', q{password 1234abcd});
is($Gestinanna::Shell::password, "1234abcd");
is($Gestinanna::Shell::VARIABLES{'password'}, 'set');

__PACKAGE__::__METHOD__({ }, '', q{password});
is($Gestinanna::Shell::password, '');
is($Gestinanna::Shell::VARIABLES{'password'}, 'unset');

__PACKAGE__::__METHOD__({ }, '', q{foo bar});
is($Gestinanna::Shell::VARIABLES{'foo'}, 'bar');

shell_command_ok("set foo bar");

my $t;

shell_command_ok("set password 1234abcd");
$t = shell_command_ok("set");
ok($t =~ m{^password\s+\[set\]$}m);

shell_command_ok("set password");
$t = shell_command_ok("set");
ok($t =~ m{^password\s+\[unset\]$}m);

shell_command_ok('set bar $(foo)');
$t = shell_command_ok("set");
ok($t =~ m{^bar\s+\[bar\]$}m);

=end testing

=cut

sub do_set {
    my($self, $prior, $arg) = @_;
    @args = split(/\s/, $arg);
    if(@args) {
        my $v = shift @args;
        my $t = join(' ', @args);
        if($self -> {_resources} && ($v eq 'dbi' || $v eq 'resources')) {
            $self -> {_resources} -> {$Gestinanna::Shell::VARIABLES{dbi}} -> free(delete $self -> {_dbi})
                if($self -> {_dbi});
            delete $self -> {alzabo_schema};
        }
        if($v eq 'password') {
            # need to prompt for it if we have a tty
            $Gestinanna::Shell::password = $t;
            $Gestinanna::Shell::VARIABLES{$v} = $t eq '' ? 'unset' : 'set';
        }
        else {
            $Gestinanna::Shell::VARIABLES{$v} = $t;
        }
        if($v eq 'resources') {
            # need to dump old resources and load new ones
            my $cfg = Apache::Gestinanna -> new;

            $cfg -> read_resource_config($t);

            my $resources = $cfg -> make_resources;

            $self -> {_resources} = $resources;
            if($Gestinanna::Shell::VARIABLES{dbi}) {
                $self -> {_dbh} = $self -> {_resources} -> {$Gestinanna::Shell::VARIABLES{dbi}} -> get();
            }
        }
        elsif($v eq 'dbi') {
            $self -> {_dbh} = $self -> {_resources} -> {$Gestinanna::Shell::VARIABLES{dbi}} -> get();
            delete $self -> {alzabo_schema};
        }
    }
    else {
        foreach my $k (sort keys %Gestinanna::Shell::VARIABLES) {
            print "$k [$Gestinanna::Shell::VARIABLES{$k}]\n";
        }
    }
    1;
}

sub do_quit { exit 0; }

sub interpret {
    my($class, $self, $prior, $s) = @_;
    local($_);

    my($cmd, $arg) = split(/\s+/, $s, 2);
    $cmd = lc $cmd;

    my $cmds = \%{"${class}::COMMANDS"};

    unless(defined $cmds->{$cmd}) {
        print STDERR "Unknown command: $prior $cmd\n";
        return 1;
    }

    return $cmds->{$cmd} -> ($self, "$prior $cmd", $arg);
}

sub alzabo_params {
    my $shell = shift;

    my %params;
    if($shell -> {_dbh}) {
        $params{dbh} = $shell -> {_dbh};
    }
    else {
        for(qw(host port user)) {
            next unless defined $Gestinanna::Shell::VARIABLES{$_};
            $params{$_} = $Gestinanna::Shell::VARIABLES{$_};
        }
        $params{password} = $Gestinanna::Shell::password if defined $Gestinanna::Shell::password;
    }

    return \%params;
}

1;

__END__

=head1 NAME

Gestinanna::Shell::Base - base commands and support for command extensions

=head1 SYNOPSIS

 package Gestinanna::Shell::MyCommands;

 use base qw(Gestinanna::Shell::Base);

 %COMMANDS = (
    command => \&do_command,
 );

 %EXPORTED_COMMANDS = (
    mycommand => \do_mycommand,
 );

=head1 DESCRIPTION

=head1 AUTHOR
        
James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
        
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
