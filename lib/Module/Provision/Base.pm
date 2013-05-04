# @(#)Ident: Base.pm 2013-05-04 19:12 pjf ;

package Module::Provision::Base;

use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(app_prefix class2appdir classdir distname
                                    throw);
use Class::Usul::Time            qw(time2str);
use Cwd                          qw(getcwd);
use File::DataClass::Constraints qw(Directory OctalNum Path);

extends q(Class::Usul::Programs);

enum __PACKAGE__.'::Builder' => qw(DZ MB MI);
enum __PACKAGE__.'::VCS'     => qw(git none svn);

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( Path, '=s' );

my %builders = ( 'DZ' => 'dist.ini', 'MB' => 'Build.PL', 'MI' => 'Makefile.PL');

# Override defaults in base class
has '+config_class' => default => sub { 'Module::Provision::Config' };

# Object attributes (public)
#   Visible to the command line
has 'base'       => is => 'lazy', isa => Path, coerce => TRUE,
   documentation => 'Directory containing new projects',
   default       => sub { $_[ 0 ]->config->base };

has 'branch'     => is => 'lazy', isa => NonEmptySimpleStr,
   documentation => 'The name of the initial branch to create',
   default       => sub { $_[ 0 ]->config->branch };

has 'builder'    => is => 'lazy', isa => __PACKAGE__.'::Builder',
   documentation => 'Which build system to use: DZ, MB, or MI';

has 'license'    => is => 'ro',   isa => NonEmptySimpleStr,
   documentation => 'License used for the project',
   default       => sub { $_[ 0 ]->config->license };

has 'perms'      => is => 'ro',   isa => OctalNum, coerce => TRUE,
   documentation => 'Default permission for file / directory creation',
   default       => '640';

has 'project'    => is => 'lazy', isa => NonEmptySimpleStr,
   documentation => 'Package name of the new projects main module';

has 'repository' => is => 'ro',   isa => NonEmptySimpleStr,
   documentation => 'Directory containing the SVN repository',
   default       => sub { $_[ 0 ]->config->repository };

has 'vcs'        => is => 'lazy', isa => __PACKAGE__.'::VCS',
   documentation => 'Which VCS to use: git, none, or svn';

#   Ingnored by the command line
has '_appbase'         => is => 'lazy', isa => Path, coerce => TRUE,
   reader              => 'appbase';

has '_appldir'         => is => 'lazy', isa => Path, coerce => TRUE,
   reader              => 'appldir';

has '_binsdir'         => is => 'lazy', isa => Path, coerce => TRUE,
   default             => sub { [ $_[ 0 ]->appldir, 'bin' ] },
   reader              => 'binsdir';

has '_dist_module'     => is => 'lazy', isa => Path, coerce => TRUE,
   default             => sub { [ $_[ 0 ]->homedir.'.pm' ] },
   reader              => 'dist_module';

has '_distname'        => is => 'lazy', isa => NonEmptySimpleStr,
   default             => sub { distname $_[ 0 ]->project },
   reader              => 'distname';

has '_exec_perms'      => is => 'lazy', isa => PositiveInt,
   reader              => 'exec_perms';

has '_homedir'         => is => 'lazy', isa => Path, coerce => TRUE,
   reader              => 'homedir';

has '_incdir'          => is => 'lazy', isa => Path, coerce => TRUE,
   default             => sub { [ $_[ 0 ]->appldir, 'inc' ] },
   reader              => 'incdir';

has '_initial_wd'      => is => 'ro',   isa => Directory, coerce => TRUE,
   default             => sub { [ getcwd ] }, reader => 'initial_wd';

has '_libdir'          => is => 'lazy', isa => Path, coerce => TRUE,
   default             => sub { [ $_[ 0 ]->appldir, 'lib' ] },
   reader              => 'libdir';

has '_module_abstract' => is => 'lazy', isa => NonEmptySimpleStr,
   reader              => 'module_abstract';

has '_project_file'    => is => 'lazy', isa => NonEmptySimpleStr,
   reader              => 'project_file';

has '_stash'           => is => 'lazy', isa => HashRef, reader => 'stash';

has '_testdir'         => is => 'lazy', isa => Path, coerce => TRUE,
   default             => sub { [ $_[ 0 ]->appldir, 't' ] },
   reader              => 'testdir';

# Object attributes (private)
has '_license_keys'    => is => 'lazy', isa => HashRef;

# Private methods
sub _build__appbase {
   my $self = shift; my $base = $self->base->absolute( $self->initial_wd );

   return $base->catdir( $self->distname );
}

sub _build__appldir {
   return $_[ 0 ]->vcs eq 'svn' ? $_[ 0 ]->appbase->catdir( $_[ 0 ]->branch )
                                : $_[ 0 ]->appbase;
}

