#!/usr/bin/perl
#
#$Id: DirWatch.pm,v 1.6 2002/07/05 00:47:53 eric Exp $

package POE::Component::DirWatch;
use strict;

use Carp qw(croak);
use DirHandle;
use File::Spec;
use POE;

use vars qw($VERSION);

$VERSION = '0.01';

use constant DEFAULT_ALIAS         => 'dirwatch';
use constant DEFAULT_POLL_INTERVAL => 1;
use constant DEFAULT_FILTER        => sub { -f $_[1] };

##########
sub spawn
{
  my ($class, %args) = @_;

  # required arguments
  $args{Directory} or croak "Directory not supplied\n";
  $args{Callback}  or croak "Callback not supplied\n";

  # supply default values
  $args{Alias}        ||= DEFAULT_ALIAS;
  $args{PollInterval} ||= DEFAULT_POLL_INTERVAL;
  $args{Filter}       ||= DEFAULT_FILTER;

  POE::Session->create(
     inline_states => {
              _start       => \&_start,
              _stop        => \&_stop,
              callback     => $args{Callback},
              shutdown     => \&shutdown,
              poll         => \&poll,
     },
     args => [ @args{qw(Alias Directory PollInterval Filter Callback)} ],
  );
  return $args{Alias};
}

##########
sub _start
{
  my ($kernel, $heap, $session,
      $alias, $directory, $poll_interval, $filter, $callback)
    = @_[KERNEL, HEAP, SESSION, ARG0..ARG4];

  # save args
  $heap->{Directory}    = $directory;
  $heap->{PollInterval} = $poll_interval;
  $heap->{Filter}       = $filter;
  $heap->{Callback}     = $callback;

  # set alias for ourselves and remember it
  $kernel->alias_set($alias);
  $heap->{Alias} = $alias;

  # open the directory handle
  $heap->{DirHandle} = DirHandle->new($heap->{Directory})
    or croak "Can't open $heap->{Directory}: $!\n";

  # set up polling
  $kernel->delay(poll => $heap->{PollInterval});
}
##########
sub _stop
{
  my $heap = $_[HEAP];

  # close the directory handle
  $heap->{DirHandle}->close if $heap->{DirHandle};
}
##########
sub poll
{
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  # make sure we have a directory handle
  $heap->{DirHandle} or croak "Need to run() before poll()\n";

  # rewind to directory start
  $heap->{DirHandle}->rewind;

  # look for a file that matches our filter
  for my $file ($heap->{DirHandle}->read()) {
      my @params = ($file,
                    File::Spec->catfile($heap->{Directory}, $file),
                   );
      if ($heap->{Filter}->(@params)) {
          # report it to the caller
          $kernel->yield(callback => @params);
          # poll again so we can process more than
          # one file per PollInterval
          $kernel->yield('poll');
          # and exit
          last;
      }
  }

  # arrange to be called again soon
  $kernel->delay(poll => $heap->{PollInterval});
}
##########
sub shutdown   # from the POE FAQ
{
   my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

   # delete all wheels.
   delete $heap->{wheel};

   # clear your alias
   $kernel->alias_remove($heap->{alias});

   # clear all alarms you might have set
   $kernel->alarm_remove_all();
   delete $heap->{alarms};

   # get rid of external ref count
   $kernel->refcount_decrement($session, 'my ref name');

   # propagate the message to children
   $kernel->post($heap->{child_session}, 'shutdown');
}

##########
1;

__END__

=head1 NAME

POE::Component::DirWatch - POE directory watcher

=head1 SYNOPSIS

  use POE::Component::DirWatch;

  POE::Component::DirWatch->spawn(
    Alias        => 'dirwatch',
    Directory    => '/some_dir',
    Filter       => sub { $_[0] =~ /\.gz$/ && -f $_[1] },
    Callback     => \&some_sub,
    PollInterval => 1,
  );

=head1 DESCRIPTION

POE::Component::DirWatch watches a directory for files. It creates
a separate session which invokes a user-supplied callback
as soon as it finds a file in the directory.

Its primary intended use is processing a "drop-box" style
directory, such as an FTP upload directory.

=head2 ARGUMENTS

=over 4

=item Alias

The alias for the DirWatch session.  Defaults to C<dirwatch> if not
specified.

=item Directory

The name of the directory to watch. This is a required argument.

=item PollInterval

The intervals between polls of the directory, in seconds. Default
to 1 if not specified.

=item Callback

A reference to a subroutine that will be called when a matching
file is found in the directory.

This subroutine is called with two arguments: the name of the
file, and its full pathname. It usually makes most sense to process
the file and remove it from the directory.

This is a required argument.

=item Filter

A reference to a subroutine that will be called for each file
in the watched directory. It should return a TRUE value if
the file qualifies as found, FALSE if the file is to be
ignored.

This subroutine is called with two arguments: the name of the
file, and its full pathname.

If not specified, defaults to C<sub { -f $_[1] }>.

=back

=head1 SEE ALSO

POE(3), POE::Component(3)

=head1 AUTHOR

Eric Cholet, <cholet@logilune.com>

Thanks to Matt Sergeant for POE insights and bug reports,
and David Rigaudière for Win32 testing.

=head1 COPYRIGHT

Copyright 2002 Eric Cholet.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut
