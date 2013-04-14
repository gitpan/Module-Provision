# @(#)Ident: 04critic.t 2013-04-12 18:56 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   not (-e catfile( $Bin, updir, 'MANIFEST.SKIP' )
     or -e catfile( $Bin, updir, updir, updir, 'MANIFEST.SKIP'))
      and plan skip_all => 'Critic test only for developers';
}

eval "use Test::Perl::Critic -profile => catfile( q(t), q(critic.rc) )";

$EVAL_ERROR and plan skip_all => 'Test::Perl::Critic not installed';

$ENV{TEST_CRITIC}
   or plan skip_all => 'Environment variable TEST_CRITIC not set';

all_critic_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