sub _build_builder {
   my $self = shift; my $appldir = $self->appldir;

   for (grep { $_->[ 1 ]->exists }
        map  { [ $_, $appldir->catfile( $builders{ $_ } ) ] } keys %builders) {
      return $_->[ 0 ];
   }

   return undef;
}

sub _build__exec_perms {
   return (($_[ 0 ]->perms & oct q(0444)) >> 2) | $_[ 0 ]->perms;
}

sub _build__homedir {
   return [ $_[ 0 ]->libdir, classdir $_[ 0 ]->project ];
}

sub _build__license_keys {
   return {
      perl       => 'Perl_5',
      perl_5     => 'Perl_5',
      apache     => [ map { "Apache_$_" } qw(1_1 2_0) ],
      artistic   => 'Artistic_1_0',
      artistic_2 => 'Artistic_2_0',
      lgpl       => [ map { "LGPL_$_" } qw(2_1 3_0) ],
      bsd        => 'BSD',
      gpl        => [ map { "GPL_$_" } qw(1 2 3) ],
      mit        => 'MIT',
      mozilla    => [ map { "Mozilla_$_" } qw(1_0 1_1) ], };
}

sub _build__module_abstract {
   return $_[ 0 ]->loc( $_[ 0 ]->config->module_abstract );
}

sub _build_project {
   my $self = shift; my $project = shift @{ $self->extra_argv };

   $project and return $project; my $dir = $self->io( getcwd ); my $prev;

   while (not $prev or $prev ne $dir) {
      for my $file (grep { $_->exists }
                    map  { $dir->catfile( $builders{ $_ } ) } keys %builders) {
         $project = __get_module_from( $file->all ) and return $project;
         throw 'Main module name not found';
      }

      $prev = $dir; $dir = $dir->parent;
   }

   throw error => 'File [_1] not in path', args => [ $self->project_file ];
   return; # Never reached
}

sub _build__project_file {
   return $builders{ $_[ 0 ]->builder };
}

sub _build__stash {
   my $self = shift; my $config = $self->config;

   my $author = $config->author; my $project = $self->project;

   return { abstract       => $self->module_abstract,
            appdir         => class2appdir $self->distname,
            author         => $author,
            author_email   => $config->author_email,
            author_id      => $config->author_id,
            copyright      => $ENV{ORGANIZATION} || $author,
            copyright_year => time2str( '%Y' ),
            creation_date  => time2str,
            dist_module    => $self->dist_module->abs2rel( $self->appldir ),
            distname       => $self->distname,
            first_name     => lc ((split SPC, $author)[ 0 ]),
            home_page      => $config->home_page,
            last_name      => lc ((split SPC, $author)[ -1 ]),
            license        => $self->license,
            license_class  => $self->_license_keys->{ $self->license },
            module         => $project,
            perl           => $],
            prefix         => (split m{ :: }mx, lc $project)[ -1 ],
            project        => $project, };
}

sub _build_vcs {
   my $self = shift; my $appbase = $self->appbase;

   return $appbase->catdir( $self->repository )->exists ? 'svn'
        : $appbase->catdir( '.git'            )->exists ? 'git'
                                                        : 'none';
}

# Private functions
sub __get_module_from { # Return main module name from contents of project file
   return
      (map    { s{ [-] }{::}gmx; $_ }
       map    { m{ \A [q\'\"] }mx ? eval $_ : $_ }
       map    { m{ \A \s* (?:module|name) \s+ [=]?[>]? \s* ([^,;]+) [,;]? }imx }
       grep   { m{ \A \s*   (module|name) }imx }
       split m{ [\n] }mx, $_[ 0 ])[ 0 ];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::Base - Immutable data object

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';

=head1 Version

This documents version v0.11.$Rev: 1 $ of L<Module::Provision::Base>

=head1 Description

Creates an immutable data object used by the methods in the applied traits

=head1 Configuration and Environment

Defines the following list of attributes which can be set from the
command line;

=over 3

=item C<base>

The directory which will contain the new project. Defaults to the users
home directory

=item C<branch>

The name of the initial branch to create. Defaults to F<master> for
Git and F<trunk> for SVN

=item C<builder>

Which of the three build systems to use. Defaults to C<MB>, which is
L<Module::Build>. Can be C<DZ> for L<Dist::Zilla> or C<MI> for
L<Module::Install>

=item C<license>

The name of the license used on the project. Defaults to C<perl>

=item C<perms>

Permissions used to create files. Defaults to C<644>. Directories and
programs have the execute bit turned on if the corresponding read bit
is on

=item C<project>

The class name of the new project. Should be the first extra argument on the
command line

=item C<repository>

Name of the directory containing the SVN repository. Defaults to F<repository>

=item C<vcs>

The version control system to use. Defaults to C<none>, can be C<git>
or C<svn>

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<File::DataClass>

=item L<Module::Provision::Config>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
