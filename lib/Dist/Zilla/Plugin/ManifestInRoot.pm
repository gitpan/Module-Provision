# @(#)Ident: ManifestInRoot.pm 2013-04-24 20:24 pjf ;

package Dist::Zilla::Plugin::ManifestInRoot;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose;
use Moose::Autobox;
use File::Slurp ();

with 'Dist::Zilla::Role::InstallTool';

sub setup_installer {
   my $self    = shift;
   my $zilla   = $self->zilla;
   my $content = $zilla->files->map( sub { $_->name } )->sort
                       ->map( sub { __fix_filename( $_ ) } )->join( "\n" )."\n";
   my $file    = $zilla->root->file( 'MANIFEST' );

   File::Slurp::write_file( "$file", { binmode => ':raw' }, $content );
   return;
}

# Private functions

sub __fix_filename {
   my $name = shift; $name =~ m{ [ \'\\] }mx or return $name;

   $name =~ s{ \\ }{\\\\}gmx; $name =~ s{ ' }{\\'}gmx;

   return qq{'$name'};
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

Dist::Zilla::Plugin::ManifestInRoot - Puts the MANIFEST file in the project root

=head1 Synopsis

   # In your dist.ini
   [ManifestInRoot]

=head1 Version

This documents version v0.7.$Rev: 2 $ of L<Dist::Zilla::Plugin::ManifestInRoot>

=head1 Description

Puts the F<MANIFEST> file in the project root so that it can be used by
other programs, e.g. C<module_provision update_version 0.1 0.2>

=head1 Configuration and Environment

None

=head1 Subroutines/Methods

=head2 setup_installer

The code had to go somewhere

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Dist::Zilla::Role::InstallTool>

=item L<File::Slurp>

=item L<Moose>

=item L<Moose::Autobox>

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
