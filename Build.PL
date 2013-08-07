# @(#)Ident: Build.PL 2013-08-07 17:53 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 1 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'Module::Provision',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'                  => 5.010001,
      'namespace::sweep'      => 0.006,
      'Class::Null'           => 2.101420,
      'Class::Usul'           => q(0.23.0),
      'CPAN::Uploader'        => 0.103004,
      'Date::Format'          => 2.24,
      'Dist::Zilla'           => 4.300033,
      'Dist::Zilla::Plugin::ManifestInRoot'    => q(0.1.2),
      'Dist::Zilla::Plugin::ReadmeAnyFromPod'  => 0.120120,
      'Dist::Zilla::Plugin::VersionFromModule' => 0.08,
      'File::DataClass'       => q(0.23.0),
      'File::ShareDir'        => 1.02,
      'File::Slurp'           => 9999.13,
      'HTTP::Message'         => 6.06,
      'LWP::Protocol::https'  => 6.03,
      'LWP'                   => 6.04,
      'Module::Install'       => 1.06,
      'Module::Install::AutoLicense'           => 0.08,
      'Module::Install::ReadmeFromPod'         => 0.20,
      'Module::Install::ReadmeMarkdownFromPod' => 0.03,
      'Module::Metadata'      => 1.000011,
      'Moo'                   => 1.003,
      'MooX::Options'         => 3.83,
      'Perl::Version'         => 1.011,
      'Pod::Eventual'         => 0.093330,
      'Pod::Markdown'         => 1.322,
      'Template'              => 2.22,
      'Type::Tiny'            => 0.012,
      'Unexpected'            => q(0.6.0), },
   recommends                 => {
      'App::cpanminus'        => 1.6005, },
   configure_requires         => {
      'version'               => 0.88,
      'Module::Build'         => 0.4004, },
   build_requires             => {
      'version'               => 0.88,
      'File::DataClass'       => q(0.23.0),
      'Module::Build'         => 0.4004, },
   no_index_dir               => [ qw(bin examples inc share t) ],
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Provision
# eval: (load-project-state "module-provision")
# mode: perl
# tab-width: 3
# End:
