package Module::Provision::Config;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( fullname loginid logname untaint_cmdline
                                untaint_identifier );
use File::DataClass::Types  qw( ArrayRef HashRef NonEmptySimpleStr
                                Path SimpleStr );

extends qw(Class::Usul::Config::Programs);

# Object attributes (public)
has 'author'           => is => 'lazy', isa => NonEmptySimpleStr;

has 'author_email'     => is => 'lazy', isa => NonEmptySimpleStr;

has 'author_id'        => is => 'lazy', isa => NonEmptySimpleStr,
   default             => sub { loginid };

has 'base'             => is => 'lazy', isa => Path, coerce => Path->coercion,
   default             => sub { $_[ 0 ]->my_home };

has 'builder'          => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'MB';

has 'default_branches' => is => 'lazy', isa => HashRef,
   default             => sub { { git => 'master', svn => 'trunk' } };

has 'delete_files_uri' => is => 'lazy', isa => NonEmptySimpleStr;

has 'editor'           => is => 'lazy', isa => NonEmptySimpleStr,
   default             => sub { untaint_identifier $ENV{EDITOR} || 'emacs' };

has 'home_page'        => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'http://example.com';

has 'hooks'            => is => 'lazy', isa => ArrayRef[NonEmptySimpleStr],
   default             => sub { [ 'commit-msg', 'pre-commit' ] };

has 'license'          => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'perl';

has 'min_perl_ver'     => is => 'lazy', isa => NonEmptySimpleStr,
   default             => '5.01';

has 'module_abstract'  => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'One-line description of the modules purpose';

has 'repository'       => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'repository';

has 'seed_file'        => is => 'lazy', isa => Path, coerce => Path->coercion,
   default             => sub { [ qw( ~ .ssh pause.key ) ] };

has 'signing_key'      => is => 'lazy', isa => SimpleStr,
   default             => NUL;

has 'tag_message'      => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'Released';

has 'template_index'   => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'index.json';

has 'test_env_vars'    => is => 'lazy', isa => ArrayRef,
   documentation       => 'Set these environment vars to true when testing',
   default             => sub {
      [ qw( AUTHOR_TESTING TEST_MEMORY TEST_SPELLING ) ] };

has 'vcs'              => is => 'lazy', isa => NonEmptySimpleStr,
   default             => 'git';

# Private methods
sub _build_author {
   my $author = untaint_cmdline( $ENV{AUTHOR} || fullname || logname );

   $author =~ s{ [\'] }{\'}gmx; return $author;
}

sub _build_author_email {
   my $email = untaint_cmdline( $ENV{EMAIL} || 'dave@example.com' );

   $email =~ s{ [\'] }{\'}gmx; return $email;
}

sub _build_delete_files_uri {
   return untaint_cmdline $ENV{CPAN_DELETE_FILES_URI}
       || 'https://pause.perl.org/pause/authenquery';
}

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

=head1 Description

Defines attributes which can be set from the config file

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<author>

=item C<author_email>

=item C<author_id>

=item C<base>

=item C<builder>

=item C<editor>

=item C<home_page>

=item C<hooks>

=item C<license>

=item C<module_abstract>

=item C<repository>

=item C<template_index>

=item C<test_env_vars>

Array reference. Set these environment vars to true when testing. Defaults
to; C<AUTHOR_TESTING TEST_MEMORY>, and C<TEST_SPELLING>

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
