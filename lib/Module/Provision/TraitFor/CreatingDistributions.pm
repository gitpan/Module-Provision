# @(#)Ident: CreatingDistributions.pm 2013-05-02 18:28 pjf ;

package Module::Provision::TraitFor::CreatingDistributions;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);
use Cwd                    qw(getcwd);

requires qw(appbase appldir builder exec_perms homedir
            incdir project_file stash testdir);

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

   $self->pre_hook;
   $self->create_directories;
   $self->populate_directories;
   $self->post_hook;
   return OK;
}

sub generate_metadata : method {
   shift->_generate_metadata( FALSE ); return OK;
}

sub populate_directories {
}

sub post_hook {
   my $self = shift;

   $self->_generate_metadata( TRUE );
   $self->test_distribution;
   return;
}

sub pre_hook {
   my $self = shift; my $argv = $self->extra_argv; umask $self->_create_mask;

   $self->appbase->exists or $self->appbase->mkpath( $self->exec_perms );
   $self->stash->{abstract} = shift @{ $argv } || $self->stash->{abstract};
   __chdir( $self->appbase );
   return;
}

sub test_distribution {
   my $self = shift; __chdir( $self->appldir );

   my $cmd = $self->builder eq 'DZ' ? 'dzil test' : 'prove t';

   $ENV{AUTHOR_TESTING} = TRUE; $ENV{TEST_SPELLING} = TRUE;
   $self->output ( 'Testing '.$self->appldir );
   $self->run_cmd( $cmd, $self->quiet ? {} : { out => 'stdout' } );
   return;
}

# Private methods
sub _create_mask {
   my $self = shift; return oct q(0777) ^ $self->exec_perms;
}

sub _generate_metadata {
   my ($self, $create) = @_; __chdir( $self->appldir );

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

# Private functions
sub __chdir {
   $_[ 0 ] or throw 'Directory not specified'; chdir $_[ 0 ];
   $_[ 0 ] eq getcwd or throw error => 'Path [_1] cannot change to',
                              args  => [ $_[ 0 ] ];
   return $_[ 0 ];
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

This documents version v0.9.$Rev: 5 $ of L<Module::Provision::TraitFor::CreatingDistributions>

=head1 Description

Create distributions using either Git or SVN for the VCS

=head1 Configuration and Environment

Requires these attributes to be defined in the consuming class;
C<appbase>, C<appldir>, C<builder>, C<exec_perms>, C<homedir>,
C<incdir>, C<project_file>, C<stash>, C<testdir>, and C<vcs>

Defines no attributes

=head1 Subroutines/Methods

=head2 create_directories

   $self->create_directories;

Creates the required directories for the new distribution. If subclassed this
method can be modified to include additional directories

=head2 dist

   $exit_code = $self->dist;

Create a new distribution specified by the module name on the command line

=head2 generate_metadata

   $exit_code = $self->generate_metadata;

Generates the distribution metadata files

=head2 populate_directories

   $self->populate_directories;

An empty subroutine to modify in another role

=head2 post_hook

   $self->post_hook;

Runs after the new distribution has been created. If subclassed this method
can be modified to perform additional actions after the templates have been
rendered

=head2 pre_hook

   $self->pre_hook;

Runs before the new distribution is created. If subclassed this method
can be modified to perform additional actions before the project directories
are created

=head2 test_distribution

   $self->test_distribution;

Tests the distribution

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Moose::Role>

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
