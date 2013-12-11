# @(#)Ident: 10test_script.t 2013-09-12 11:04 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.27.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
   $builder and $notes = $builder->notes;
   $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use Test::Requires { Moo => 1.003001 };
use Cwd qw( getcwd );
use File::DataClass::IO;

use_ok 'Module::Provision';

my $owd = getcwd; my $prog;

sub test_mp {
   my ($builder, $method) = @_; $method ||= 'dist';

   return Module::Provision->new_with_options
      ( appclass  => 'Module::Provision',
        base      => 't',
        builder   => $builder,
        config    => { tempdir => 't', },
        method    => $method,
        nodebug   => 1,
        quiet     => 1,
        project   => 'Foo::Bar',
        templates => catdir( 't', 'code_templates' ),
        vcs       => 'none', );
}

sub test_cleanup {
   my $owd = shift; chdir $owd;

   io( catdir( qw( t Foo-Bar )        ) )->rmtree();
   io( catdir( qw( t code_templates ) ) )->rmtree();
   return;
}

$prog = test_mp( 'MB', 'init_templates' ); $prog->run;

ok -f catfile( qw( t code_templates index.json ) ), 'Creates template index';

$prog->dist_pre_hook;

like $prog->appbase->name, qr{ Foo-Bar \z }mx, 'Sets appbase';

$prog->create_directories;

ok -d catdir( qw( lib Foo ) ), 'Creates lib/Foo dir';
ok -d 'inc', 'Creates inc dir';
ok -d 't', 'Creates t dir';

$prog->render_templates;

ok -f catfile( qw( lib Foo Bar.pm ) ), 'Creates lib/Foo/Bar.pm';
ok -f 'Build.PL', 'Creates Build.PL';

test_cleanup( $owd );

SKIP: {
   $ENV{AUTHOR_TESTING} or skip 'extended testing', 1;

   $prog = test_mp( 'DZ' );

   is $prog->run, 0, 'Dist DZ returns zero';

   test_cleanup( $owd );

   $prog = test_mp( 'MB' );

   is $prog->run, 0, 'Dist MB returns zero';

   test_cleanup( $owd );

   $prog = test_mp( 'MI' );

   is $prog->run, 0, 'Dist MI returns zero';

   test_cleanup( $owd );
}

done_testing;

unlink catfile( qw( t .foo-bar.rev ) );
unlink catfile( qw( t ipc_srlock.lck ) );
unlink catfile( qw( t ipc_srlock.shm ) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
