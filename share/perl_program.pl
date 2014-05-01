#!/usr/bin/env perl

use strict;
use warnings;

use English               qw( -no_match_vars );
use File::Spec::Functions qw( catdir catfile updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

BEGIN {
   my $path = catfile( $Bin, '[% prefix %]-localenv' );

   -f $path and (do $path or die $EVAL_ERROR || "Path ${path} not done\n");
}

use [% module %];

exit [% module %]->new_with_options( noask => 1 )->run;

__END__

=pod

=encoding utf8

=head1 NAME

[% program_name %] - [% abstract %]

=head1 SYNOPSIS

=over 3

=item B<[% program_name %]> B<> I<>

I<Command line description>

=item B<[% program_name %]> B<-H> | B<-h> I<[method]> | B<-?>

Display man page / method help  / usage strings

=item B<[% program_name %]> B<list_methods>

Lists the methods available in this program

=back

=head1 DESCRIPTION

I<Program description>

=head1 REQUIRED ARGUMENTS

=over 3

=item I<>

=back

=head1 OPTIONS

=over 3

=item B<-D>

Turn debugging on

=back

=head1 DIAGNOSTICS

Prints errors to stderr

=head1 EXIT STATUS

Returns zero on success, non zero on failure

=head1 CONFIGURATION

Uses the constructor's C<appclass> attribute to locate a configuration file

=head1 DEPENDENCIES

=over 3

=item L<Class::Usul>

=back

=head1 INCOMPATIBILITIES

None

=head1 BUGS AND LIMITATIONS

Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=[% distname %]

=head1 AUTHOR

[% author %], C<< <[% author_email %]> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) [% copyright_year %] [% copyright %]

This is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
