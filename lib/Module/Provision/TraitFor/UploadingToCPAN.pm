# @(#)Ident: UploadingToCPAN.pm 2013-05-11 13:53 pjf ;

package Module::Provision::TraitFor::UploadingToCPAN;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.14.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);

# Public methods
sub cpan_upload : method {
   my $self = shift; my $args = $self->_read_pauserc;

   my $file = shift @{ $self->extra_argv }
           || $self->distname.'-v'.$self->dist_version.'.tar.gz';

   $self->ensure_class_loaded( q(CPAN::Uploader) );

   $args->{subdir} = lc $self->distname;
   exists $args->{dry_run} or $args->{dry_run}
      = not $self->yorn( 'Really upload to CPAN', FALSE, TRUE, 0 );
   CPAN::Uploader->upload_file( $file, $args );
   return OK;
}

# Private methods
sub _read_pauserc {
   my $self = shift; my $dir = $self->config->my_home; my $args = {};

   for ($self->io( [ $dir, q(.pause) ] )->chomp->getlines) {
      ($_ and $_ !~ m{ \A \s* \# }mx) or next;
      my ($k, $v) = m{ \A \s* (\w+) \s+ (.+) \z }mx;
      exists $args->{ $k } and throw "Multiple enties for ${k}";
      $args->{ $k } = $v;
   }

   return $args;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::UploadingToCPAN - Uploads distributions to CPAN

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::UploadingToCPAN';

=head1 Version

This documents version v0.14.$Rev: 2 $ of
L<Module::Provision::TraitFor::UploadingToCPAN>

=head1 Description

Uploads distributions to CPAN

=head1 Configuration and Environment

Reads PAUSE account data from F<~/.pauserc>

Defines no attributes

=head1 Subroutines/Methods

=head2 cpan_upload

   $exit_code = $self->cpan_upload;

Uploads a distribution to CPAN

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<CPAN::Uploader>

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
