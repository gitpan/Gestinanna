package My::Builder;

use Module::Build;
our @ISA = qw(Module::Build);

use File::Spec;
use Test::More;


use strict;

sub ACTION_manifest {
    my $self = shift;
    $self -> depends_on('tests');
    $self -> SUPER::ACTION_manifest;
}

sub ACTION_dependencies {
    my $self = shift;
    $self -> depends_on('code');
    require XML::LibXML;
    require Pod::Coverage;
    my $changed = 0;

    my($doc, $root) = $self -> _get_deps_dom;

    my $pm_files = $self -> find_pm_files;
    my $PL_files = $self -> find_PL_files;

    my @files = values %$pm_files, values %$PL_files;

    foreach my $file (@files) {
        my @dirs = File::Spec -> splitdir($file);
        shift @dirs;
        my $module = join("::", @dirs);
        $module =~ s{\.[^.]+$}{};
        next unless $self -> _is_modified_after_deps(File::Spec -> catfile('blib', $file));
        #print "Processing $module from $file\n";
        my $coverage = Pod::Coverage -> new(
            package => $module,
            pod_from => File::Spec -> catfile('blib', $file)
        );

        my $module_el;
        unless(($module_el) = ($root -> findnodes('module[@name="' . $module . '"]'))) {
            $module_el = $doc -> createElement('module');
            $module_el -> setAttribute(name => $module);
            $root -> appendChild($module_el);
            $changed = 1;
        }

        my $interface_el;
        unless(($interface_el) = ($module_el -> findnodes('interface'))) {
            $interface_el = $doc -> createElement('interface');
            $module_el -> appendChild($interface_el);
            $changed = 1;
        }

        my @methods = sort($coverage -> uncovered, $coverage -> covered);

        my($method_el);

        foreach my $method (@methods) {
            unless(($method_el) = ($interface_el -> findnodes('method[@name="' . $method . '"]'))) {
                $method_el = $doc -> createElement('method');
                $method_el -> setAttribute(name => $method);
                $interface_el -> appendChild($method_el);
                $changed = 1;
            }
        }
    }

    my $modules = $root -> findnodes('module');
    my %provides = map { $_ -> getAttribute('name') => 1 } $modules -> get_nodelist;

    foreach my $module_el ($modules -> get_nodelist) {
        my $item = $module_el -> getAttribute('name');
        my @dirs = split(/::/, $item);
        my $file = File::Spec -> catfile(qw(blib lib), @dirs[0..$#dirs-1], $dirs[$#dirs] . ".pm");
        next unless $self -> _is_modified_after_deps($file);
        local($/);

        # load dependencies from module
        open my $fh, "<", $file or next;
        my $content = <$fh>;
        close $fh;

        my @uses = $content =~ m{#?\s*use\s+(.*?);}mg;
        @uses = grep { $provides{$_} }
                     map { s{^base\s+}{} ? eval : m{^(\S+)} }
                         grep { m{^base} || m{^[A-Z]} }
                              grep { !m{^#} } @uses;

        #print "$item: ", join(" ", @uses), "\n";

        foreach my $module ( @uses ) {
            my($dep_el) = ($module_el -> findnodes('dependence[@module="' . $module . '"]'));
            unless($dep_el) {
                next if $module eq $item;
                #print "$item does not depend on $module yet\n";
                $dep_el = $doc -> createElement('dependence');
                $dep_el -> setAttribute(module => $module);
                $module_el -> appendChild($dep_el);
                $changed = 1;
            }
            elsif($module eq $item) {
                $module_el -> removeChild($dep_el);
                $changed = 1;
            }
            else {
                #print "$item already depends on $module\n";
            }
        }

        #print "Uses in $item:\n<", join("><", @uses), ">\n";
    }

    if($changed) {
        open my $fh, ">", "deps.xml" or die "Unable to open deps.xml: $!\n";

        my $xml = $doc -> toString(2);

        $xml =~ s{\n(\s*\n)+}{\n}mg;
        print $fh $xml;

        close $fh;
    }
}

sub ACTION_tests {
    my $self = shift;
    $self -> depends_on('dependencies');
    
    my($doc, $root) = $self -> _get_deps_dom;

    require Algorithm::Dependency::Ordered;
    require Pod::Tests;

    eval { require Pod::Coverage; };
    my $has_pod_coverage = $@ ? 0 : 1;

    my $source = __PACKAGE__::MyXMLSource -> new( qw(dependence module), $root -> findnodes('module') );

    my $dep = Algorithm::Dependency::Ordered -> new(
        source => $source,
        ignore_orphans => 1,
    );

    my $schedule = $dep->schedule_all;

    unless($schedule) {
        warn "Unable to create a schedule of modules.\n";
        return;
    }

    $self -> _set_init_deps($dep);

    my $counter = "0" x length(2+scalar(@$schedule));

    mkdir 't' unless -d 't';

    opendir my $dir, 't' or die "Unable to open directory: $!\n";
    unlink File::Spec -> catfile('t', $_) for grep { m{^\d+-.+\.t$} } (readdir($dir));
    closedir $dir;

    my $filename = "${counter}-compile.t";
    #print "t/${filename}\n";
    open my $fh, ">", File::Spec -> catfile('t', $filename) or die "Unable to open file: $!\n";
    my $num_tests = scalar(@$schedule);
    my $tlib = File::Spec -> catdir(qw(t lib));

    print $fh <<1HERE1;
use lib q{$tlib};
use My::Builder;
use Test::More tests => $num_tests;

BEGIN {
    our \@modules = qw(
        @{[join("\n        ", @$schedule)]}
    );

    use_ok(\$_) for \@modules;
}

# record test results for later

my \$tester = Test::More -> builder;
my \$builder = My::Builder -> current;
my \@details = \$tester -> details;
my \$test_results = \$builder -> notes('test_results') || { };

for(my \$i = 0; \$i <= \$#modules; \$i++) {
    \$test_results -> {\$modules[\$i]} -> {compile_ok} =
        \$details[\$i] -> {actual_ok};
}

\$builder -> notes(test_results => \$test_results);
1HERE1

    $counter ++;

    foreach my $item (@$schedule) {
        my $filename = lc $item;
        $filename =~ s{::}{-}g;
        #print "t/${counter}-${filename}.t\n";
        open my $fh, ">", File::Spec -> catfile('t', "${counter}-${filename}.t") or die "Unable to open file: $!\n";
        print $fh "use lib q{$tlib};\nuse My::Builder;\n";
        $self -> _create_test($fh, $item, $root -> findnodes("module[\@name='$item']"));
        $counter ++;
    }

    #print "t/${counter}-pod.t\n";
    $filename = "${counter}-pod.t";
    open $fh, ">", File::Spec -> catfile('t', $filename) or die "Unable to open file: $!\n";
    print $fh "use lib q{$tlib};\nuse My::Builder;\n";

    $self -> _create_pod_test($fh, $schedule);

    close $fh;

    $counter ++;
    #print "t/${counter}-cleanup.t\n";

    open $fh, ">", File::Spec -> catfile('t', "${counter}-cleanup.t") or die "Unable to open file: $!\n";
    print $fh "use lib q{$tlib};\nuse My::Builder;";

    $self -> _create_cleanup($fh);
    
    close $fh;

    $counter ++;
}

sub _create_test {
    my($self, $fh, $module, @nodes) = @_;

    my($source, $dep, $schedule);

    $source = __PACKAGE__::MyXMLSource -> new( qw(dependence method), (
        map { $_ -> findnodes('interface/method') } @nodes
    ) ) if @nodes;

    $dep = Algorithm::Dependency::Ordered -> new(
        source => $source,
        ignore_orphans => 1,
    ) if $source;

    $schedule = $dep->schedule_all if $dep;

    unless($schedule) {
        print $fh qq{# No tests\nuse Test::More skip_all => 'No tests defined';};
        return;
    }

    my $pod_tests_ex = Pod::Tests -> new;
    { no warnings; $pod_tests_ex -> parse_file(File::Spec -> catfile(qw(blib lib), split(/::/, $module)) . ".pm"); }

    my @pod_tests;
    { no warnings; @pod_tests = $pod_tests_ex -> tests; }

    my %extra_tests;
    foreach my $t (@pod_tests) {
        $t->{code} =~ s{^\s*#\s*(.*?)\n}{}m;
        my $method = $1;
        $t -> {code} =~ s{__PACKAGE__}{$module}mg;
        $t -> {code} =~ s{__METHOD__}{$method}mg;
        do { } while $t -> {code} =~ s{
            __OBJECT__
            (?: \( ([^)]+) \) )?
        }{
            defined($1) ? "\$objects{'$1'}" : "\$objects{'_default'}"
        }mxe;
        $extra_tests{$method} ||= [];
        push @{$extra_tests{$method}}, $t;
    }

    foreach my $method (keys %extra_tests) {
        no warnings;
        $extra_tests{$method} = join("\n\n", $pod_tests_ex -> build_tests(@{$extra_tests{$method}}));
    }

    $self -> _register_cleanup($module, $extra_tests{'CLEANUP'}) if $extra_tests{'CLEANUP'};
    $self -> _register_init($module, "use $module;\n".$extra_tests{'INIT'}) if $extra_tests{'INIT'};

    print $fh "# Testing found ", scalar(@nodes), " nodes\n";
    print $fh <<1HERE1;
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require $module;
    };

    if(\$\@) {
        plan skip_all => 'Unable to load $module';
        exit 0;
    }
}

plan no_plan;

my \$builder = My::Builder -> current;

1HERE1

    my $tests = 0;

    my @ids;
    my @constructors = map { $_ -> findnodes('interface/constructor') } @nodes;

    print $fh <<1HERE1;
my \%objects;

1HERE1

    $extra_tests{'BEGIN'} = $self -> _query_init($module) . "\n" . (defined $extra_tests{'BEGIN'} ? $extra_tests{'BEGIN'} :  '')
        if $self -> _query_init($module);

    foreach my $phase (qw(
        BEGIN
        END
    )) {
        print $fh "$phase {\n" . $extra_tests{$phase} . "\n}\n"
            if(defined $extra_tests{$phase});
    }

    foreach my $constructor ( @constructors ) {
        my $id = $constructor -> getAttribute('id');
        $id = '_default' if !defined($id) || $id eq '';
        my $method = $constructor -> getAttribute('method');
        $method = 'new' if !defined($method) || $method eq '';
        # need to get arguments...
        push @ids, $id;

        my $arguments = $self -> _parse_arguments($constructor);

        { no warnings; print $fh <<1HERE1
\$builder -> begin_tests('$method');
eval {
    \$objects{'$id'} = $module -> $method($arguments);
};
ok(!\$\@);
isa_ok(\$objects{'$id'}, '$module');

$extra_tests{$method}

\$builder -> end_tests('$method');
1HERE1
        }
    }

    my %id_seen;

    @ids = grep { !$id_seen{$_}++ } @ids;

    print $fh "my \@ids = qw(", join(" ", @ids), ");\n\n" if @ids;

    my %seen = ( BEGIN => 1, END => 1, CLEANUP => 1, INIT => 1 );

    foreach my $method (@$schedule, keys %extra_tests) {
        next if $seen{$method}++;
        print $fh "\n# method: $method\n\n\$builder -> begin_tests('$method');\n\n";

        my($method_el) = ( map { $_ -> findnodes('interface/method[@name="' . $method . '"]') } @nodes );

        my @tests = ( );
        @tests = $method_el -> findnodes('test') if $method_el;

        foreach my $test (@tests) {
            my($in_el, $out_el);
            ($in_el) = ($test -> findnodes('in'));
            ($out_el) = ($test -> findnodes('out'));
            my $in = $self -> _parse_arguments($in_el);
            my $out = $self -> _parse_arguments($out_el);
            my($object);
            if(@ids) {
                $object = $test -> getAttribute('object-id');
                $object = '_default' if !defined($object) || $object eq '';
                print $fh <<1HERE1;
eval {
    \@result = ( );
    (\@result) = (\$objects{'$object'} -> $method($in));
};
ok(!\$\@);
is_deeply(\\\@result, [ $out ], q($module($object) -> $method));

1HERE1
            }
            else {
                print $fh <<1HERE1;
eval {
    \@result = ${module}::${method}($in);
};
ok(!\$\@);
is_deeply(\\\@result, [ $out ], q(${module}::${method}));

1HERE1
            }
        }
        print $fh "\n". $extra_tests{$method}. "\n" if defined $extra_tests{$method} && !ref($extra_tests{$method});
        print $fh "\n\$builder -> end_tests('$method');\n";
    }

        print $fh <<1HERE1;
# record test results for report
\$builder -> record_test_details('$module');
my \$tester = Test::More -> builder;
if(\$tester -> current_test == 0) {
    \$tester -> skip_all( 'No tests defined' );
}
1HERE1
}


sub _create_pod_test {
    my($self, $fh, $schedule) = @_;

    my $num_tests = scalar(@$schedule);

    print $fh <<1HERE1;
use Test::More;

my \$build = My::Builder -> current;
my \$pod_coverage = { };

BEGIN {
    our(\$has_test_pod, \$has_pod_coverage) = (1,1);
    eval {
        require Test::Pod;
        Test::Pod -> import;
    };
    \$has_test_pod = 0 if \$\@;

    eval {
        require Pod::Coverage;
        Pod::Coverage -> import;
    };
    \$has_pod_coverage = 0 if \$\@;

    unless(\$has_test_pod || \$has_pod_coverage) {
        plan skip_all => 'At least one of Test::Pod and Pod::Coverage are required to run Pod tests';
        exit 0;
    }
}

plan tests => $num_tests*(\$has_test_pod + \$has_pod_coverage);
1HERE1

    foreach my $item (sort @$schedule) {
        my $file = File::Spec -> catfile(qw(blib lib), split(/::/, $item)) . ".pm";

        print $fh <<1HERE1;

pod_file_ok(
    q($file),
    q(Testing POD in $item)
) if \$has_test_pod;

if(\$has_pod_coverage) {
    my \$coverage = Pod::Coverage -> new(
        package => q($item),
        pod_from => q($file)
    );
    ok(\$coverage -> coverage == 1, q(Testing POD coverage in $item));
    # store stuff for report later
    \$pod_coverage -> {q($item)} = {
        why_unrated => \$coverage -> why_unrated,
        uncovered => [ \$coverage -> uncovered ],
        covered => [ \$coverage -> covered ],
    }
}
1HERE1
    }

print $fh <<1HERE1;
    \$build -> notes(pod_coverage => \$pod_coverage);
1HERE1

}

{
my %init;
my $deps;
my %seen;

sub _register_init {
    my($self, $module, $code) = @_;

    foreach my $m (@{$deps->{$module} || []}) {
        #next if $seen{"$module -> $m"}++;
        warn("registering INIT section for $module -> $m\n");
        $init{$m} .= $code;
        $self -> _register_init($m, $code);
    }
}

sub _query_init {
    my($self, $module) = @_;

    return $init{$module};
}

sub _set_init_deps {
    my($self, $dep) = @_;

    $deps = $self -> _inv_deps($dep);
}
}

{
my %cleanup;
my @cleanup_modules;

sub _register_cleanup {
    my($self, $module, $code) = @_;

    $cleanup{$module} = $code;
    unshift @cleanup_modules, $module;
}

sub _create_cleanup {
    my($self, $fh) = @_;

    print $fh <<1HERE1;
use Test::More;
1HERE1

    foreach my $module (@cleanup_modules) {
        print $fh "\n# Cleanup for $module\n\nuse $module;\n\n";
        print $fh $cleanup{$module}, "\n\n";
    }

    print $fh <<1HERE1;
plan skip_all => 'No tests defined';
1HERE1
}

}

sub ACTION_cover {
    my $self = shift;
    $self -> depends_on('tests');

    system('cover', '-delete');
    local $ENV{HARNESS_PERL_SWITCHES} .= " -MDevel::Cover";
    $self -> depends_on('test');
    system('cover');
}

sub ACTION_report {
    my $self = shift;

    require Algorithm::Dependency::Ordered;
    require Perl::Tidy;
    require Pod::Coverage;
    require IO::String;

    my $pod_coverage = $self -> notes('pod_coverage');
    my $test_results = $self -> notes('test_results');

    if(!ref $test_results) {
        $self -> depends_on('test');
        $pod_coverage = $self -> notes('pod_coverage');
        $test_results = $self -> notes('test_results');
    }

    my($doc, $root) = $self -> _get_deps_dom;

    #print "doc: $doc; root: $root\n";

    my $source = __PACKAGE__::MyXMLSource -> new( qw(dependence module), $root -> findnodes('module') );

    #print "source: $source\n";

    my $dep = Algorithm::Dependency::Ordered -> new(
        source => $source,
        ignore_orphans => 1,
    );

    #print "dep: $dep\n";

    my @parallel_modules = $self -> _parallel_deps($dep);

    my $schedule = $dep->schedule_all;

    #print "schedule: $schedule\n";

    my %counts;

    my %totals;

    my $totals = __PACKAGE__::Counter -> new;

    #print "totals: $totals\n";

    mkdir 'report' unless -d 'report';


    my %overall_tests;

    foreach my $package (@$schedule) {
        my $filename = File::Spec -> catfile(qw(blib lib), split(/::/, $package)) . ".pm";

        my $content;
        open my $fh, "<", $filename or die "Unable to read file: $!\n";
        { local($/); $content = <$fh>; }
        close $fh;
        my $destination;
        my $errors = IO::String -> new;
        my $counter = __PACKAGE__::Counter -> new;

        eval {
        local(@ARGV) = ( );
        Perl::Tidy::perltidy(
            source => \$content,
            destination => \$destination,
            formatter => $counter,
            errorfile => $errors,
        );
        };

        #print "error tidying file: $@\n" if $@;

        #print "$package: ", Data::Dumper -> Dump([$counter]);
        my $errstr = ${$errors -> string_ref};
        #print "Errors:\n$errstr\n" if $errstr ne '';
        $totals -> combine($counter);

        my @depends = $dep -> source -> item($package) -> depends;

        my $outfile = $package;
        $outfile =~ s{::}{-}g;
        $outfile = lc $outfile;
        open $fh, ">", File::Spec -> catfile('report', $outfile . ".html") or next;
        print $fh <<EOHTML;
<html>
  <head>
    <title>CRC for $package</title>
  </head>
  <body>
    <h1>CRC for $package</h1>
EOHTML

        if(@depends) {
            print $fh "<p>This module depends on the following modules: ";
            foreach my $d (@depends) {
                my $f = $d;
                $f =~ s{::}{-}g;
                $f = lc $f;
                print $fh qq(<a href="${f}.html">$d</a> );
            }
            print $fh "</p>\n";
        }
        else {
            print $fh "<p>This module does not depend on any other modules in this project.</p>\n";
        }


        my $total = 0;
        $total += $_ for values %$counter;

        print $fh <<EOHTML;
    <table border="1">
      <tr><td>Line Type</td><td>Count</td></tr>
      <tr><td>Code</td><td>@{[$$counter{CODE} || '-']}</td></tr>
      <tr><td>Comments</td><td>@{[$$counter{COMMENT} || '-']}</td></tr>
      <tr><td>Documentation</td><td>@{[$$counter{POD} || '-']}</td></tr>
      <tr><td>Internal Data</td><td>@{[$$counter{HERE} || '-']}</td></tr>
      <tr><td>Total</td><td>$total</td></tr>
    </table>
EOHTML

        my $method_html = '';
        my $overall_passed = 0;
        my $overall_total = 0;

        my %docs;
        my $pack_file = File::Spec -> catfile(qw(blib lib), split(/::/, $package));
        $pack_file .= ".pm";

        my $coverage = $pod_coverage -> {$package};

        my @covered = @{$coverage -> {covered} || []};
        my @uncovered = @{$coverage -> {uncovered} || []};

        @docs{@covered} = ('Y') x scalar(@covered);
        @docs{@uncovered} = ('N') x scalar(@uncovered);

        my $method_src = __PACKAGE__::MyXMLSource -> new( qw(dependence method), (
            $root -> findnodes('module[@name="' . $package . '"]/interface/method')
        ) );

        my $method_dep;
        $method_dep = Algorithm::Dependency::Ordered -> new(
            source => $method_src,
            ignore_orphans => 1,
        ) if $method_src;

        if($method_dep) {
            my @parallel_methods = $self -> _parallel_deps($method_dep);

            my $filename = $package;
            $filename =~ s{::}{-}g;
            $filename = lc $filename;
            print $fh <<EOHTML;
    <h2>Dependency Ranking</h2>
    <table border="1">
      <tr><td>Rank</td><td>Methods</td></tr>
EOHTML

            for(my $rank = 0; $rank <= $#parallel_methods; $rank++) {
                print $fh "<tr><td>$rank</td><td>";
                foreach my $method (sort @{$parallel_methods[$rank]||[]}) {
                    my $total = $test_results -> {$package} -> {methods} -> {$method} -> {total};
                    my $passed = $test_results -> {$package} -> {methods} -> {$method} -> {passed};

                    my $color = "red";
                    if(defined $total && defined $passed && $total > 0) {
                        if($passed == $total) {
                            $color = "green";
                        }
                        elsif(3 * $passed >= 2*$total) {
                            $color = "gold";
                        }
                        elsif(3 * $passed >= $total) {
                            $color = "orange";
                        }
                    }
                    print $fh qq{<font color="$color">$method</font> };
                }
            #print $fh join(" ", sort @{$parallel_methods[$rank]||[]});
                print $fh "</td></tr>\n";
            }

            print $fh <<EOHTML;
    </table>
EOHTML
        }

        print $fh "<h2>Modules</h2>\n";

        my $methods = [ ];
        $methods = $method_dep->schedule_all if $method_dep;

        my(@constructors) = $root -> findnodes('module[@name="' . $package . '"]/interface/constructor');
        my %seen_methods;
        if(@constructors) {
             my @cons_methods;
             foreach my $c (@constructors) {
                 my $method = $c -> getAttribute('method') || 'new';
                 push @cons_methods, $method;
             }
             my %tcm = map { $_ => undef } @cons_methods;
             @constructors = grep { exists $tcm{$_} && ++$tcm{$_} } @{$methods};
             push @constructors, grep { exists($tcm{$_}) && !defined($tcm{$_}) } keys %tcm;

             my($html, $passed, $total) = $self -> _method_html("Constructors", \@constructors, \%docs, $test_results -> {$package} -> {methods}, $method_dep);
             $seen_methods{$_}++ for @constructors;
             $method_html .= $html;
             $overall_passed += $passed;
             $overall_total += $total;
        }

        my @public_methods = grep { !m{^_} && !$seen_methods{$_} } @$methods;

        if(@public_methods) {
            my($html, $passed, $total) = $self -> _method_html('Public Methods', \@public_methods, \%docs, $test_results -> {$package} -> {methods}, $method_dep);
           $seen_methods{$_}++ for @public_methods;
           $method_html .= $html;
           $overall_passed += $passed;
           $overall_total += $total;
        }

        my @private_methods = grep { m{^_} && !$seen_methods{$_} } (
            @$methods,
            keys %{$test_results -> {$package} -> {methods}||{}},
        );

        if(@private_methods) {
            my($html, $passed, $total) = $self -> _method_html('Private Methods', \@private_methods, \%docs, $test_results -> {$package} -> {methods}, $method_dep);
           $seen_methods{$_}++ for @private_methods;
           $method_html .= $html;
           $overall_passed += $passed;
           $overall_total += $total;
        }

        if($overall_total) {
            $overall_tests{$package} = [ $overall_passed, $overall_total ];
        }

        print $fh "<p>Total passed tests: $overall_passed / $overall_total</p>\n";

        print $fh <<EOHTML if $method_html;
    <table border="1">
      $method_html
    </table>
EOHTML
        print $fh <<EOHTML;
  </body>
</html>
EOHTML

        close $fh;
    }

    open my $fh, ">", File::Spec -> catfile(qw(report index.html)) or die "Unable to create CRC index: $!\n";

    my $total = 0;
    $total += $_ for values %$totals;
    my($overall_passed, $overall_total) = (0, 0);

    foreach my $package (keys %overall_tests) {
        $overall_passed += $overall_tests{$package}[0];
        $overall_total  += $overall_tests{$package}[1];
    }

    my $overall_percentage = '-';

    if($overall_total) {
        $overall_percentage = (int($overall_passed * 10000 / $overall_total) / 100) . '%';
    }
    else {
        $overall_total = '-';
        $overall_passed = '-';
    }

    print $fh <<EOHTML;
<html>
  <head>
    <title>CRC</title>
  </head>
  <body>
    <h1>CRC Reports</h1>
    <table border="1">
      <tr><td>Line Type</td><td>Count</td></tr>
      <tr><td>Code</td><td>$$totals{CODE}</td></tr>
      <tr><td>Comments</td><td>$$totals{COMMENT}</td></tr>
      <tr><td>Documentation</td><td>$$totals{POD}</td></tr>
      <tr><td>Internal Data</td><td>$$totals{HERE}</td></tr>
      <tr><td>Total</td><td>$total</td></tr>
    </table>
    <p>Passing tests: $overall_passed / $overall_total ($overall_percentage)</p>
    <!-- table border=0>
        <tr><td><embed src="module_deps.svg" width="290px" height="150px" /></td></tr>
        <tr><td align="center"><a href="module_deps.svg">Larger View</a></td></tr>
    </table -->
    <!-- img src="module_deps.png"/ -->
    <h2>Dependency Ranking</h2>
    <table border="1">
      <tr><td>Rank</td><td>Modules</td></tr>
EOHTML

    for(my $rank = 0; $rank <= $#parallel_modules; $rank++) {
        print $fh "<tr><td>$rank</td><td>";
        foreach my $d (sort @{$parallel_modules[$rank]||[]}) {
            my $f = $d;
            $f =~ s{::}{-}g;
            $f = lc $f;
            print $fh qq(<a href="${f}.html">$d</a> );
        }
        print $fh "</td></tr>\n";
    }

    print $fh <<EOHTML;
    </table>
    <h2>Modules</h2>
    <table border="1">
      <tr><td>Module</td><td>Compiles</td><td>Dependence</td></tr>
EOHTML


    foreach my $p (@$schedule) {
        my $filename = $p;
        $filename =~ s{::}{-}g;
        $filename = lc $filename;
        print $fh qq(<tr><td><a href="${filename}.html">$p</a></td>\n<td>);
        print $fh (defined $test_results -> {$p} -> {compile_ok})
                  ? ($test_results -> {$p} -> {compile_ok} ? 'Y' : 'N')
                  : '-';
        print $fh "</td>\n<td>";
        my @depends = $dep -> source -> item($p) -> depends;
        foreach my $d (@depends) {
            my $f = $d;
            $f =~ s{::}{-}g;
            $f = lc $f;
            print $fh qq(<a href="${f}.html">$d</a> );
        }
        print $fh "</td></tr>\n";
    }

    print $fh <<EOHTML;
    </table>
  </body>
</html>
EOHTML

    close $fh;
}

sub _method_html {
    my($self, $title, $methods, $docs, $tests, $method_dep) = @_;

    my %seen;

    my $html = <<1HERE1;
<tr><td colspan="5" align="center"><strong>$title</strong></td></tr>
<tr><td>Method</td><td>Documented</td><td>Tests Failed</td><td>Total Tests</td><td>Dependencies</td></tr>
1HERE1

    my($overall_passed, $overall_total) = (0, 0);

    foreach my $method (@$methods) {
        next if $seen{$method}++;
        my $doc = $docs->{$method};
        $doc = '-' unless defined $doc;
        my $passed_tests = $tests -> {$method} -> {passed};
        my $total_tests = $tests -> {$method} -> {total};
        $passed_tests = '-' unless defined $passed_tests;
        $total_tests = '-' unless defined $total_tests;
        $overall_passed += $passed_tests if $passed_tests =~ m{^\s*\d+\s*$};
        $overall_total += $total_tests if $total_tests =~ m{^\s*\d+\s*$};
        my $diff = ($total_tests =~ m{^\s*\d+\s*$}  ? $total_tests  : 0)
                 - ($passed_tests =~ m{^\s*\d+\s*$} ? $passed_tests : 0);
        $html .= "      <tr><td>$method</td><td>$doc</td><td>$diff</td><td>$total_tests</td><td>";
        if(defined $method_dep && defined $method_dep -> source -> item($method)) {
            $html .= join(" ", $method_dep -> source -> item($method) -> depends);
        }
        $html .= "</td></tr>\n";
    }
    return($html, $overall_passed, $overall_total);
}

sub _parallel_deps {
    my($self, $dep) = @_;

    my $schedule = $dep -> schedule_all || [];

    my %distances;

    @distances{@$schedule} = ( 0 ) x scalar(@$schedule);

    foreach my $item (@$schedule) {
        my @ds = sort { $b <=> $a } map { $distances{$_} || 0  } ($dep -> source -> item($item) -> depends);
        #print "ds: ", join(" ", @ds), "\n";
        $distances{$item} = $ds[0] + 1 if @ds;
    }

    my @rows;

    foreach my $item (@$schedule) {
        $rows[$distances{$item}] ||= [ ];
        push @{$rows[$distances{$item}]}, $item;
    }

    return @rows;
}

sub ACTION_graph {
    my $self = shift;
    #$self -> depends_on('test');

    require Algorithm::Dependency::Ordered;
    require Graph::Directed;

    my $test_results = $self -> notes('test_results');

    #print "test_results: $test_results\n";
    if(!ref $test_results) {
        $self -> depends_on('test');
        $test_results = $self -> notes('test_results');
    }

    my($doc, $spec_root) = $self -> _get_deps_dom;

    my $source = __PACKAGE__::MyXMLSource -> new( qw(dependence module), $spec_root -> findnodes('module') );

    my $dep = Algorithm::Dependency::Ordered -> new(
        source => $source,
        ignore_orphans => 1,
    );

    my $schedule = $dep -> schedule_all;

    my %doms;
    my %scores;

    foreach my $module (@$schedule) {
        my $method_src = __PACKAGE__::MyXMLSource -> new( qw(dependence method), (
            $spec_root -> findnodes('module[@name="' . $module . '"]/interface/method')
        ) );

        my $method_dep;
        $method_dep = Algorithm::Dependency::Ordered -> new(
            source => $method_src,
            ignore_orphans => 1,
        ) if $method_src;

        next unless $method_dep;

        my $filename = $module;
        $filename =~ s{::}{-}g;
        $filename = lc $filename;

        my $graph = $self -> _make_graph($method_dep);

        next unless $graph;

        # we want to put in a little window for each method

        foreach my $method ($graph -> vertices) {
            my $id = "${module}::${method}";
            $id =~ s{::}{_}g;
            $id = lc $id;
            $graph -> set_attribute('id', $method, $id);

            my $total = $test_results -> {$module} -> {methods} -> {$method} -> {total};
            my $passed = $test_results -> {$module} -> {methods} -> {$method} -> {passed};

            my $color = "red";
            $scores{$module}{'methods'}++;
            if(defined $total && defined $passed && $total > 0) {
                if($passed == $total) {
                    $color = "green";
                    $scores{$module}{'colors'} += 3;
                }
                elsif(3 * $passed >= 2*$total) {
                    $color = "gold";
                    $scores{$module}{'colors'} += 2;
                }
                elsif(3 * $passed >= $total) {
                    $color = "orange";
                    $scores{$module}{'colors'} += 1;
                }
            }
            $graph -> set_attribute('color', $method, $color);
        }
  
        my $svg_dom = XML::LibXML -> createDocument;

        $self -> _make_svg($graph, $svg_dom);

        my @svgs;

        foreach my $method ($graph -> vertices) {
            my $id = $graph -> get_attribute('id', $method);
        
            my $g = $svg_dom -> createElement('g');
            push @svgs, $g;
    
            $g -> setAttribute(id => "text_$id");
        
            $g -> setAttribute(style => 'visibility:hidden');
    
            #$g -> setAttribute(x => 50);
            #$g -> setAttribute(y => $svg_dom -> documentElement -> getAttribute('height') + 20);

            my $animate = $svg_dom -> createElement('animate');
            $animate -> setAttribute(begin => "vert_${id}.click");
            $animate -> setAttribute(attributeName => 'visibility');
            $animate -> setAttribute(from => 'hidden');
            $animate -> setAttribute(to => 'visible');
            $animate -> setAttribute(fill => 'freeze');
            $animate -> setAttribute(dur => '0.1s');

            $g -> appendChild($animate);

            my $rectangle = $svg_dom -> createElement('rect');
        
            $rectangle -> setAttribute(id => "rect_$id");
            $rectangle -> setAttribute('stroke-width' => 3);
            $rectangle -> setAttribute('stroke' => 'black');
            $rectangle -> setAttribute('fill' => 'white');
            $rectangle -> setAttribute('rx' => 20);
        
            $animate = $svg_dom -> createElement('animate');
            $animate -> setAttribute(begin => "rect_${id}.click");
            $animate -> setAttribute(attributeName => 'visibility');
            $animate -> setAttribute(from => 'visible');
            $animate -> setAttribute(to => 'hidden');
            $animate -> setAttribute(fill => 'freeze');
            $animate -> setAttribute(dur => '0.1s');
            $g -> appendChild($animate);

            my @texts = (
                qq{method: $method},
                qq{tests passed: } . ($test_results -> {$module} -> {methods} -> {$method} -> {passed} || '0'),
                qq{ total tests: } . ($test_results -> {$module} -> {methods} -> {$method} -> {total} || '0'),
            );

            my $max_w = (sort { $b <=> $a } map { length($_) } @texts)[0];
            my $svg = $svg_dom -> createElement('svg');
            $svg -> setAttribute(x => 50);
            $svg -> setAttribute(y => $svg_dom -> documentElement -> getAttribute('height') + 20);
            $svg -> setAttribute('width' => 7 * $max_w + 30);
            $svg -> setAttribute('height' => 55);   
            $g -> appendChild($svg);
            $svg -> appendChild($rectangle);

            $rectangle -> setAttribute(x => 3);
            $rectangle -> setAttribute(y => 3);
            $rectangle -> setAttribute('width' => $svg -> getAttribute('width') - 6);
            $rectangle -> setAttribute('height' => $svg -> getAttribute('height') - 6);

            my $text = $svg_dom -> createElement('text');
            $text -> setAttribute(x => 15);
            $text -> setAttribute(dy => 10);
        
            $svg -> appendChild($text);
        
            foreach my $t (@texts) {
                my $tspan = $svg_dom -> createElement('tspan');
                $tspan -> appendText($t);
                $tspan -> setAttribute(x => 15);
                $tspan -> setAttribute(dy => 15);
                $text -> appendChild($tspan);
            }
        }
        
        $doms{$module} = [ $svg_dom -> documentElement, @svgs ];
    }

    my $graph = $self -> _make_graph($dep);

    foreach my $v ($graph -> vertices) {
        my $id = $v;
        $id =~ s{::}{_}g;
        $id = lc $id;
        $graph -> set_attribute('id', $v, $id);
        
        my $total = $scores{$v}{'methods'};
        my $passed = $scores{$v}{'colors'};
        my $color = "red";
        if(defined $total && defined $passed && $total > 0) {
            if($passed == 3*$total) {
                $color = "green";
            }
            elsif($passed >= 2*$total) {
                $color = "gold";
            }
            elsif($passed >= $total) {
                $color = "orange";
            }
        }
        $graph -> set_attribute('color', $v, $color);
    }

    # put in a little window for each module

    my $svg_dom = XML::LibXML -> createDocument;
    $svg_dom -> setStandalone(0);
    $svg_dom -> createInternalSubset('svg', '-//W3C//DTD SVG 20010904//EN', 'http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd');

    $self -> _make_svg($graph, $svg_dom);

    my $root = $svg_dom -> documentElement;

    $root -> removeAttribute('width');
    $root -> removeAttribute('height');

    foreach my $module (keys %doms) {

        my $g = $svg_dom -> createElement('g');
        my $id = $graph -> get_attribute('id', $module);
        if(!defined $id) {
            $id = lc $id;
            $id =~ s{::}{_}g;
        }
        $g -> setAttribute(id => "svg_$id");
            
        $g -> setAttribute(style => 'visibility:hidden');
         
        my $animate = $svg_dom -> createElement('animate');
        $animate -> setAttribute(begin => "vert_${id}.click");
        $animate -> setAttribute(attributeName => 'visibility');
        $animate -> setAttribute(from => 'hidden');
        $animate -> setAttribute(to => 'visible');
        $animate -> setAttribute(fill => 'freeze');
        $animate -> setAttribute(dur => '0.1s');

        $g -> appendChild($animate);
    
        my $rectangle = $svg_dom -> createElement('rect');
    
        $rectangle -> setAttribute(id => "rect_$id");
        $rectangle -> setAttribute('stroke-width' => 3);
        $rectangle -> setAttribute('stroke' => 'black');
        $rectangle -> setAttribute('fill' => 'white');
        $rectangle -> setAttribute('rx' => 20);
        
        $animate = $svg_dom -> createElement('animate');
        $animate -> setAttribute(begin => "rect_${id}.click");
        $animate -> setAttribute(attributeName => 'visibility');
        $animate -> setAttribute(from => 'visible');
        $animate -> setAttribute(to => 'hidden');
        $animate -> setAttribute(fill => 'freeze');
        $animate -> setAttribute(dur => '0.1s');
         
        $g -> appendChild($animate);

        my $svg = shift @{$doms{$module} || []};
        next unless $svg;
        $svg_dom -> adoptNode($svg);

        #$rectangle -> setAttribute(height => '100%'); # $svg -> getAttribute('height'));
        #$rectangle -> setAttribute(width => '100%'); # $svg -> getAttribute('width'));
        #$rectangle -> setAttribute(x => 0);
        #$rectangle -> setAttribute(y => 0);
        $rectangle -> setAttribute(x => 3);
        $rectangle -> setAttribute(y => 3);
        $rectangle -> setAttribute('width' => $svg -> getAttribute('width') - 6);
        $rectangle -> setAttribute('height' => $svg -> getAttribute('height') - 6);

        $svg -> insertBefore($rectangle, undef);

        $g -> appendChild($svg);

        $root -> appendChild($g);

        foreach my $d (@{$doms{$module} || []}) {
            $svg_dom -> adoptNode($d);
    
            $root -> appendChild($d);
        }
    }
    
    my $file = File::Spec -> catfile(qw(graph));
    $svg_dom -> toFile($file . '.svg', 1);
}

sub _parse_arguments {
    my $self = shift;
    my $node = shift;
        
    my @arguments;   

    foreach my $child ( $node -> childNodes ) {
        #print "Node: ", $child -> localname, " Type: ", $child -> nodeType, "\n";
        my $key = '';
        $key = $child -> getAttribute('key') if $child -> can('getAttribute');
        $key =~ s{\|}{\\\|}gm;
        push @arguments, ($key ne '' ? "q|$key|" : ()), $self -> _parse_argument_node($child);
    }
    return join(", ", grep { defined && $_ ne '' } @arguments);
}

sub _parse_argument_node {
    my $self = shift;
    my $child = shift;
        
    my $localname = $child -> localname;
    $localname = '' unless defined $localname;
    if($localname eq 'nil') {
        return 'undef'; 
    }
    elsif($localname eq 'regex') {
        my $text = $child -> textContent;
        $text =~ s{^\s*\n}{}m;  
        $text =~ s{\n\s*$}{}m;
        #$text =~ s{\|}{\\\|}gm;
        $text =~ s/([\\|])/\\$1/gm;
        return 'qr|'.$text.'|';
    }
    elsif($localname eq 'string') {
        my $text = $child -> textContent;
        $text =~ s{^\s*\n}{}m;
        $text =~ s{\n\s*$}{}m;
        #$text =~ s{\|}{\\\|}gm;
        $text =~ s/([\\|])/\\$1/gm;
        return 'q|'.$text.'|';

        return "q|$text|";
    }
    elsif($localname eq 'list') {
        return "[ " . $self -> _parse_arguments($child) . " ]";
    }
    elsif($localname eq 'association') {
        my @values;
        foreach my $pair ($child -> childNodes) {
            my $key = $pair -> getAttribute('key');
            $key =~ s{\|}{\\\|}gm;
            push @values, "q|$key| => " . $self -> _parse_argument_node($pair);
        }
        return "{ " . join(", ", @values) . " }";
    }
}

sub _inv_deps {
    my($self, $dep) = @_;
    
    my $schedule = $dep -> schedule_all;
    
    my %v;
    
    foreach my $item (@$schedule) {
        foreach my $d ($dep -> source -> item($item) -> depends) {
            push @{$v{$d} ||= []}, $item;
        }
    }
    
    return \%v;
}

sub _make_graph {
    my($self, $dep) = @_;

    my $graph = Graph::Directed -> new;

    my @rows = $self -> _parallel_deps($dep);

    my %prev_row;
    my %no_edges;
    for(my $rank = 0; $rank <= $#rows; $rank++) {
        my $row = $rows[$rank];
        for(my $file = 0; $file <= $#$row; $file++) {
            my $item = $row -> [$file];
            $graph -> add_vertex($item);
            $graph -> set_attribute('layout_pos1', $item, $rank);
            foreach my $d ($dep -> source -> item($item) -> depends) {
                $graph -> add_edge($d, $item);
            }
        }
    }

    my $inv_dep = $self -> _inv_deps($dep);

    foreach my $v (keys %$inv_dep) {
        next unless @{$inv_dep->{$v} || []};
        my @xs = sort { $a <=> $b } map { $graph -> get_attribute('layout_pos1', $_) } @{$inv_dep->{$v}};
        #print "Moving $v from col ", $graph -> get_attribute('layout_pos1', $v), " to col ", $xs[0] - 1, "\n";
        $graph -> set_attribute('layout_pos1', $v, $xs[0] - 1);
    }

    my @sinks = $graph -> sink_vertices;

    my %seen;
    my %taken;

    for(my $pos = 0; $pos <= $#sinks; $pos++) {
        $seen{$sinks[$pos]} ++;
        $graph -> set_attribute('layout_pos2', $sinks[$pos],  $pos);
        $graph -> set_attribute('weight', $sinks[$pos], 1);
        $taken{$graph -> get_attribute('layout_pos1', $sinks[$pos]) . '.' . $pos} = 1;
    }

    my @vertices = grep { !$seen{$_} } map { $graph -> neighbors($_) } @sinks;
    while(@vertices) {
        my $v = shift @vertices;
        next if $seen{$v}++;

        my @right = grep { $seen{$_} } $graph -> neighbors($v);
        push @vertices, grep { !$seen{$_} } $graph -> neighbors($v);
     
        my $minx = $#rows;
        my $total_y = 0;
        my $total_weight = 0;
        my($x, $y);
        if(grep { !defined $graph -> get_attribute('layout_pos2', $_) } @right) {
            push @vertices, $v;
            next;
        }
        foreach my $r (@right) {   
            $x = $graph -> get_attribute('layout_pos1', $r);
            $y = $graph -> get_attribute('layout_pos2', $r);
            $minx = $x if $minx > $x;
            $total_y += $y * ($graph -> get_attribute('weight', $r) || 1);
            $total_weight += $graph -> get_attribute('weight', $r) || 1;
        }
        $x = $graph -> get_attribute('layout_pos1', $v);
        $y = int(($total_y + $total_weight/2) / ($total_weight || 1));
        if($taken{$x . '.' . $y}) {
            my $o = 1;
            $o ++ while($taken{$x . '.' . ($y+$o)} && $taken{$x . '.' . ($y-$o)});
            if(!$taken{$x . '.' . ($y-$o)}) { 
                $y = $y - $o;
            }
            elsif(!$taken{$x . '.' . ($y + $o)}) {
                $y = $y + $o;
            }
            else { warn "Oops!: $v - $x, $y\n" }
        }
        $taken{$x . '.' . $y} = 1;  
        $graph -> set_attribute('layout_pos1', $v, $x);
        $graph -> set_attribute('layout_pos2', $v, $y);
        $graph -> set_attribute('weight', $v, $total_weight);
    }

    @vertices = @{$rows[0] || []};
    #@vertices = ( );
    %seen = ( );
    while(@vertices) {
        my $v = shift @vertices;
        next if $seen{$v}++;

        #if($v =~ m{::}) { print "rechecking location of $v:\n"; }
        my $x = $graph -> get_attribute('layout_pos1', $v);
        my $y = $graph -> get_attribute('layout_pos2', $v);
    
        next if defined $y;
        #push @vertices, grep { $graph -> get_attribute('layout_pos1', $_) >= $x } $graph -> neighbors($v);
        #my @successors = grep { $graph -> get_attribute('layout_pos1', $_) < $x } $graph -> neighbors($v);
        #next unless @successors;
        #my @xs = sort { $b <=> $a } map { $graph -> get_attribute('layout_pos1', $_) } @successors;
        #my $new_x = $xs[0] + 1;
        #next if $new_x >= $x;

        delete $taken{"${x}.${y}"} if defined $y;
        $y = 0 if !defined $y;
        my $old_y = $y;
        my $old_x = $x;   
        #$x = $new_x;   
        if($taken{$x . '.' . $y}) {
            my $o = 1;
            $o ++ while($taken{$x . '.' . ($y+$o)} && $taken{$x . '.' . ($y-$o)});
            if(!$taken{$x . '.' . ($y-$o)}) {
                $y = $y - $o;
            }
            elsif(!$taken{$x . '.' . ($y + $o)}) {
                $y = $y + $o;
            }
            else { warn "Oops!: $v - $x, $y\n" }
        }
        $taken{$x . '.' . $y} = 1;
         
        #print "  moving from ($old_x, $old_y) to ($x, $y)\n" if $v =~ m{::};
        $graph -> set_attribute('layout_pos1', $v, $x); 
        $graph -> set_attribute('layout_pos2', $v, $y);
    }

    my($min_x, $min_y, $max_x, $max_y);

    foreach my $v ($graph -> vertices) {
        my($x, $y) = (
            $graph -> get_attribute('layout_pos1', $v),
            $graph -> get_attribute('layout_pos2', $v)
        );
        #print "$v: $x, $y\n";
        $min_x = $x if !defined($min_x) || $x < $min_x;
        $min_y = $y if !defined($min_y) || $y < $min_y;
        $max_x = $x if !defined($max_x) || $x > $max_x;
        $max_y = $y if !defined($max_y) || $y > $max_y;
    }
     
    #print "Rectangle: ($min_x, $min_y) -> ($max_x, $max_y)\n";
    
    $graph -> set_attribute('layout_min1', $min_x);
    $graph -> set_attribute('layout_min2', $min_y);
    $graph -> set_attribute('layout_max1', $max_x);
    $graph -> set_attribute('layout_max2', $max_y);
        
    return $graph;
}

sub _make_svg {
    my($self, $graph, $svg_dom) = @_;

    my $root = $svg_dom -> createElement(
        'svg'
    );
    $root -> setNamespace('http://www.w3.org/1999/xlink', 'xlink', 0);
    $root -> setNamespace('http://www.w3.org/2000/svg');

    $svg_dom -> setDocumentElement($root);

    #my $min_x = $graph -> get_attribute('layout_min1');

    $root -> setAttribute(height => ($graph -> get_attribute('layout_max2') - $graph -> get_attribute('layout_min2')) * 25 + 50);
    $root -> setAttribute(width => ($graph -> get_attribute('layout_max1') - $graph -> get_attribute('layout_min1')) * 120 + 120);
    #$root -> setAttribute(height => 'auto');
    #$root -> setAttribute(width => 'auto');

    #$root -> setAttribute(viewBox => join(" ",
    #    $graph -> get_attribute('layout_min1') * 100 + 100,
    #    $graph -> get_attribute('layout_min2') * 20 - 20,
    #    $graph -> get_attribute('layout_max1') * 100 + 200,
    #    $graph -> get_attribute('layout_max2') * 20 + 40,
    #));
        
    $root -> setAttribute(version => '1.1');

    my @edges = $graph -> edges;
    my($u, $v);
    while(($u, $v) = splice @edges, 0, 2) {
        my $line = $self -> _edge($svg_dom, $graph, $u, $v);
            
        $line -> setAttribute(#'http://www.w3.org/2000/svg',
            stroke => 'grey');
        $line -> setAttribute(#'http://www.w3.org/2000/svg',
            'stroke-width' => '1');
        
        $root -> appendChild($line);
    }
     
    #my $defs = $svg_dom -> createElement('defs');
    
    #$root -> appendChild($defs);
    
    my @labels;
    my @paths;
    my @vertices;
    foreach my $v ($graph -> vertices) {
        push @paths, $self -> _path($svg_dom, $graph, $v); 

        my($circle, $label) = $self -> _vertex($svg_dom, $graph, $v);

        push @labels, $label;
        push @vertices, $circle;
        #$root -> appendChild($circle);
    }

    $root -> appendChild($_) for @labels;
    $root -> appendChild($_) for @paths;
    $root -> appendChild($_) for @vertices;
}
        
sub _path {
    my($self, $dom, $graph, $v) = @_;
    
    #print "Path for $v:\n";
    my $path = $dom -> createElement(
        'g'
    );

    $path -> setAttribute(style => 'visibility:hidden;');
    
    my $id = $graph -> get_attribute('id', $v);
    if(!defined $id) {
        $id = $v;
        $id =~ s{::}{_}g;
        $id = lc $id;
    }
    
    my $animate = $dom -> createElement('animate');
    $animate -> setAttribute(begin => "vert_${id}.mouseover");
    $animate -> setAttribute(attributeName => 'visibility');
    $animate -> setAttribute(from => 'hidden');
    $animate -> setAttribute(to => 'visible');
    $animate -> setAttribute(fill => 'freeze');
    $animate -> setAttribute(dur => '0.1s');
    
    $path -> appendChild($animate);

    $animate = $dom -> createElement('animate');
    $animate -> setAttribute(begin => "vert_${id}.mouseout");
    $animate -> setAttribute(attributeName => 'visibility');
    $animate -> setAttribute(from => 'visible');
    $animate -> setAttribute(to => 'hidden');
    $animate -> setAttribute(fill => 'freeze');
    $animate -> setAttribute(dur => '0.1s');

    $path -> appendChild($animate);

    $path -> setAttribute(id => "path_$id");

    my @edges = $self -> _edges($dom, $graph, $v);

    foreach (@edges) {
        $_ -> setAttribute(#'http://www.w3.org/2000/svg',
            stroke => 'black');
        $_ -> setAttribute(#'http://www.w3.org/2000/svg',
            'stroke-width' => '2');
    }
        
    $path -> appendChild($_) foreach @edges;
        
    return $path;
}

sub _edges {
    my($self, $dom, $graph, $v) = @_;

    my @edges = ( );

    #print "  $v\n";
    my $x = $graph -> get_attribute('layout_pos1', $v);
    my @vertices = grep { $graph -> get_attribute('layout_pos1', $_) < $x } $graph -> neighbors($v);
    
    push @edges, $self -> _edge($dom, $graph, $v, $_) foreach @vertices;
      
    push @edges, $self -> _edges($dom, $graph, $_) foreach @vertices;
    
    return @edges;
}

sub _edge {
    my($self, $dom, $graph, $u, $v) = @_;

    my($fromx, $fromy, $tox, $toy) = (
        $graph -> get_attribute('layout_pos1', $u) - $graph -> get_attribute('layout_min1') + .25,
        $graph -> get_attribute('layout_pos2', $u) - $graph -> get_attribute('layout_min2') + 1.5,
        $graph -> get_attribute('layout_pos1', $v) - $graph -> get_attribute('layout_min1') + .25,
        $graph -> get_attribute('layout_pos2', $v) - $graph -> get_attribute('layout_min2') + 1.5,
    );

    my $line = $dom -> createElement(
        #'http://www.w3.org/2000/svg',
        'line',
    );

    $line -> setAttribute(#'http://www.w3.org/2000/svg',
        x1 => $fromx * 100);
    $line -> setAttribute(#'http://www.w3.org/2000/svg',
        y1 => $fromy * 20);
    $line -> setAttribute(#'http://www.w3.org/2000/svg',
        x2 => $tox * 100);
    $line -> setAttribute(#'http://www.w3.org/2000/svg',
        y2 => $toy * 20);
    
    my $width = $graph -> get_attribute('weight', $v); # + $graph -> get_attribute('weight', $v);
    $width = int(log($width) / log(2.) + 0.5) if $width > 0;
    #$width -= 2;
    $width = 1 if $width < 1;

    #$line -> setAttribute(style => "stroke-width:$width;");
        
    return $line;
}
            
sub _vertex {
    my($self, $dom, $graph, $vertex) = @_;

    my($x, $y, $color, $label, $link_ref) = (
       map { $graph -> get_attribute($_, $vertex) } qw(
           layout_pos1
           layout_pos2
           color
           label
           link
       )
    );

    $x -= $graph -> get_attribute('layout_min1') - .25;
    $y -= $graph -> get_attribute('layout_min2') - 1.5;

    $label = $vertex unless defined $label;
    $color = 'red' unless defined $color;
    
    my $file_ref = lc $label;
    $file_ref =~ s{::}{-}g;
    my $id = $graph -> get_attribute('id', $vertex);
    if(!defined $id) {
        $id = lc $label;
        $id =~ s{::}{_}g;
    }
    my $label_ref = "vert_$id";
    my $link;
        
    if(defined $link_ref) {
        $link = $dom -> createElement(
            #'http://www.w3.org/2000/svg',
            'a'
        );
      
        $link -> setAttribute('xlink:href' => $link_ref);
    }
    else {
        $link = $dom -> createElement(
            'g'
        );
    }
    
    $link -> setAttribute(id => $label_ref);

    my $circle = $dom -> createElement(
        #'http://www.w3.org/2000/svg',
        'circle' 
    );

    $circle -> setAttribute(cx => $x * 100);
    $circle -> setAttribute(cy => $y * 20);
    $circle -> setAttribute(r => 8);
    $circle -> setAttribute(#'http://www.w3.org/2000/svg',
        fill => 'black');

    $link -> appendChild($circle);
    
    $circle = $dom -> createElement(
        #'http://www.w3.org/2000/svg',
        'circle'
    );
           
    $circle -> setAttribute(cx => $x * 100);
    $circle -> setAttribute(cy => $y * 20);
    $circle -> setAttribute(r => 7);
    $circle -> setAttribute(#'http://www.w3.org/2000/svg',
        fill => $color);
      
    $link -> appendChild($circle);
    
    my $text = $dom -> createElement(
        #'http://www.w3.org/2000/svg',
        'text'
    );

    $text -> setAttribute(x => $x * 100 + 6);
    $text -> setAttribute(y => $y * 20 - 6);
    $text -> setAttribute('text-anchor' => 'start');
    $text -> setAttribute(fill => 'blue');
    #$text -> setAttribute(id => $label_ref);
        
    $text -> appendTextNode( $label );
    
    return( $link, $text);
}


{
my $DOM;
my $M;

sub _get_deps_dom {
    require XML::LibXML;
    require Pod::Coverage;

    my $doc;
    my $parser = XML::LibXML -> new;
    my $root;

    if($DOM) {
        $doc = $DOM;
        $root = $doc -> documentElement;
        return ($doc, $root);
    }

    if(-e 'deps.xml') {
        $M = -M _;
        $doc = $parser -> parse_file('deps.xml');
        $root = $doc -> documentElement;
        foreach my $module ( map { $_ -> getAttribute('name') } $root -> findnodes('module')) {
            push @ARGV, $module;
        }
    }
    else {
        $M = undef;
        $doc = XML::LibXML->createDocument;
        $root = $doc -> createElement('specification');
        $doc -> setDocumentElement($root);
    }

    $DOM = $doc;
    return($doc, $root);
}

sub _is_modified_after_deps {
    return 1 unless defined $M;

    my($self, $file) = @_;

    return $M > -M $file;
}

}

{

my @result;
my %tests;

sub begin_tests {
    my($self, $m) = @_;
    my $tester  = Test::More -> builder;
    $tests{$m} ||= [];
    push @{$tests{$m}}, $tester -> current_test;
}

sub end_tests {
    my($self, $m) = @_;
    my $tester  = Test::More -> builder;
    my $t = $tests{$m};
    my $first = $t -> [$#$t];
    my $last = $tester -> current_test - 1;
    if(!defined $first || !defined $last || $last < $first) {
        pop @$t;
    }
    else {
        while(++$first <= $last) {
            push @$t, $first;
        }
    }
}

sub tests {
    my($self, $m) = @_;
    return @{$tests{$m}||[]};
}

sub tested_methods { return keys %tests; }

sub record_test_details {
    my($self) = shift;
    my($module) = shift;
    my $tester  = Test::More -> builder;
    my @details = $tester -> details;
    my $results = $self -> notes('test_results');
    my $test_results = $results -> {$module} -> {'methods'} ||= {};
    foreach my $method ($self -> tested_methods()) {
        my @passed = grep { $details[$_] -> {actual_ok} }
                          $self -> tests($method);
        my $total = scalar($self -> tests($method));
        $test_results -> {$method} = {
            total => $total,
            passed => scalar(@passed),
        };
    }

    $self -> notes(test_results => $results);
}

}

{
package __PACKAGE__::Counter;

sub new { bless { } => $_[0] };
    
sub write_line {
    my ( $self, $line_of_tokens ) = @_;
    my $line_type = $line_of_tokens->{_line_type};

    if($line_of_tokens -> {_line_text} =~ m{^\s*#}) {
        $line_type = 'COMMENT';
    }
    elsif($line_of_tokens -> {_line_text} =~ m{^\s*$}) {
        $line_type = 'BLANK';
    }

    $self -> {$line_type} ++;
}

sub combine {
    my ($self, $other) = @_;

    foreach my $k (keys %$other) {
        $self -> {$k} += $other -> {$k};
    }
}

}

{
package __PACKAGE__::MyXMLSource;

use Algorithm::Dependency::Source;
our @ISA = qw(Algorithm::Dependency::Source);

sub new {
    my $class = shift;
    #my $dom = shift; 

    my $self = $class -> SUPER::new() or return undef;
    $self -> {dep_name} = shift;
    $self -> {attr_name} = shift; 
    return undef unless @_;
    $self -> {item_list} = [ @_ ];

    return $self;
}
    
sub _load_item_list {
    my $self = shift;

    my $item_list = $self -> {item_list} or return undef;

    my @ItemList = ( );
         
    my $last_item;
    no warnings;
    foreach my $item ( @$item_list ) {
        push @ItemList, $last_item = Algorithm::Dependency::Item -> new( 
            $item -> getAttribute('name'),
            (map { $_ -> getAttribute($self ->{attr_name}) }
                ( grep { $_ -> getAttribute('ignore') ne 'yes' } ($item -> findnodes($self -> {dep_name}))))
        );
    }

    return \@ItemList;
}

}

1;

__END__
