# @(#)Ident: Config.pm 2013-05-04 00:12 pjf ;

package Module::Provision::Config;

use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(Path);
use User::pwent;

extends qw(Class::Usul::Config::Programs);

# Object attributes (public)
has 'author'          => is => 'lazy', isa => NonEmptySimpleStr;

has 'author_email'    => is => 'lazy', isa => NonEmptySimpleStr;

has 'author_id'       => is => 'lazy', isa => SimpleStr,
   default            => q();

has 'base'            => is => 'lazy', isa => Path, coerce => TRUE,
   default            => sub { $_[ 0 ]->config->my_home };

has 'branch'          => is => 'lazy', isa => NonEmptySimpleStr,
   default            => sub { $_[ 0 ]->vcs eq 'svn' ? 'trunk' : 'master' };

has 'builder'         => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'MB';

has 'home_page'       => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'http://example.com';

has 'license'         => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'perl';

has 'module_abstract' => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'One-line description of the modules purpose';

has 'repository'      => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'repository';

has 'vcs'             => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'git';

# Private methods
sub _build_author {
   my $self     = shift;
   my $user     = getpwuid( $UID );
   my $fullname = (split m{ \s* , \s * }msx, $user->gecos)[ 0 ];
   my $author   = $ENV{AUTHOR} || $fullname || $self->logname;

   $author =~ s{ [\'] }{\'}gmx;
   return $author;
}

sub _build_author_email {
   my $email = $ENV{EMAIL} || 'dave@example.com'; $email =~ s{ [\'] }{\'}gmx;

   return $email;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::Config - Attributes set from the config file

=head1 Synopsis

   use Moose;

   extends 'Class::Usul::Programs';

   has '+config_class' => default => sub { 'Module::Provision::Config' };

=head1 Version

This documents version v0.10.$Rev: 3 $ of L<Module::Provision::Config>

=head1 Description

Defines attributes which can be set from the config file

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<author>

=item C<author_email>

=item C<author_id>

=item C<base>

=item C<branch>

=item C<builder>

=item C<home_page>

=item C<license>

=item C<module_abstract>

=item C<repository>

=item C<vcs>

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<File::DataClass>

=item L<User::pwent>

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
