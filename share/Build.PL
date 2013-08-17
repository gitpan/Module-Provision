# @(#)$Ident: Build.PL 2013-08-17 15:12 pjf ;

# Local Variables:
# mode: perl
# eval: (load-project-state "[% appdir %]")
# tab-title: [% project %]
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:

use strict;
use warnings;
use version; our $VERSION = qv( '0.1' );

use File::Spec::Functions   qw( catfile );
use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver   = [% perl %];
my $module     = '[% project %]';
my $class_path = catfile( 'lib', split m{ :: }mx, "${module}.pm" );

$] >= $perl_ver or $ENV{PERL5_CPANPLUS_IS_VERSION}
   or whimper "Minimum required Perl version is ${perl_ver}";

Module::Build->subclass( code => do { local $/; <DATA> } )->new
   (  add_to_cleanup      => [ 'Debian_CPANTS.txt', 'MANIFEST.bak',
                               '[% distname %]-*',
                               map { ( '*/' x $_ ).'*~' } 0 .. 5 ],
      build_requires      => {
         'version'        => 0.88,
         'Module::Build'  => 0.4004, },
      configure_requires  => {
         'version'        => 0.88,
         'Module::Build'  => 0.4004, },
      create_license      => 1,
      create_packlist     => 0,
      create_readme       => 1,
      dist_version_from   => $class_path,
      license             => '[% license %]' || 'perl',
      meta_merge          => __get_resources(),
      module_name         => $module,
      no_index            => { directory => [ qw( examples inc share t ) ] },
      notes               => {
         create_readme_md => 1,
         min_perl_version => $perl_ver,
         url_prefix       => 'https://metacpan.org/module/', },
      recommends          => {
         'App::cpanminus' => 1.6005, },
      requires            => {
         'perl'           => $perl_ver,
         'Class::Usul'    => '0.22.0', },
      sign                => 1,
      share_dir           => -d 'share' ? 'share' : undef,
   )->create_build_script; # Goal!

exit 0;

sub __get_resources {
   my $distname  = '[% distname %]';
   my $home_page = '[% home_page %]',
   my $tracker   = 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=';
   my $resources = {};

   $resources->{bugtracker} = $tracker.$distname;
   $home_page and $resources->{homepage} = $home_page;
   $resources->{license} = 'http://dev.perl.org/licenses/';

   # Only get repository info when authoring a distribution
   my $repo; -f 'MANIFEST.SKIP' and $repo = __get_repository()
      and $resources->{repository} = $repo;

   return { resources => $resources };
}

sub __get_repository { # Accessor for the VCS repository information
   my $repo;

   -d q(.git) and $repo = __get_git_repository() and return $repo;
   -d q(.svn) and $repo = __get_svn_repository() and return $repo;

   return;
}

sub __get_git_repository {
   return (map  { s{ : }{/}mx; s{ @ }{://}mx; $_ }
           grep { m{ \A git }mx }
           map  { s{ \s+ }{ }gmx; (split ' ', $_)[ 1 ] }
           grep { m{ \A origin }mx }
              qx{ git remote -v 2>/dev/null })[ 0 ];
}

sub __get_svn_repository {
   return (grep { ! m{ \A file: }mx }
           (split q( ), (grep { m{ \A URL: }mx }
                            qx{ svn info })[ 0 ])[ 1 ])[ 0 ];
}

__DATA__

sub ACTION_distmeta {
   my $self = shift;

   $self->notes->{create_readme_md} and $self->_create_readme_md();

   return $self->SUPER::ACTION_distmeta;
}

# Private methods
sub _create_readme_md {
   print "Creating README.md using Pod::Markdown\n"; require Pod::Markdown;

   # Monkey patch Pod::Markdown to allow for configurable URL prefixes
   no warnings qw(redefine); *Pod::Markdown::_resolv_link = \&_my_resolve_link;

   my $self   = shift;
   my $parser = Pod::Markdown->new( url_prefix => $self->notes->{url_prefix} );
   my $path   = $self->dist_version_from;

   open my $in,  '<', $path       or die "Path ${path} cannot open: ${!}";
   $parser->parse_from_filehandle( $in ); close $in;
   open my $out, '>', 'README.md' or die "File README.md cannot open: ${!}";
   print {$out} $parser->as_markdown; close $out;
   return;
}

sub _my_resolve_link {
   my ($self, $cmd, $arg) = @_; local $self->_private->{InsideLink} = 1;

   my ($text, $inferred, $name, $section, $type) =
      map { $_ && $self->interpolate( $_, 1 ) }
      Pod::ParseLink::parselink( $arg );
   my $url = q();

   if    ($type eq q(url)) { $url = $name }
   elsif ($type eq q(man)) {
      my ($page, $part) = $name =~ m{ \A ([^\(]+) (?:[\(] (\S*) [\)])? }mx;
      my $prefix = $self->{man_prefix} || q(http://man.he.net/man);

      $url = $prefix.($part || 1).q(/).($page || $name);
   } else {
      my $prefix = $self->{url_prefix} || q(http://search.cpan.org/perldoc?);

      $name    and $url  = "${prefix}${name}";
      $section and $url .= "#${section}";
   }

   $url and return sprintf '[%s](%s)', ($text || $inferred), $url;

   return sprintf '%s<%s>', $cmd, $arg;
}

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs; return $p;
}
