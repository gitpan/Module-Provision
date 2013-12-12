# @(#)Ident: VCS.pm 2013-10-03 14:43 pjf ;

package Module::Provision::TraitFor::VCS;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.29.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( is_win32 throw );
use Class::Usul::Types      qw( Bool );
use Perl::Version;
use Scalar::Util            qw( blessed );
use Moo::Role;

requires qw( add_leader appbase appldir branch chdir config default_branch
             dist_version distname editor exec_perms get_line
             loc next_argv output quiet run_cmd vcs );

# Public attributes
has 'no_auto_rev' => is => 'ro', isa => Bool, default => FALSE,
   documentation  => 'Do not turn on Revision keyword expansion';

# Construction
around 'dist_post_hook' => sub {
   my ($next, $self, @args) = @_; $self->_initialize_vcs;

   my $r = $self->$next( @args );

   $self->vcs eq 'git' and $self->_reset_rev_file( TRUE );
   $self->vcs eq 'svn' and $self->_svn_ignore_meta_files;
   return $r;
};

around 'substitute_version' => sub {
   my ($next, $self, $path, @args) = @_; my $r = $self->$next( $path, @args );

   $self->vcs eq 'git' and $self->_reset_rev_keyword( $path );
   return $r;
};

around 'update_version_pre_hook' => sub {
   my ($next, $self, @args) = @_;

   my @vnums = $self->_get_version_numbers( @args );

# TODO: Add tag after commit of the x.x.1 version
#   $self->_should_add_tag( @vnums ) and $self->_add_tag( $vnums[ 0 ] );
   return $self->$next( @vnums );
};

after 'update_version_post_hook' => sub {
   $_[ 0 ]->vcs eq 'git' and $_[ 0 ]->_reset_rev_file( FALSE ); return;
};

# Public methods
sub add_hooks : method {
   my $self = shift;

   $self->vcs eq 'git' and $self->_add_git_hooks( 'commit-msg', 'pre-commit' );
   return OK;
}

sub add_to_vcs {
   my ($self, $target, $type) = @_;

   $target or throw $self->loc( 'VCS target not specified' );
   $self->vcs eq 'git' and $self->_add_to_git( $target, $type );
   $self->vcs eq 'svn' and $self->_add_to_svn( $target, $type );
   return;
}

sub get_emacs_state_file_path {
   my ($self, $file) = @_; my $home = $self->config->my_home;

   return $home->catfile( qw( .emacs.d config ), "state.${file}" );
}

sub set_branch : method {
   my $self = shift; my $bfile = $self->branch_file;

   my $old_branch = $self->branch;
   my $new_branch = $self->next_argv || $self->default_branch;

   not $new_branch and $bfile->exists and $bfile->unlink and return OK;
       $new_branch and $bfile->println( $new_branch );

   my $method = 'get_'.$self->editor.'_state_file_path';

   $self->can( $method ) or return OK;

   my $sfname = __get_state_file_name( $self->io( $self->project_file ) );
   my $sfpath = $self->$method( $sfname );
   my $sep    = is_win32 ? "\\" : '/';

   $sfpath->substitute( "${sep}\Q${old_branch}\E${sep}",
                        "${sep}${new_branch}${sep}" );
   return OK;
}

# Private methods
sub _add_git_hooks {
   my ($self, @hooks) = @_;

   for my $hook (grep { -e ".git${_}" } @hooks) {
      my $dest = $self->appldir->catfile( qw(.git hooks), $hook );

      $dest->exists and $dest->unlink; link ".git${hook}", $dest;
      chmod $self->exec_perms, ".git${hook}";
   }

   return;
}

sub _add_tag {
   my ($self, $tag) = @_;

   $tag or throw $self->loc( 'VCS tag version not specified' );
   $self->output( 'Creating tagged release v[_1]', { args => [ $tag ] } );
   $self->vcs eq 'git' and $self->_add_tag_to_git( $tag );
   $self->vcs eq 'svn' and $self->_add_tag_to_svn( $tag );
   return;
}

