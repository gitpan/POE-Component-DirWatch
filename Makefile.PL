#!/usr/bin/perl
# $Id: Makefile.PL,v 1.1 2002/07/04 17:36:39 eric Exp $

use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME         => 'POE::Component::DirWatch',
    AUTHOR       => 'Eric Cholet <cholet@logilune.com>',
    ABSTRACT     => 'POE component watches a directory for files.',
    VERSION_FROM => 'DirWatch.pm',

    PM           => { 'DirWatch.pm' => '$(INST_LIBDIR)/DirWatch.pm' },
    PREREQ_PM    => { POE        => 0.12,
                      Test::More => 0,
                    },
    dist         => { COMPRESS => 'gzip -9f',
                      SUFFIX   => 'gz',
                    },
  );
