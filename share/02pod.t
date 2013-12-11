# @(#)Ident: 02pod.t 2013-12-06 14:37 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING} or plan skip_all => 'POD test only for developers';
}

use English qw( -no_match_vars );

eval "use Test::Pod 1.14";

$EVAL_ERROR and plan skip_all => 'Test::Pod 1.14 required';

all_pod_files_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
