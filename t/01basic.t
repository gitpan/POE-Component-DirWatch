#!/usr/bin/perl
#
#$Id: 01basic.t,v 1.5 2002/07/04 22:15:35 eric Exp $

use strict;
use FindBin    qw($Bin);
use File::Spec;
use File::Path qw(rmtree);
use POE;

our %FILES = map { $_ =>  1 } qw(foo bar);
use Test::More;
plan tests => 2 + 3 * keys %FILES;

use_ok('POE::Component::DirWatch');

our $DIR   = File::Spec->catfile($Bin, 'watch');
our $state = 0;
our %seen;

POE::Session->create(
    inline_states => {
              _start       => \&_start,
              _stop        => \&_stop,
              gotfile      => \&gotfile,
    },
);
$poe_kernel->run();
exit 0;

sub _start
{
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    # create a test directory with some test files
    rmtree $DIR;
    mkdir($DIR, 0755) or die "can't create $DIR: $!\n";
    for my $file (keys %FILES) {
        my $path = File::Spec->catfile($DIR, $file);
        open FH, ">$path" or die "can't create $path: $!\n";
        close FH;
    }
    POE::Component::DirWatch->spawn(
        Directory    => $DIR,
        PollInterval => 1,
        Callback     => \&gotfile,
    );
}
sub _stop
{
    my $heap = $_[HEAP];
    rmtree $DIR;
}

sub gotfile
{
    my ($kernel, $file, $pathname) = @_[KERNEL, ARG0, ARG1];
    ok(1, 'callback has been called');
    ok(exists $FILES{$file}, 'correct file');
    ++$seen{$file};
    is($pathname, File::Spec->catfile($DIR, $file), 'correct path');

    # don't loop
    if (++$state == keys %FILES) {
        is_deeply(\%FILES, \%seen, 'seen all files');
        $kernel->post(dirwatch => 'shutdown');
    }
    elsif ($state > keys %FILES) {
        rmtree $DIR;
        die "We seem to be looping, bailing out\n";
    }
}

__END__
