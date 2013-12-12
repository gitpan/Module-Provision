# @(#)Ident: UpdatingContent.pm 2013-07-11 14:57 pjf ;

package Module::Provision::TraitFor::UpdatingContent;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.28.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use Moo::Role;

requires qw( appldir loc manifest_paths next_argv output );

# Public methods
sub substitute_version {
   my ($self, $path, $from, $to) = @_;

   $path->substitute( "\Q\'${from}.%d\',\E", "\'${to}.%d\'," );
   $path->substitute( "\Q v${from}.\$Rev\E", " v${to}.\$Rev" );
   return;
}

sub update_copyright_year : method {
   my $self = shift; my ($from, $to) = $self->_get_update_args;

   my $prefix = $self->loc( 'Copyright (c)' );

   $self->output( 'Updating copyright year' );

   for my $path (@{ $self->manifest_paths }) {
      $path->substitute( "\Q${prefix} ${from}\E", "${prefix} ${to}" );
   }

   return OK;
}

sub update_version : method {
   my $self = shift; my ($from, $to) = $self->_get_update_args;

   my $ignore = $self->_get_ignore_rev_regex;

   $self->output( 'Updating version numbers' );

   ($from, $to) = $self->update_version_pre_hook( $from, $to );

   for my $path (@{ $self->manifest_paths }) {
      $ignore and $path =~ m{ (?: $ignore ) }mx and next;
      $self->substitute_version( $path, $from, $to );
   }

   $self->update_version_post_hook;
   return OK;
}

sub update_version_post_hook { # Can be modified by applied traits
}

sub update_version_pre_hook { # Can be modified by applied traits
   my ($self, @args) = @_;

   ($args[ 0 ] and $args[ 1 ]) or throw $self->loc( 'Insufficient arguments' );

   return @args;
}

# Private methods
sub _get_ignore_rev_regex {
   my $self = shift;

   my $ignore_rev = $self->appldir->catfile( '.gitignore-rev' )->chomp;

   return $ignore_rev->exists ? join '|', $ignore_rev->getlines : undef;
}

sub _get_update_args {
   return ($_[ 0 ]->next_argv, $_[ 0 ]->next_argv);
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::UpdatingContent - Perform search and replace on project file content

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::UpdatingContent';

=head1 Version

This documents version v0.28.$Rev: 1 $ of
L<Module::Provision::TraitFor::UpdatingContent>

=head1 Description

Perform search and replace on project file content

=head1 Configuration and Environment

Requires the following attributes to be defined in the consuming
class; C<appldir>

Defines no attributes

=head1 Subroutines/Methods

=head2 substitute_version

   $self->substitute_version( $path, $from, $to );

Substitutes the C<$to> string everywhere the C<$from> pattern occurs
in the C<$path> file. The C<$path> argument should be of type
L<File::DataClass::IO>

=head2 update_copyright_year - Updates the copyright year in the POD

   $exit_code = $self->update_copyright_year;

Substitutes the existing copyright year for the new copyright year in all
files in the F<MANIFEST>

=head2 update_version - Updates the version numbers in all files

   $exit_code = $self->update_version;

Substitutes the existing version number for the new version number in all
files in the F<MANIFEST>

=head2 update_version_pre_hook

   $self->update_version_pre_hook;

Returns it's input args by default. Can be modified by applied traits

=head2 update_version_post_hook

   $self->update_version_post_hook;

Does nothing by default. Can be modified by applied traits

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
