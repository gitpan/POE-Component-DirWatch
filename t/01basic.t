#!/usr/bin/perl
#
#$Id: 01basic.t,v 1.5 2002/07/04 22:15:35 eric Exp $

use strict;
use FindBin qw($Bin);
use File::Spec;
use Test;

BEGIN { plan tests => 3 }

use POE;
use POE::Component::DirWatch;

use constant DIR  => File::Spec->catfile($Bin, 'watch');
use constant FILE => 'foo.txt';
use constant PATH => File::Spec->catfile(DIR, FILE);

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

    # create a test directory with a test file
    unlink PATH;
    rmdir DIR;
    mkdir(DIR, 0755) or die "can't create ".DIR.": $!\n";
    open FH, '>'.PATH or die "can't create ".PATH.": $!\n";
    close FH;

    POE::Component::DirWatch->spawn(
        Directory    => DIR,
        PollInterval => 1,
        Callback     => \&gotfile,
    );
}
sub _stop
{
    my $heap = $_[HEAP];
    unlink PATH;
    rmdir DIR;
}

sub gotfile
{
    my ($kernel, $file, $pathname) = @_[KERNEL, ARG0, ARG1];
    ok(1);
    ok($file eq FILE);
    ok($pathname eq PATH);
    unlink PATH;
    $kernel->post(dirwatch => 'shutdown');
}

__END__
