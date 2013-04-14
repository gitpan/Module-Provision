#!/usr/bin/env perl
# @(#)Ident: perl_program.pl 2013-04-09 17:04 pjf ;

use strict;
use warnings;

use English qw( -no_match_vars );
use FindBin qw( $Bin );
use File::Spec;

BEGIN {
   my $path = File::Spec->catfile( $Bin, '[% prefix %]-localenv' );

   do $path or die $EVAL_ERROR || "Path ${path} not done\n";
}

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );

use [% project %];

exit [% project %]->new_with_options( appclass => '[% project %]' )->run;

__END__

=pod

=head1 NAME

[% program_name %] - I<One line abstract describing the programs purpose>

=head1 SYNOPSIS

=over 3

=item B<[% program_name %]> B<> I<>

I<Command line description>

=item B<[% program_name %]> B<-H> | B<-h> I<[method]> | B<-?>

Display man page / method help  / usage strings

=item B<[% program_name %]> B<list_methods>

Lists the methods available in this program

=back

=head1 VERSION

This documents version v0.1.$Rev: 1 $ of L<[% project %]>

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

Send reports to address below

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
