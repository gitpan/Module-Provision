use [% perl %];
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );

name     '[% distname %]';
all_from '[% dist_module %]';
author   q{[% author %] <[% author_email %]>};
license  '[% license %]';

perl_version [% perl %];

configure_requires
   ( 'version'          => 0.77,
     'Module::Install'  => 0, );

build_requires
   ( 'Exception::Class' => 1.23,
     'Test::More'       => 0.74, );

requires
   ( 'version'          => 0.77,
     'Class::Usul'      => q(0.16.0),
     'File::DataClass'  => q(0.17.0), );

recommends
   ( 'App::cpanminus'   => 1.6005,
     'Date::Format'     => 2.24,
     'Pod::Markdown'    => 1.322,
     'Module::Metadata' => 1.000011, );

resources
   ( bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=[% distname %]',
     #homepage   => '[% home_page %]',
     #IRC        => 'irc://irc.perl.org/#[% distname %]',
     license    => 'http://dev.perl.org/licenses/',
     #repository => 'git://github.com/[% author_id %]/[% distname %].git',
     );

readme_from '[% dist_module %]';
readme_markdown_from '[% dist_module %]';
tests_recursive( 't' );

install_as_cpan;
auto_license;
auto_install;
WriteAll;

# Local Variables:
# mode: perl
# eval: (load-project-state "[% appdir %]")
# tab-title: [% project %]
# tab-width: 3
# End:
