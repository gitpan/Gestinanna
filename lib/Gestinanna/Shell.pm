package Gestinanna::Shell;

use Getopt::Std;
use strict;
 
our %VARIABLES = (
    user => $ENV{USER},
    home => $ENV{HOME},
);

our $password;

our %COMMANDS = (
);

sub find_commands {
    my($self, $base) = @_;
 
    eval {
        require Module::Require;
    };
        
    throw Gestinanna::Exception::Load(
        -text => "Unable to load Module::Require"
    ) if $@;
        
    $base =~ s{::}{/}g;

    Module::Require::walk_inc (
        sub {
            return if m{^CVS$};
            return $_ if m{\.pm$} or m{/[^.]+$};
            return;
        },
        sub {
            eval { require $_[1] and $INC{$_[0]} = $_[1] };
            return if $@;
            $_[0] =~ s{\.pm$}{};
            $_[0] =~ s{/}{::}g;
            if($_[0] -> can('init_commands')) {
                print "  $_[0]\n" unless $self->{suppress_narrative};
                $_[0] -> init_commands(\%Gestinanna::Shell::COMMANDS);
            }
            return 1;
        },
        $base,   
        );
}


sub shell {
    my %opts;
    my(@argv) = @ARGV;
    my($class) = shift;


    my $self = bless { }, ref $class || $class;

    if(@_) {
        @argv = @_;
    }

    local(@ARGV) = @argv;

    # process @args
    getopt('rhc:f:', \%opts);
    if(exists $opts{h}) {
        print <<1HERE1;
Usage: $0 [-r] [-h] [-f <rc file>] [file list]

  Option   Description
    -f     Use given rc file instead of ~/.gstrc
    -h     This help text
    -r     Suppress use of Term::ReadLine

For help on available commands, type `help' within the shell or
`perldoc Gestinanna::Shell'.
1HERE1
        exit 0;
    }

    $self -> {prompt} = "gst>";

    $self -> {suppress_readline} = 1 if(exists $opts{r}) ;
    $self -> {suppress_readline} = scalar(@ARGV) ? 1 : ! -t STDIN
        unless defined  $self -> {suppress_readline};

    unless($self -> {suppress_readline}) {
        eval { require Term::ReadLine; };
        $self -> {suppress_readline} = 1 if $@;
    }

    if ($self -> {suppress_readline}) {
        $self -> {OUT} = \*STDOUT;
        $self -> {IN} = \*STDIN;
    } else {
        if (! $self -> {term}
            or
            $self -> {term} ->ReadLine eq "Term::ReadLine::Stub"
           ) {
            $self -> {term} = Term::ReadLine->new('Gestinanna Monitor');
        }
        my $odef = select STDERR;
        $| = 1;
        select STDOUT;
        $| = 1;
        select $odef;
        $self -> {OUT} = $self -> {term} -> OUT || \*STDOUT;
        $self -> {IN} = $self -> {term} -> IN || \*STDIN;
    }

    $self->{suppress_narrative} = scalar(@ARGV);

    unless($self->{suppress_narrative}) {
        print "\ngst shell -- Gestinanna management (v$Gestinanna::VERSION)\n";
        print "ReadLine support enabled\n" unless $self -> {suppress_readline};
        print "Looking for command definitions...\n";
    }

    eval {
        require Gestinanna::Shell::Base;
        Gestinanna::Shell::Base -> init_commands(\%Gestinanna::Shell::COMMANDS);
    };

    $self -> find_commands('Gestinanna::Shell');

    unless($self->{suppress_narrative}) {
        print "\n";
    }

    $opts{f} = "$ENV{HOME}/.gstrc" unless defined $opts{f};
    if(-f $opts{f} && -r _) {
        print "Reading rc file $opts{f}\n";
        $self -> read_file($opts{f});
    }

    if( $self -> {suppress_readline}) {
        $self -> interpret($_) while(<>);
    } else {
        $self -> interpret($_) 
            while defined($_ = $self -> {term} -> readline($self->{prompt}))
    }

    return 1;
}

sub read_file {
    my($self, $file) = @_;

    if(-f $file && -r _) {
        my $fh;
        if(open $fh, "<", $file) {
            local($self -> {silent}) = 1;
            while(<$fh>) {
                chomp;
                next if /^\s*#/ || /^\s*$/;
                $self -> interpret($_) or return 1;
            }
        }
    }
}

sub interpret {
    my($self, $s) = @_;
    local($_);

    chomp $s;
    return if $s =~/^\s*#/ || $s =~/^\s*$/;
    $s =~s{^\s+}{};
    $s =~s{\s+$}{};

    $s =~ s-\$([{(])(\w+?)[)}]-
            $1 eq '{' ? $ENV{$2} : $Gestinanna::Shell::VARIABLES{$2}
        -xeg;


    if($s =~ /^!/) {
        print "\n";
        system(substr($s, 1));
        print "\n";
        return;
    }
    elsif($s =~ /^\?\s*(.+)$/) {
        $s = $1 . " ?";
    }

    my($cmd, $arg) = split(/\s+/, $s, 2);
    $cmd = lc $cmd;

    unless(defined $COMMANDS{$cmd}) {
        # try to find a file in $(path)
        my @paths = split(/:/, $VARIABLES{path});
        my $p;
        while($p = shift @paths) {
            if(-f "$p/$cmd" && -r _) {
                local(%VARIABLES);
                my @bits = split(/\s+/, $arg);

                @Gestinanna::Shell::VARIABLES{0..@bits} = ($cmd, @bits);

                $self -> read_file("$p/$cmd");
                return;
            }
        }
        print STDERR "Unknown command: $cmd\n";
        return;
    }

    eval {
        $COMMANDS{$cmd} -> ($self, $cmd, $arg);
    };
    if($@) {
       warn "NOT OK: $@\n";
    }
    else {
       print "OK\n";
    }
    return 1;
}

1;

__END__

=head1 NAME

Gestinanna::Shell - provides a command-line interface to Gestinanna

=head1 SYNOPSIS

 use Gestinanna::Shell;

 Gestinanna::Shell -> shell();

=head1 DESCRIPTION

The shell provides an easy way to bootstrap a Gestinanna-based 
application server as well as handle much of the day-to-day 
management if you do not want to use the web interface.  It also 
makes testing of new modules fairly easy without requiring a 
complete web application before testing can begin.

To see what top-level commands are available, type C<?> at the prompt.

You can type C<?> at the beginning or end of any command to see 
help specific to that command or set of commands.

You can store commands in an rc file (usually ~/.gstrc).  These 
will be read after the standard commands have been loaded and 
before you receive the prompt.  Any command that would be valid 
at the prompt is valid in the rc file.

=head1 SUBSTITUTION

Variables may be set with the C<set> command.  These may be used 
in subsequent commands through substitution.  Two forms of 
substitution are used:

=over 4

=item $(var)

Substitutes the value of the internal variable C<var>.

=item ${var}

Substitutes the value of the environment variable C<var>.

=back

The special variable C<password> is maintained outside the usual 
internal variable store.  The value of this variable (for purposes 
of substitution) are C<set> or C<unset>, denoting the state of 
the password.

=head1 AUTHOR
        
James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002 Texas A&M University.  All Rights Reserved.
        
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
