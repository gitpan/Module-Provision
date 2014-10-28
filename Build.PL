# @(#)$Ident: DZ_Build.PL 2013-12-14 14:19 pjf ;

use strict;
use warnings;

use Module::Build 0.4004;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $name     = 'Module-Provision'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Module::Build' => '0.4004',
    'Test::Requires' => '0.06',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'CPAN::Uploader' => '0.103004',
    'Class::Null' => '2.101420',
    'Class::Usul' => 'v0.50.0',
    'Config::Tiny' => '2.20',
    'Date::Format' => '2.24',
    'Dist::Zilla' => '4.300033',
    'Dist::Zilla::Plugin::AbstractFromPOD' => 'v0.2.0',
    'Dist::Zilla::Plugin::LicenseFromModule' => '0.03',
    'Dist::Zilla::Plugin::ManifestInRoot' => 'v0.1.0',
    'Dist::Zilla::Plugin::Meta::Dynamic::Config' => '0.04',
    'Dist::Zilla::Plugin::ModuleBuild::Custom' => '4.16',
    'Dist::Zilla::Plugin::ReadmeAnyFromPod' => '0.141760',
    'Dist::Zilla::Plugin::Signature' => '1.100930',
    'Dist::Zilla::Plugin::VersionFromModule' => '0.08',
    'File::DataClass' => 'v0.49.0',
    'File::ShareDir' => '1.102',
    'HTTP::Message' => '6.06',
    'LWP' => '6.08',
    'LWP::Protocol::https' => '6.03',
    'Module::Install' => '1.12',
    'Module::Install::AutoLicense' => '0.08',
    'Module::Install::ReadmeFromPod' => '0.20',
    'Module::Install::ReadmeMarkdownFromPod' => '0.03',
    'Module::Metadata' => '1.000011',
    'Moo' => '1.006000',
    'Perl::Version' => '1.013',
    'Pod::Eventual' => '0.094001',
    'Software::License' => '0.103010',
    'Template' => '2.26',
    'Type::Tiny' => '1.000004',
    'Unexpected' => 'v0.34.0',
    'local::lib' => '2.000014',
    'namespace::autoclean' => '0.20',
    'perl' => '5.010001'
  },
};

if ($] < $perl_ver) {
   $ENV{AUTOMATED_TESTING}
      or $ENV{PERL_CPAN_REPORTER_CONFIG}
      or $ENV{PERL5_CPANPLUS_IS_VERSION}
      or whimper "Minimum required Perl version is ${perl_ver}";
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
}

Module::Build->new(
  'module_name' => $name,
  'notes'       => { min_perl_version => $perl_ver },
  %{ $prereqs },
  'share_dir' => {
    'dist' => 'share'
  },
)->create_build_script;

exit 0;
