# @(#)Ident: CreatingDistributions.pm 2013-05-15 17:35 pjf ;

package Module::Provision::TraitFor::CreatingDistributions;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.16.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions        qw(emit throw trim);
use Cwd                           qw(getcwd);
use MooseX::Types::Common::String qw(NonEmptySimpleStr);

requires qw(appbase appldir branch builder exec_perms homedir
            incdir project_file render_templates stash testdir vcs);

# Object attributes (public)
has 'editor'     => is => 'ro', isa => NonEmptySimpleStr, lazy => TRUE,
   documentation => 'Which text editor to use',
   default       => sub { $_[ 0 ]->config->editor };

# Construction
around '_build__appldir' => sub {
   my ($next, $self, @args) = @_; my $appldir = $self->$next( @args );

   return !$appldir && $self->method eq 'dist'
          ? $self->appbase->catdir( $self->branch ) : $appldir ;
};

around '_build_builder' => sub {
   my ($next, $self, @args) = @_; my $builder = $self->$next( @args );

   return !$builder && $self->method eq 'dist'
        ? $self->config->builder : $builder;
};

around '_build_project' => sub {
   my ($next, $self, @args) = @_; my $project;

   $self->method eq 'dist' and $project = shift @{ $self->extra_argv }
      and return $project;

   return $self->$next( @args );
};

around '_build_vcs' => sub {
   my ($next, $self, @args) = @_; my $vcs = $self->$next( @args );

   return $vcs eq 'none' && $self->method eq 'dist' ? $self->config->vcs : $vcs;
};

# Public Methods
sub create_directories {
   my $self = shift; my $perms = $self->exec_perms;

   $self->output( $self->loc( 'Creating directories' ) );
   $self->appldir->exists or $self->appldir->mkpath( $perms );
   $self->builder eq 'MB'
      and ($self->incdir->exists or $self->incdir->mkpath( $perms ));
   $self->testdir->exists or $self->testdir->mkpath( $perms );
   $self->homedir->parent->exists or $self->homedir->parent->mkpath( $perms );
   return;
}

sub dist : method {
   my $self = shift;

   $self->dist_pre_hook;
   $self->create_directories;
   $self->render_templates;
   $self->dist_post_hook;
   return OK;
}

sub dist_post_hook {
   my $self = shift;

   $self->generate_metadata( TRUE ); $self->prove;

   return;
}

sub dist_pre_hook {
   my $self = shift; my $argv = $self->extra_argv; umask $self->_create_mask;

   $self->appbase->exists or $self->appbase->mkpath( $self->exec_perms );
   $self->stash->{abstract} = shift @{ $argv } || $self->stash->{abstract};
   $self->chdir( $self->appbase );
   return;
}

sub edit_project : method {
   my $self = shift; my $path = $self->_project_file_path;

   $self->run_cmd( $self->editor.SPC.$path, { async => TRUE } );
   return OK;
}

sub generate_metadata {
   my ($self, $create) = @_; $self->chdir( $self->appldir );

   my $mdf; my $verbose = $create ? FALSE : TRUE;

   if ($self->builder eq 'DZ') {
      $self->run_cmd( 'dzil build', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( 'dzil clean' );
      $mdf = 'README.mkdn';
   }
   elsif ($self->builder eq 'MB') {
      $self->run_cmd( 'perl '.$self->project_file );
      $self->run_cmd( './Build manifest', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( './Build distmeta', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( './Build distclean' );
      $mdf = 'README.md';
   }
   elsif ($self->builder eq 'MI') {
      $self->run_cmd( 'perl '.$self->project_file );
      $self->run_cmd( 'make manifest', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( 'make clean' );
      $mdf = 'README.mkdn';
   }

   return $create ? $mdf : undef;
}

sub metadata : method {
   my $self = shift; $self->generate_metadata( FALSE ); return OK;
}

sub prove : method {
   my $self = shift; $self->chdir( $self->appldir );

   my $cmd = $self->builder eq 'DZ' ? 'dzil test' : 'prove t';

   $ENV{AUTHOR_TESTING} = TRUE; $ENV{TEST_MEMORY} = TRUE;
   $ENV{TEST_SPELLING}  = TRUE;
   $self->output ( 'Testing '.$self->appldir );
   $self->run_cmd( $cmd, $self->quiet ? {} : { out => 'stdout' } );
   return OK;
}

sub show_tab_title : method {
   my $self = shift;
   my $file = $self->extra_argv->[ 0 ] || $self->_project_file_path;
   my $text = (grep { m{ tab-title: }msx } $self->io( $file )->getlines)[ -1 ];

   emit trim( (split m{ : }msx, $text || NUL, 2)[ 1 ] );
   return OK;
}

# Private methods
sub _create_mask {
   return oct q(0777) ^ $_[ 0 ]->exec_perms;
}

sub _project_file_path {
   return $_[ 0 ]->appldir->catfile( $_[ 0 ]->project_file );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::CreatingDistributions - Create distributions

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::CreatingDistributions';

=head1 Version

This documents version v0.16.$Rev: 1 $ of L<Module::Provision::TraitFor::CreatingDistributions>

=head1 Description

Create distributions using either Git or SVN for the VCS

=head1 Configuration and Environment

Requires these attributes to be defined in the consuming class;
C<appbase>, C<appldir>, C<builder>, C<exec_perms>, C<homedir>,
C<incdir>, C<project_file>, C<render_templates>, C<stash>, C<testdir>,
and C<vcs>

Defines the following attributes;

=over 3

=item <editor>

Which text editor to use. It is a read only, lazily evaluated, simple
string that cannot be null. It defaults to the C<editor> configuration
variable

=back

=head1 Subroutines/Methods

=head2 create_directories

   $self->create_directories;

Creates the required directories for the new distribution. If subclassed this
method can be modified to include additional directories

=head2 dist

   $exit_code = $self->dist;

Create a new distribution specified by the module name on the command line

=head2 dist_post_hook

   $self->dist_post_hook;

Runs after the new distribution has been created. If subclassed this method
can be modified to perform additional actions after the templates have been
rendered

=head2 dist_pre_hook

   $self->dist_pre_hook;

Runs before the new distribution is created. If subclassed this method
can be modified to perform additional actions before the project directories
are created

=head2 edit_project

   $exit_code = $self->edit_project;

Edit the project file (one of; F<dist.ini>, F<Build.PL>, or
F<Makefile.PL>) in the current directory

=head2 generate_metadata

   $markdown_file = $self->generate_metadata( $create_flag );

Generates the distribution metadata files. If the create_flag is C<TRUE>
returns the name of the F<README.md> file

=head2 metadata

   $exit_code = $self->metadata;

Calls L</generate_metadata> with the create flag set to C<FALSE>

=head2 prove

   $exit_code = $self->prove;

Tests the distribution

=head2 show_tab_title

   $exit_code = $self->show_tab_title;

Print the tab title for the current project to C<STDOUT>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Moose::Role>

=item L<MooseX::Types::Common::String>

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
