# @(#)Ident: Build.PL 2013-04-14 19:10 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 47 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(Module::Provision),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'             => 5.010,
      'version'          => 0.77,
      'Class::Usul'      => q(0.13.0),
      'Date::Format'     => 2.24,
      'Dist::Zilla'      => 4.300033,
      'Dist::Zilla::Plugin::ReadmeAnyFromPod'  => 0.120120,
      'Dist::Zilla::Plugin::VersionFromModule' => 0.08,
      'File::DataClass'  => q(0.16.0),
      'File::ShareDir'   => 1.02,
      'Module::Build'    => 0.38,
      'Module::Metadata' => 1.000011,
      'Perl::Version'    => 1.011,
      'Pod::Markdown'    => 1.322,
      'Module::Install'  => 1.06,
      'Module::Install::AutoLicense'           => 0.08,
      'Module::Install::ReadmeFromPod'         => 0.20,
      'Module::Install::ReadmeMarkdownFromPod' => 0.03,
      'Template'         => 2.22, },
   recommends            => {
      'App::cpanminus'   => 1.6005, },
   configure_requires    => {
      'version'          => 0.77,
      'Module::Build'    => 0.38, },
   build_requires        => {
      'Exception::Class' => 1.23,
      'File::DataClass'  => q(0.16.0),
      'Test::More'       => 0.74, },
   no_index_dir          => [ qw(bin examples inc share t) ],
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Provision
# eval: (load-project-state "module-provision")
# mode: perl
# tab-width: 3
# End: