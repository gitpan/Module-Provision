# @(#)Ident: Build.PL 2013-05-11 08:48 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.14.%d', q$Rev: 1 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(Module::Provision),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'                  => 5.010,
      'namespace::autoclean'  => 0.13,
      'Class::Null'           => 2.101420,
      'Class::Usul'           => q(0.18.6),
      'Date::Format'          => 2.24,
      'Dist::Zilla'           => 4.300033,
      'Dist::Zilla::Plugin::ReadmeAnyFromPod'  => 0.120120,
      'Dist::Zilla::Plugin::VersionFromModule' => 0.08,
      'File::DataClass'       => q(0.20.7),
      'File::ShareDir'        => 1.02,
      'File::Slurp'           => 9999.13,
      'Module::Build'         => 0.4004,
      'Module::Install'       => 1.06,
      'Module::Install::AutoLicense'           => 0.08,
      'Module::Install::ReadmeFromPod'         => 0.20,
      'Module::Install::ReadmeMarkdownFromPod' => 0.03,
      'Module::Metadata'      => 1.000011,
      'Moose'                 => 2.0802,
      'Moose::Autobox'        => 0.12,
      'MooseX::Types::Common' => 0.001008,
      'MooseX::Types'         => 0.35,
      'Perl::Version'         => 1.011,
      'Pod::Eventual'         => 0.093330,
      'Pod::Markdown'         => 1.322,
      'Template'              => 2.22,
      'Text::Format'          => 0.53, },
   recommends                 => {
      'App::cpanminus'        => 1.6005, },
   configure_requires         => {
      'version'               => 0.88,
      'Module::Build'         => 0.4004, },
   build_requires             => {
      'version'               => 0.88,
      'File::DataClass'       => q(0.20.7),
      'Module::Build'         => 0.4004, },
   no_index_dir               => [ qw(bin examples inc share t) ],
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Provision
# eval: (load-project-state "module-provision")
# mode: perl
# tab-width: 3
# End:
