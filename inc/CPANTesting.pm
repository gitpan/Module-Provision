# @(#)Ident: CPANTesting.pm 2013-05-05 11:17 pjf ;
# Bob-Version: 1.12

package CPANTesting;

use strict;
use warnings;

use Sys::Hostname; my $host = lc hostname; my $osname = lc $^O;

# Is this an attempted install on a CPAN testing platform?
sub is_testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                 || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

sub should_abort {
   is_testing() or return 0;

   $host eq q(xphvmfred) and return
      "Stopped Stauner ${host} - 0a7335a2-af67-11e2-99d1-ca991c44ed51";
   return 0;
}

sub test_exceptions {
   my $p = shift; is_testing() or return 0;

   $p->{stop_tests}     and return 'CPAN Testing stopped in Build.PL';
   $osname eq q(mirbsd) and return 'Mirbsd  OS unsupported';
   return 0;
}

1;

__END__