sub _add_tag_to_git {
   my ($self, $tag) = @_;

   my $message = $self->loc( $self->config->tag_message );
   my $sign    = $self->config->signing_key; $sign and $sign = "-u ${sign}";

   $self->run_cmd( "git tag -d v${tag}", { err => 'null', expected_rv => 1 } );
   $self->run_cmd( "git tag ${sign} -m '${message}' v${tag}" );
   return;
}

sub _add_tag_to_svn {
   my ($self, $tag) = @_; my $params = $self->quiet ? {} : { out => 'stdout' };

   my $repo    = $self->_get_svn_repository;
   my $from    = "${repo}/trunk";
   my $to      = "${repo}/tags/v${tag}";
   my $message = $self->loc( $self->config->tag_message )." v${tag}";
   my $cmd     = "svn copy --parents -m '${message}' ${from} ${to}";

   $self->run_cmd( $cmd, $params );
   return;
}

sub _add_to_git {
   my ($self, $target, $type) = @_;

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "git add ${target}", $params );
   return;
}

sub _add_to_svn {
   my ($self, $target, $type) = @_;

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "svn add ${target} --parents", $params );
   $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}",
                   $params );
   $type and $type eq 'program'
      and $self->run_cmd( "svn propset svn:executable '*' ${target}", $params );
   return;
}

sub _get_rev_file {
   my $self = shift; ($self->no_auto_rev or $self->vcs ne 'git') and return;

   return $self->appldir->parent->catfile( lc '.'.$self->distname.'.rev' );
}

sub _get_svn_repository {
   my $self = shift; my $info = $self->run_cmd( 'svn info' )->stdout;

   return (split m{ : \s }mx, (grep { m{ \A Repository \s Root: }mx }
                               split  m{ \n }mx, $info)[ 0 ])[ 1 ];
}

sub _get_version_numbers {
   my ($self, @args) = @_; $args[ 0 ] and $args[ 1 ] and return @args;

   my $prompt = $self->add_leader( $self->loc( 'Enter major/minor 0 or 1'  ) );
   my $comp   = $self->get_line( $prompt, 1, TRUE, 0 );
      $prompt = $self->add_leader( $self->loc( 'Enter increment/decrement' ) );
   my $bump   = $self->get_line( $prompt, 1, TRUE, 0 ) or return @args;
   my ($from, $ver);

   if ($from = $args[ 0 ]) { $ver = Perl::Version->new( $from ) }
   else {
      $ver  = $self->dist_version or return @args;
      $from = __tag_from_version( $ver );
   }

   $ver->component( $comp, $ver->component( $comp ) + $bump );
   $comp == 0 and $ver->component( 1, 0 );

   return ($from, __tag_from_version( $ver ));
}

sub _initialize_git {
   my $self = shift;
   my $msg  = $self->loc( 'Initialized by [_1]', blessed $self );

   $self->chdir( $self->appldir );

   $self->run_cmd( 'git init'   ); $self->add_hooks;

   $self->run_cmd( 'git add .'  ); $self->run_cmd( "git commit -m '${msg}'" );
   return;
}

sub _initialize_svn {
   my $self = shift; my $class = blessed $self; $self->chdir( $self->appbase );

   my $repository = $self->appbase->catdir( $self->repository );

   $self->run_cmd( "svnadmin create ${repository}" );

   my $branch = $self->branch;
   my $url    = 'file://'.$repository->catdir( $branch );
   my $msg    = $self->loc( 'Initialized by [_1]', $class );

   $self->run_cmd( "svn import ${branch} ${url} -m '${msg}'" );

   my $appldir = $self->appldir; $appldir->rmtree;

   $self->run_cmd( "svn co ${url}" );
   $appldir->filter( sub { $_ !~ m{ \.git }msx and $_ !~ m{ \.svn }msx } );

   for my $target ($appldir->deep->all_files) {
      $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}" );
   }

   $msg = $self->loc( 'Add RCS keywords to project files' );
   $self->run_cmd( "svn commit ${branch} -m '${msg}'" );
   $self->chdir( $self->appldir );
   $self->run_cmd( 'svn update' );
   return;
}

