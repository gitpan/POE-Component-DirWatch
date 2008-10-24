#!/usr/bin/perl

use strict;

use POE;
use FindBin qw($Bin);
use File::Path;
use Path::Class qw/dir file/;
use Test::More  tests => 6;
use POE::Component::DirWatch;

my %FILES = (foo => 1, bar => 1);
my $DIR   = dir($Bin, 'watch');
my $state = 0;
my %seen;

POE::Session->create(
     inline_states =>
     {
      _start       => \&_tstart,
      _stop        => \&_tstop,
     },
    );

$poe_kernel->run();
ok(1, 'Proper shutdown detected');

exit 0;

sub _tstart {
  my ($kernel, $heap) = @_[KERNEL, HEAP];
  # create a test directory with some test files
  $DIR->rmtree;
  $DIR->mkpath or die "can't create $DIR: $!\n";
  for my $file (keys %FILES) {
    my $path = file($DIR, $file);
    if(my $fh = $path->openw){
      print $fh rand();
    } else {
      die "Can't create $path: $!\n";
    }
  }

  my $callback = sub {
    my $file = shift;
    ok(exists $FILES{$file->basename}, 'correct file');
    ++$seen{$file->basename};

    # don't loop
    if (++$state == keys %FILES) {
      is_deeply(\%FILES, \%seen, 'seen all files');
      $poe_kernel->call(dirwatch_test => 'shutdown');
    } elsif ($state > keys %FILES) {
      $DIR->rmtree;
      die "We seem to be looping, bailing out\n";
    }
  };

  my $watcher =  POE::Component::DirWatch->new
    (
     alias     => 'dirwatch_test',
     interval  => 1,
     file_callback => $callback,
     directory => $DIR,
    );

  ok($watcher->alias eq 'dirwatch_test', 'Alias successfully set');
}

sub _tstop{
  ok($DIR->rmtree, 'Proper cleanup detected');
}

__END__
