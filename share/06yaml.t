# @(#)Ident: 06yaml.t 2013-04-12 18:57 pjf ;

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
      and plan skip_all => 'YAML test only for developers';
}

eval { require Test::YAML::Meta; };

$EVAL_ERROR and plan skip_all => 'Test::YAML::Meta not installed';

Test::YAML::Meta->import();

meta_yaml_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
