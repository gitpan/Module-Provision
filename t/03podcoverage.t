# @(#)Ident: 03podcoverage.t 2013-08-15 23:20 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.29.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING}
      or plan skip_all => 'POD coverage test only for developers';
}

eval "use Test::Pod::Coverage 1.04";

$EVAL_ERROR and plan skip_all => 'Test::Pod::Coverage 1.04 required';

use Test::Builder;

my $Test = Test::Builder->new;

sub _all_pod_coverage_ok {
   my $parms = (@_ && (ref $_[ 0 ] eq 'HASH')) ? shift : {}; my $msg = shift;

   my $ok = 1; my @modules = grep { not m{ \A auto }mx } all_modules();

   if (@modules) {
      $Test->plan( tests => scalar @modules );

      for my $module (@modules) {
         my $thismsg = defined $msg ? $msg : "Pod coverage on ${module}";
         my $thisok  = pod_coverage_ok( $module, $parms, $thismsg );

         $thisok or $ok = 0;
      }
   }
   else { $Test->plan( tests => 1 ); $Test->ok( 1, 'No modules found.' ) }

   return $ok;
}

_all_pod_coverage_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