sub _initialize_vcs {
   my $self = shift;

   $self->vcs ne 'none' and $self->output( 'Initializing VCS' );
   $self->vcs eq 'git'  and $self->_initialize_git;
   $self->vcs eq 'svn'  and $self->_initialize_svn;
   return;
}

sub _reset_rev_file {
   my ($self, $create) = @_; my $file = $self->_get_rev_file;

   $file and ($create or $file->exists)
         and $file->println( $create ? '1' : '0' );
   return;
}

sub _reset_rev_keyword {
   my ($self, $path) = @_;

   my $zero = 0; # Zero variable prevents unwanted Rev keyword expansion

   $self->_get_rev_file and $path->substitute
      ( '\$ (Rev (?:ision)?) (?:[:] \s+ (\d+) \s+)? \$', '$Rev: '.$zero.' $' );
   return;
}

sub _should_add_tag {
   my ($self, $from, $to) = @_;

   ($self->vcs ne 'none' and $from and $to) or return FALSE;

   my $from_ver = Perl::Version->new( $from );
   my $to_ver   = Perl::Version->new( $to   );

   return $to_ver > $from_ver ? TRUE : FALSE;
}

sub _svn_ignore_meta_files {
   my $self = shift; $self->chdir( $self->appldir );

   my $ignores = "LICENSE\nMANIFEST\nMETA.json\nMETA.yml\nREADME\nREADME.md";

   $self->run_cmd( "svn propset svn:ignore '${ignores}' ." );
   $self->run_cmd( 'svn commit -m "Ignoring meta files" .' );
   $self->run_cmd( 'svn update' );
   return;
}

# Private functions
sub __get_state_file_name {
   return (map  { m{ load-project-state \s+ [\'\"](.+)[\'\"] }mx; }
           grep { m{ eval: \s+ \( \s* load-project-state }mx }
           $_[ 0 ]->getlines)[ -1 ];
}

sub __tag_from_version {
   my $ver = shift; return $ver->component( 0 ).'.'.$ver->component( 1 );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::VCS - Version Control

=head1 Synopsis

   use Module::Provision::TraitFor::VCS;
   # Brief but working code examples

=head1 Version

This documents version v0.29.$Rev: 1 $ of L<Module::Provision::TraitFor::VCS>

=head1 Description

Interface to Version Control Systems

=head1 Configuration and Environment

Modifies
L<Module::Provision::TraitFor::CreatingDistributions/dist_post_hook>
where it initializes the VCS, ignore meta files and resets the
revision number file

Modifies
L<Module::Provision::TraitFor::UpdatingContent/substitute_version>
where it resets the Revision keyword values

Modifies
L<Module::Provision::TraitFor::UpdatingContent/update_version_pre_hook>
where it prompts for version numbers and creates tagged releases

Modifies
L<Module::Provision::TraitFor::UpdatingContent/update_version_post_hook>
where it resets the revision number file

Requires these attributes to be defined in the consuming class;
C<appldir>, C<distname>, C<vcs>

Defines the following attributes;

=over 3

=item C<no_auto_rev>

Do not turn on automatic Revision keyword expansion. Defaults to C<FALSE>

=back

=head1 Subroutines/Methods

=head2 add_hooks - Adds and re-adds any hooks used in the VCS

   $exit_code = $self->add_hooks;

Returns the exit code

=head2 add_to_vcs

   $self->add_to_vcs( $target, $type );

Add the target file to the VCS

=head2 get_emacs_state_file_path

   $io_object = $self->get_emacs_state_file_path( $file_name );

Returns the L<File::DataClass::IO> object for the path to the Emacs editor's
state file

=head2 set_branch - Set the VCS branch name

   $exit_code = $self->set_branch;

Sets the current branch to the value supplied on the command line

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Moose::Role>

=item L<Perl::Version>

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
