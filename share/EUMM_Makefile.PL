use [% perl %];
use strict;
use warnings FATAL => 'all';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );

use ExtUtils::MakeMaker;

WriteMakefile
   ( NAME               => '[% project %]',
     AUTHOR             => q{[% author %] <[% author_email %]>},
     VERSION_FROM       => '[% dist_module %]',
     ABSTRACT_FROM      => '[% dist_module %]',
     LICENSE            => '[% license %]',
     PL_FILES           => {},
     MIN_PERL_VERSION   => [% perl %],
     CONFIGURE_REQUIRES => {
        'version'             => 0.77,
        'ExtUtils::MakeMaker' => 0,
     },
     BUILD_REQUIRES => {
        'Exception::Class' => 1.23,
        'Test::More'       => 0.74,
     },
     PREREQ_PM => {
        'version'          => 0.77,
        'Class::Usul'      => q(0.14.0),
        'File::DataClass'  => q(0.16.0),
     },
     dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
     clean => { FILES => '[% distname %]-*' }, );
