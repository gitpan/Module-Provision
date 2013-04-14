# @(#)Ident: 10test_script.t 2013-04-12 18:50 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 43 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Cwd qw(getcwd);
use File::DataClass::IO;
use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use_ok 'Module::Provision';

my $owd = getcwd; my $prog;

sub test_mp {
   my $builder = shift;

   return Module::Provision->new_with_options
      ( appclass  => 'Module::Provision',
        base      => 't',
        builder   => $builder,
        method    => 'dist',
        nodebug   => 1,
        novcs     => 1,
        project   => 'Foo::Bar',
        templates => catdir( 't', 'code_templates' ) );
}

sub test_cleanup {
   my $owd = shift; chdir $owd;

   io( catdir( qw(t Foo-Bar)        ) )->rmtree();
   io( catdir( qw(t code_templates) ) )->rmtree();
   return;
}

$prog = test_mp( 'DZ' );

is $prog->run, 0, 'Dist DZ returns zero';

test_cleanup( $owd );

$prog = test_mp( 'MB' );

is $prog->run, 0, 'Dist MB returns zero';

test_cleanup( $owd );

$prog = test_mp( 'MI' );

is $prog->run, 0, 'Dist MI returns zero';

test_cleanup( $owd );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
