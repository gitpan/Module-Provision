# @(#)Ident: VCS.pm 2013-05-11 03:11 pjf ;

package Module::Provision::TraitFor::VCS;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);
use Cwd                    qw(getcwd);
use MooseX::Types::Moose   qw(Bool);
use Perl::Version;

requires qw(appldir distname vcs);

# Public attributes
has 'no_auto_rev' => is => 'ro', isa => Bool, default => FALSE,
   documentation  => 'Do not turn on Revision keyword expansion';

# Construction
around 'dist_post_hook' => sub {
   my ($next, $self, @args) = @_;

   $self->_initialize_vcs;
   $self->$next( @args );
   $self->vcs eq 'svn' and $self->_svn_ignore_meta_files;
   $self->_reset_rev_file( TRUE );
   return;
};

around 'substitute_version' => sub {
   my ($next, $self, $path, $from, $to) = @_;

   $self->$next( $path, $from, $to );
   $self->_reset_rev_keyword( $path );
   return;
};

around 'update_version_pre_hook' => sub {
   my ($next, $self, @args) = @_;

   my @vnums = $self->_get_version_numbers( @args );

   $self->_should_add_tag( @vnums ) and $self->_add_tag( $vnums[ 0 ] );

   return $self->$next( @vnums );
};

after 'update_version_post_hook' => sub {
   my $self = shift; $self->_reset_rev_file( FALSE ); return;
};

# Public methods
sub add_to_vcs {
   my ($self, $target, $type) = @_; $target or throw 'VCS target not specified';

   $self->vcs eq 'git' and $self->_add_to_git( $target, $type );
   $self->vcs eq 'svn' and $self->_add_to_svn( $target, $type );
   return;
}

# Private methods
sub _add_hook {
   my ($self, $hook) = @_; -e ".git${hook}" or return;

   my $path = $self->appldir->catfile( qw(.git hooks), $hook );

   link ".git${hook}", $path; chmod $self->exec_perms, ".git${hook}";
   return;
}

sub _add_tag {
   my ($self, $tag) = @_; $tag or throw 'VCS tag version not specified';

   $self->output( $self->loc( 'Creating tagged release v[_1]', $tag ) );
   $self->vcs eq 'git' and $self->_add_tag_to_git( $tag );
   $self->vcs eq 'svn' and $self->_add_tag_to_svn( $tag );
   return;
}

sub _add_tag_to_git {
   my ($self, $tag) = @_;

   my $message = $self->config->tag_message;
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
   my $message = $self->config->tag_message." v${tag}";
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

   my $prompt = $self->add_leader( 'Enter major/minor 0 or 1' );
   my $comp   = $self->get_line( $prompt, 1, TRUE, 0 );
      $prompt = $self->add_leader( 'Enter increment/decrement' );
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
   my $self = shift; my $class = blessed $self; $self->chdir( $self->appldir );

   $self->run_cmd  ( 'git init'   );
   $self->_add_hook( 'commit-msg' );
   $self->_add_hook( 'pre-commit' );
   $self->run_cmd  ( 'git add .'  );
   $self->run_cmd  ( "git commit -m 'Initialized by ${class}'" );
   return;
}

sub _initialize_svn {
   my $self = shift; my $class = blessed $self; $self->chdir( $self->appbase );

   my $repository = $self->appbase->catdir( $self->repository );

   $self->run_cmd( "svnadmin create ${repository}" );

   my $branch = $self->branch;
   my $url    = 'file://'.$repository->catdir( $branch );

   $self->run_cmd( "svn import ${branch} ${url} -m 'Initialized by ${class}'" );

   my $appldir = $self->appldir; $appldir->rmtree;

   $self->run_cmd( "svn co ${url}" );
   $appldir->filter( sub { $_ !~ m{ \.git }msx and $_ !~ m{ \.svn }msx } );

   for my $target ($appldir->deep->all_files) {
      $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}" );
   }

   my $msg = "Add RCS keywords to project files";

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

   my $ignores = "LICENSE\nMANIFEST\nMETA.json\nMETA.yml\nREADME";

   $self->run_cmd( "svn propset svn:ignore '${ignores}' ." );
   $self->run_cmd( 'svn commit -m "Ignoring meta files" .' );
   $self->run_cmd( 'svn update' );
   return;
}

# Private functions
sub __tag_from_version {
   my $ver = shift; return $ver->component( 0 ).q(.).$ver->component( 1 );
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

This documents version v0.15.$Rev: 2 $ of L<Module::Provision::TraitFor::VCS>

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

=head2 add_to_vcs

   $self->add_to_vcs( $target, $type );

Add the target file to the VCS

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Moose::Role>

=item L<MooseX::Types>

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
