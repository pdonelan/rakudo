#! perl

# Copyright (C) 2004-2008, The Perl Foundation.
# $Id$

##  The "make spectest_regression" target tells us how many
##  tests we failed (hopefully zero!), but doesn't say how
##  many were actually passed.  This script runs the spectest_regression
##  tests and summarizes planned, actual, passed, failed, todoed,
##  and skipped test results.
##
##  Usage:
##     tools/test_summary.pl [testlist]
##
##  If supplied, C<testlist> identifies an alternate list of tests
##  to use (e.g., t/localtest.data).

use strict;
use warnings;

my $testlist = $ARGV[0] || 't/spectest_regression.data';

my $fh;
open($fh, '<', $testlist) || die "Can't read $testlist: $!";

my(@fudge, @pure);
while (<$fh>) {
    /^ *#/ && next;
    my ($specfile) = split ' ', $_;
    next unless $specfile;
    $specfile = "t/spec/$specfile";
    if (/#pure/) { push @pure, $specfile; }
    else { push @fudge, $specfile; }
}
close($fh);

if (@fudge) {
    my $cmd = join ' ', $^X, 't/spec/fudgeall', 'rakudo', @fudge;
    print "$cmd\n";
    @fudge = split ' ', `$cmd`;
}

my @tfiles = sort @pure, @fudge;
my $max = 0;
for my $tfile (@tfiles) {
    if (length($tfile) > $max) { $max = length($tfile); }
}

$| = 1;
printf "%s  plan test pass fail todo skip\n", ' ' x $max;
my %sum;
for my $tfile (@tfiles) {
    my $th;
    open($th, '<', $tfile) || die "Can't read $tfile: $!\n";
    my $plan = 0;
    while (<$th>) {
       if (/^\s*plan\D*(\d+)/) { $plan = $1; last; }
    }
    close($th);
    printf "%s%s..%4d", $tfile, '.' x ($max - length($tfile)), $plan;
    my $cmd = "../../parrot perl6.pbc $tfile";
    my @results = split "\n", `$cmd`;
    my ($test, $pass, $fail, $todo, $skip) = (0,0,0,0,0);
    my %skip;
    for (@results) {
        next unless /^(not )?ok +\d+/;
        $test++;
        if    (/#\s*SKIP\s*(.*)/i) { $skip++; $skip{$1}++; }
        elsif (/#\s*TODO/i)        { $todo++; }
        elsif (/^not ok +\d+/)     { $fail++; }
        elsif (/^ok +\d+/)         { $pass++; }
    }
    printf " %4d %4d %4d %4d %4d\n", $test, $pass, $fail, $todo, $skip;
    $sum{'plan'} += $plan;
    $sum{'test'} += $test;
    $sum{'pass'} += $pass;
    $sum{'fail'} += $fail;
    $sum{'todo'} += $todo;
    $sum{'skip'} += $skip;
    for (keys %skip) {
        printf "    %d skipped: %s\n", $skip{$_}, $_;
    }
}

my $total = "  ".scalar(@tfiles)." test files";
$total .= ' ' x ($max-length($total));
printf "%s  %4d %4d %4d %4d %4d %4d\n",
    $total, $sum{'plan'}, $sum{'test'}, $sum{'pass'},
    $sum{'fail'}, $sum{'todo'}, $sum{'skip'};