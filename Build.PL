# @(#)$Ident: DZ_Build.PL 2013-08-15 13:04 pjf ;

use strict;
use warnings;

use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $name     = 'Module-Provision'; $name =~ s{ - }{::}gmx;

$] >= $perl_ver or $ENV{PERL5_CPANPLUS_IS_VERSION}
   or whimper "Minimum required Perl version is ${perl_ver}";

Module::Build->subclass( code => do { local $/; <DATA> } )->new(
  'module_name' => $name,
  'notes'       => { min_perl_version => $perl_ver },
  'build_requires' => {
    'File::DataClass' => 'v0.24.0',
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'CPAN::Uploader' => '0.103004',
    'Class::Null' => '2.101420',
    'Class::Usul' => 'v0.24.0',
    'Date::Format' => '2.24',
    'Dist::Zilla' => '4.300033',
    'Dist::Zilla::Plugin::ManifestInRoot' => 'v0.1.0',
    'Dist::Zilla::Plugin::MarkdownInRoot' => 'v0.1.0',
    'Dist::Zilla::Plugin::Meta::Dynamic::Config' => '0.04',
    'Dist::Zilla::Plugin::ModuleBuild::Custom' => '4.16',
    'Dist::Zilla::Plugin::ReadmeAnyFromPod' => '0.120120',
    'Dist::Zilla::Plugin::Signature' => '1.100930',
    'Dist::Zilla::Plugin::VersionFromModule' => '0.08',
    'File::DataClass' => 'v0.24.0',
    'File::ShareDir' => '1.02',
    'File::Slurp' => '9999.13',
    'HTTP::Message' => '6.06',
    'LWP' => '6.04',
    'LWP::Protocol::https' => '6.03',
    'Module::Install' => '1.06',
    'Module::Install::AutoLicense' => '0.08',
    'Module::Install::ReadmeFromPod' => '0.20',
    'Module::Install::ReadmeMarkdownFromPod' => '0.03',
    'Module::Metadata' => '1.000011',
    'Moo' => '1.003',
    'MooX::Options' => '3.83',
    'Perl::Version' => '1.011',
    'Pod::Eventual' => '0.093330',
    'Pod::Markdown' => '1.322',
    'Template' => '2.22',
    'Type::Tiny' => '0.012',
    'Unexpected' => 'v0.8.0',
    'namespace::sweep' => '0.006',
    'perl' => '5.010001'
  },
  'share_dir' => {
    'dist' => 'share'
  },
)->create_build_script;

exit 0;

__DATA__

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs; return $p;
}
