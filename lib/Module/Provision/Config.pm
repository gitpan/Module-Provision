# @(#)Ident: Config.pm 2013-05-08 02:48 pjf ;

package Module::Provision::Config;

use version; our $VERSION = qv( sprintf '0.12.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Class::Null;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(untaint_cmdline untaint_identifier);
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(Path);
use User::pwent;

extends qw(Class::Usul::Config::Programs);

my $osname = lc $OSNAME;

# Object attributes (public)
has 'author'          => is => 'lazy', isa => NonEmptySimpleStr;

has 'author_email'    => is => 'lazy', isa => NonEmptySimpleStr;

has 'author_id'       => is => 'lazy', isa => NonEmptySimpleStr;

has 'base'            => is => 'lazy', isa => Path, coerce => TRUE,
   default            => sub { $_[ 0 ]->my_home };

has 'builder'         => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'MB';

has 'editor'          => is => 'lazy', isa => NonEmptySimpleStr,
   default            => sub { untaint_identifier $ENV{EDITOR} || 'emacs' };

has 'home_page'       => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'http://example.com';

has 'license'         => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'perl';

has 'module_abstract' => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'One-line description of the modules purpose';

has 'repository'      => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'repository';

has 'template_index'  => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'index.json';

has 'vcs'             => is => 'lazy', isa => NonEmptySimpleStr,
   default            => 'git';

# Private methods
sub _build_author {
   my $author = untaint_cmdline( $ENV{AUTHOR} || __fullname() || __logname() );

   $author =~ s{ [\'] }{\'}gmx; return $author;
}

sub _build_author_email {
   my $email = untaint_cmdline( $ENV{EMAIL} || 'dave@example.com' );

   $email =~ s{ [\'] }{\'}gmx; return $email;
}

sub _build_author_id {
   return untaint_cmdline( __loginid() );
}

# Private functions
sub __fullname {
   return (split m{ \s* , \s * }msx, (__get_user()->gecos || q()))[ 0 ];
}

sub __get_user {
   return $osname eq EVIL ? Class::Null->new : getpwuid( $UID );
}

sub __loginid {
   return __get_user()->name || 'unknown';
}

sub __logname {
   return $ENV{USER} || $ENV{LOGNAME} || __loginid;
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

This documents version v0.12.$Rev: 2 $ of L<Module::Provision::Config>

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

=item C<editor>

=item C<home_page>

=item C<license>

=item C<module_abstract>

=item C<repository>

=item C<template_index>

=item C<vcs>

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Null>

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