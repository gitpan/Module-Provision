use [% perl %];
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     '[% distname %]';
all_from '[% dist_module %]';
author   q{[% author %] <[% author_email %]>};
license  '[% license %]';

perl_version [% perl %];

requires
   ( 'Class::Usul'     => q(0.22.0), );

recommends
   ( 'App::cpanminus'  => 1.6005, );

configure_requires
   ( 'version'         => 0.88,
     'Module::Install' => 0, );

build_requires
   ( 'version'         => 0.88,
     'Module::Install' => 0, );

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
# vim: expandtab shiftwidth=3:
