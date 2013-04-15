# @(#)Ident: Provision.pm 2013-04-14 19:05 pjf ;

package Module::Provision;

use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 44 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(class2appdir classdir classfile distname
                                    home2appldir is_arrayref prefix2class
                                    throw trim);
use Class::Usul::Time            qw(time2str);
use Cwd                          qw(getcwd);
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(Directory OctalNum Path);
use File::Spec::Functions        qw(catdir);
use File::ShareDir                 ();
use Template;
use User::pwent;

extends q(Class::Usul::Programs);

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( Path, '=s' );

enum 'Module::Provision::Builder' => qw(DZ MB MI);

# Public attributes

has 'base'        => is => 'lazy', isa => Path, coerce => TRUE,
   documentation  => 'The directory which will contain the new project',
   default        => sub { $_[ 0 ]->config->my_home };

has 'branch'      => is => 'lazy', isa => NonEmptySimpleStr,
   documentation  => 'The name of the initial branch to create',
   default        => sub { $_[ 0 ]->vcs eq 'git' ? 'master' : 'trunk' };

has 'builder'     => is => 'ro',   isa => 'Module::Provision::Builder',
   documentation  => 'Which of the three build systems to use',
   default        => 'MB';

has 'force'       => is => 'ro',   isa => Bool, default => FALSE,
   documentation  => 'Overwrite the output file if it already exists',
   traits         => [ 'Getopt' ], cmd_aliases => q(f), cmd_flag => 'force';

has 'license'     => is => 'ro',   isa => NonEmptySimpleStr, default => 'perl',
   documentation  => 'License used for the project';

has 'novcs'       => is => 'ro',   isa => Bool, default => FALSE,
   documentation  => 'Do not create or use a VCS';

has 'perms'       => is => 'ro',   isa => OctalNum, coerce => TRUE,
   documentation  => 'Default permission for file / directory creation',
   default        => '640';

has 'project'     => is => 'lazy', isa => NonEmptySimpleStr,
   documentation  => 'The class name of the new project';

has 'repository'  => is => 'ro',   isa => NonEmptySimpleStr,
   documentation  => 'Name of the directory containing the SVN repository',
   default        => 'repository';

has 'templates'   => is => 'ro',   isa => SimpleStr, default => NUL,
   documentation  => 'Non default location of the code templates';

has 'vcs'         => is => 'ro',   isa => NonEmptySimpleStr,
   documentation  => 'The version control system to use',
   default        => 'git';

# Private attributes

has '_appbase'       => is => 'lazy', isa => NonEmptySimpleStr,
   default           => sub { distname $_[ 0 ]->project };

has '_appldir'       => is => 'lazy', isa => Path, coerce => TRUE;

has '_author'        => is => 'lazy', isa => NonEmptySimpleStr;

has '_author_email'  => is => 'lazy', isa => NonEmptySimpleStr;

has '_author_id'     => is => 'lazy', isa => NonEmptySimpleStr;

has '_binsdir'       => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 'bin' ] };

has '_dist_module'   => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_homedir.'.pm' ] };

has '_home'          => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { $_[ 0 ]->config->my_home };

has '_homedir'       => is => 'lazy', isa => Path, coerce => TRUE;

has '_home_page'     => is => 'lazy', isa => NonEmptySimpleStr;

has '_incdir'        => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 'inc' ] };

has '_initial_wd'    => is => 'ro',   isa => Directory, coerce => TRUE,
   default           => sub { [ getcwd ] };

has '_libdir'        => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 'lib' ] };

has '_license_keys'  => is => 'ro',   isa => HashRef,
   builder           => '_build_license_keys';

has '_project_file'  => is => 'lazy', isa => NonEmptySimpleStr;

has '_stash'         => is => 'lazy', isa => HashRef, reader => 'stash';

has '_template_list' => is => 'lazy', isa => ArrayRef,
   reader            => 'template_list';

has '_template_dir'  => is => 'lazy', isa => Directory, coerce => TRUE,
   reader            => 'template_dir';

has '_testdir'       => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 't' ] };

sub create_directories {
   my ($self, $args) = @_; my $perms = $self->_exec_perms;

   $self->_appldir->exists or $self->_appldir->mkpath( $perms );
   $self->builder eq 'MB' and ($self->_incdir->exists
                               or $self->_incdir->mkpath( $perms ));
   $self->_testdir->exists or $self->_testdir->mkpath( $perms );
   $self->_homedir->parent->exists or $self->_homedir->parent->mkpath( $perms );
   return;
}

sub dist : method {
   my $self = shift; my $args = $self->pre_hook( {} );

   $self->create_directories( $args );
   $self->render_templates( $args );
   $self->post_hook( $args );
   return OK;
}

sub init_templates : method {
   my $self = shift; $self->template_list; return OK;
}

sub module : method {
   my $self   = shift;
   my $module = $self->extra_argv->[ 0 ];
   my $target = $self->_get_target( '_libdir', \&classfile );

   $self->stash->{module} = $module;
   $target = $self->_render_template( 'perl_module.pm', $target );
   $self->_add_to_vcs( { target => $target, type => 'module' } );
   return OK;
}

sub post_hook {
   my ($self, $args) = @_;

   $self->_initialize_vcs( $args );
   $self->_initialize_distribution( $args );
   $self->_test_distribution( $args );
   return;
}

sub pre_hook {
   my ($self, $args) = @_; $args ||= {}; umask $self->_create_mask;

   my $base    = $self->base->absolute( $self->_initial_wd );
   my $appbase = $args->{appbase} = $base->catdir( $self->_appbase );

   $appbase->exists or $appbase->mkpath( $self->_exec_perms );

   __chdir( $appbase ); $args->{templates} = $self->template_list;

   return $args;
}

sub program : method {
   my $self    = shift;
   my $program = $self->extra_argv->[ 0 ];
   my $target  = $self->_get_target( '_binsdir' );

   $self->stash->{program_name} = $program;
   $target = $self->_render_template( 'perl_program.pl', $target );
   chmod $self->_exec_perms, $target->pathname;
   $self->_add_to_vcs( { target => $target, type => 'program' } );
   return OK;
}

sub render_templates {
   my ($self, $args) = @_; my $templates = $args->{templates};

   for my $tuple (@{ $templates }) {
      for (my $i = 0, my $max = @{ $tuple }; $i < $max; $i++) {
         if (is_arrayref $tuple->[ $i ]) {
            my $method = $tuple->[ $i ]->[ 0 ];

            '_' eq substr $method, 0, 1
               and $tuple->[ $i ]->[ 0 ] = $self->$method();
            $tuple->[ $i ] = $self->io( $tuple->[ $i ] );
         }
         else {
            my $method = $tuple->[ $i ];

            '_' eq substr $method, 0, 1 and $tuple->[ $i ] = $self->$method();
         }
      }

      $self->_render_template( @{ $tuple } );
   }

   return;
}

sub test : method {
   my $self = shift; my $target = $self->_get_target( '_testdir' );

   $target = $self->_render_template( 'test_script.t', $target );
   $self->_add_to_vcs( { target => $target, type => 'test' } );
   return OK;
}

# Private methods

sub _add_hook {
   my ($self, $hook) = @_; -e ".git${hook}" or return;

   my $path = $self->_appldir->catfile( qw(.git hooks), $hook );

   link ".git${hook}", $path; chmod $self->_exec_perms, ".git${hook}";
   return;
}

sub _add_to_git {
   my ($self, $args) = @_; my $target = $args->{target};

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "git add ${target}", $params );

   return TRUE;
}

sub _add_to_svn {
   my ($self, $args) = @_; my $target = $args->{target};

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "svn add ${target} --parents", $params );
   $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}",
                   $params );
   $args->{type} and $args->{type} eq 'program'
      and $self->run_cmd( "svn propset svn:executable '*' ${target}", $params );
   return;
}

sub _add_to_vcs {
   my ($self, $args) = @_; $args ||= {};

   $args->{target} or throw 'VCS target not specified';

   $self->novcs and return;
   $self->vcs eq 'git' and $self->_add_to_git( $args );
   $self->vcs eq 'svn' and $self->_add_to_svn( $args );
   return;
}

sub _build__appldir {
   my $self = shift; my $base = $self->base->absolute( $self->_initial_wd );

   return $self->vcs eq 'git' ? [ $base, $self->_appbase ]
                              : [ $base, $self->_appbase, $self->branch ];
}

sub _build__author {
   my $path      = $_[ 0 ]->template_dir->catfile( 'author' );
   my $from_file = $path->exists ? trim $path->getline : FALSE;

   if ($from_file) { $from_file =~ s{ [\'] }{\'}gmx; return $from_file }

   my $user      = getpwuid( $UID );
   my $fullname  = (split m{ \s* , \s * }msx, $user->gecos)[ 0 ];
   my $author    = $ENV{AUTHOR} || $fullname || $user->name;

   $path->print( $author ); $author =~ s{ [\'] }{\'}gmx;
   return $author;
}

sub _build__author_email {
   my $path      = $_[ 0 ]->template_dir->catfile( 'author_email' );
   my $from_file = $path->exists ? trim $path->getline : FALSE;

   if ($from_file) { $from_file =~ s{ [\'] }{\'}gmx; return $from_file }

   my $email = $ENV{EMAIL} || 'dave@example.com';

   $path->print( $email ); $email =~ s{ [\'] }{\'}gmx;
   return $email;
}

sub _build__author_id {
   my $path      = $_[ 0 ]->template_dir->catfile( 'author_id' );
   my $from_file = $path->exists ? trim $path->getline : FALSE;

   $from_file and return $from_file;

   my $author_id = $ENV{USER} || getpwuid( $UID )->name;

   $path->print( $author_id );
   return $author_id;
}

sub _build__home_page {
   my $path = $_[ 0 ]->template_dir->catfile( 'home_page' );

   return $path->exists ? trim $path->getline : 'http://example.com';
}

sub _build__homedir {
   return [ $_[ 0 ]->_libdir, classdir $_[ 0 ]->project ];
}

sub _build_license_keys {
   return {
      perl       => 'Perl_5',
      perl_5     => 'Perl_5',
      apache     => [ map { "Apache_$_" } qw(1_1 2_0) ],
      artistic   => 'Artistic_1_0',
      artistic_2 => 'Artistic_2_0',
      lgpl       => [ map { "LGPL_$_" } qw(2_1 3_0) ],
      bsd        => 'BSD',
      gpl        => [ map { "GPL_$_" } qw(1 2 3) ],
      mit        => 'MIT',
      mozilla    => [ map { "Mozilla_$_" } qw(1_0 1_1) ], };
}

sub _build_project {
   my $project = $_[ 0 ]->extra_argv->[ 0 ]
      or throw 'Project class not specified';

   return $project;
}

sub _build__project_file {
   return $_[ 0 ]->builder eq 'MB' ? 'Build.PL' : 'Makefile.PL';
}

sub _build__stash {
   my $self = shift; my $project = $self->project; my $author = $self->_author;

   return { appbase        => $self->_appbase,
            appdir         => class2appdir $self->_appbase,
            author         => $author,
            author_email   => $self->_author_email,
            author_id      => $self->_author_id,
            copyright      => $ENV{ORGANIZATION} || $author,
            copyright_year => time2str( '%Y' ),
            creation_date  => time2str,
            dist_module    => $self->_dist_module->abs2rel( $self->_appldir ),
            distname       => distname $project,
            first_name     => lc ((split SPC, $author)[ 0 ]),
            home_page      => $self->_home_page,
            last_name      => lc ((split SPC, $author)[ -1 ]),
            license        => $self->license,
            license_class  => $self->_license_keys->{ $self->license },
            module         => $project,
            perl           => $],
            prefix         => (split m{ :: }mx, lc $project)[ -1 ],
            project        => $project, };
}

sub _build__template_dir {
   my $self = shift;
   my $dir  = $self->templates
            ? $self->io( [ $self->templates ] )->absolute( $self->_initial_wd )
            : $self->io( [ $self->_home, '.code_templates' ] );

   $dir->exists and return $dir; $dir->mkpath( $self->_exec_perms );

   my $dist = $self->io( File::ShareDir::dist_dir( distname __PACKAGE__ ) );

   $_->copy( $dir ) for ($dist->all_files);

   return $dir;
}

sub _build__template_list {
   my $self = shift; my $index = $self->template_dir->catfile( 'index.json' );

   my $data; $index->exists and $data = $self->file->data_load
      ( paths => [ $index ], storage_class => 'Any' )
      and return $self->_merge_lists( $data );

   my $builders  = {
      DZ => [ [ 'dist.ini',           '_appldir' ], ],
      MB => [ [ 'Build.PL',           '_appldir' ],
              [ 'Bob.pm',             '_incdir'  ],
              [ 'CPANTesting.pm',     '_incdir'  ],
              [ 'SubClass.pm',        '_incdir'  ], ],
      MI => [ [ 'MI_Makefile.PL',   [ '_appldir', 'Makefile.PL' ], ], ], };
   my $templates = [ [ 'Changes',         '_appldir'     ],
                     [ 'MANIFEST.SKIP',   '_appldir'     ],
                     [ 'perl_module.pm',  '_dist_module' ],
                     [ '01always_pass.t', '_testdir'     ],
                     [ '02pod.t',         '_testdir'     ],
                     [ '03podcoverage.t', '_testdir'     ],
                     [ '04critic.t',      '_testdir'     ],
                     [ '05kwalitee.t',    '_testdir'     ],
                     [ '06yaml.t',        '_testdir'     ],
                     [ '07podspelling.t', '_testdir'     ],
                     [ '10test_script.t', '_testdir'     ], ];
   my $vcs = {
      git => [ [ 'gitcommit-msg', [ '_appldir', '.gitcommit-msg' ] ],
               [ 'gitignore',     [ '_appldir', '.gitignore'     ] ],
               [ 'gitpre-commit', [ '_appldir', '.gitpre-commit' ] ], ],
      svn => [], };

   $data = { builders => $builders, templates => $templates, vcs => $vcs };
   $self->output( "Creating index ${index}" );
   $self->file->data_dump
      ( data => $data, path => $index, storage_class => 'Any' );

   return $self->_merge_lists( $data );
}

sub _create_mask {
   my $self = shift; return oct q(0777) ^ $self->_exec_perms;
}

sub _exec_perms {
   my $self = shift; return (($self->perms & oct q(0444)) >> 2) | $self->perms;
}

sub _find_appldir {
   my $self = shift; my $dir = $self->io( getcwd ); my $prev;

   while (not $prev or $prev ne $dir) {
      $dir->catfile( 'Build.PL'    )->exists and return $dir;
      $dir->catfile( 'Makefile.PL' )->exists and return $dir;
      $prev = $dir; $dir = $dir->parent;
   }

   throw error => 'File [_1] not in path', args => [ $self->_project_file ];
   return; # Never reached
}

sub _get_target {
   my ($self, $dir, $f) = @_;

   my $car = shift @{ $self->extra_argv } or throw 'No target specified';

   unless ($self->extra_argv->[ 0 ]) {
      my $meta = $self->get_meta( $self->_find_appldir );

      push @{ $self->extra_argv }, prefix2class $meta->name;
   }

   my $target = $self->$dir->catfile( $f ? $f->( $car ) : $car );

   $target->perms( $self->perms )->assert_filepath;
   return $target;
}

sub _initialize_distribution {
   my ($self, $args) = @_; my $mdf; __chdir( $self->_appldir );

   if ($self->builder eq 'DZ') {
      $self->run_cmd( 'dzil build' );
      $self->run_cmd( 'dzil clean' );
      $mdf = 'README.mkdn';
   }
   elsif ($self->builder eq 'MB') {
      $self->run_cmd( 'perl '.$self->_project_file );
      $self->run_cmd( './Build manifest'  );
      $self->run_cmd( './Build distmeta'  );
      $self->run_cmd( './Build distclean' );
      $mdf = 'README.md';
   }
   elsif ($self->builder eq 'MI') {
      $self->run_cmd( 'perl '.$self->_project_file );
      $self->run_cmd( 'make manifest' );
      $self->run_cmd( 'make clean' );
      $mdf = 'README.mkdn';
   }

   $mdf and $self->_appldir->catfile( $mdf )->exists
        and $self->_add_to_vcs( { target => $mdf } );
   return;
}

sub _initialize_git {
   my ($self, $args) = @_; __chdir( $self->_appldir );

   my $branch = $self->branch;

   $self->run_cmd  ( 'git init'   );
   $self->_add_hook( 'commit-msg' );
   $self->_add_hook( 'pre-commit' );
   $self->run_cmd  ( 'git add .'  );
   $self->run_cmd  ( "git commit -m 'Created Git ${branch}'" );
   return;
}

sub _initialize_svn {
   my ($self, $args) = @_; my $appbase = $args->{appbase}; __chdir( $appbase );

   my $repository = $appbase->catdir( $self->repository );

   $self->run_cmd( "svnadmin create ${repository}" );

   my $branch = $self->branch;
   my $msg    = "Created SVN ${branch}";
   my $url    = 'file://'.catdir( $repository, $branch );

   $self->run_cmd( "svn import ${branch} ${url} -m '${msg}'" );

   my $appldir = $self->_appldir; $appldir->rmtree;

   $self->run_cmd( "svn co ${url}" );
   $appldir->filter( sub { $_ !~ m{ \.git }msx and $_ !~ m{ \.svn }msx } );

   for my $target ($appldir->deep->all_files) {
      $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}" );
   }

   $msg = "Add RCS keywords to ${branch}";
   $self->run_cmd( "svn commit ${branch} -m '${msg}'" );
   return;
}

sub _initialize_vcs {
   my ($self, $args) = @_;

   $self->novcs and return;
   $self->output( 'Initializing VCS' );
   $self->vcs eq 'git' and $self->_initialize_git( $args );
   $self->vcs eq 'svn' and $self->_initialize_svn( $args );
   return;
}

sub _merge_lists {
   my ($self, $data) = @_; my $list = $data->{templates};

   push @{ $list }, @{ $data->{builders}->{ $self->builder } };
   not $self->novcs and push @{ $list }, @{ $data->{vcs}->{ $self->vcs } };

   return $list;
}

sub _render_template {
   my ($self, $template, $target) = @_;

   $template or throw 'No template specified';
   $target   or throw 'No template target specified';

   $target->exists and $target->is_dir
      and $target = $target->catfile( $template );
   $template = $self->template_dir->catfile( $template );

   $template->exists or
      return $self->log->warn( $self->loc( 'Path [_1] not found', $template ) );

   my $file  = $target->filename; my $prompt;

   $target->exists and not $self->force
      and $prompt = $self->add_leader( "File ${file} exists, overwrite?" )
      and not $self->yorn( $prompt, FALSE, TRUE )
      and return $target;

   my $conf  = { ABSOLUTE => TRUE, };

   $conf->{VARIABLES}->{loc} = sub { return $self->loc( @_ ) };

   my $tmplt = Template->new( $conf ) or throw $Template::ERROR;
   my $text  = NUL;

   $tmplt->process( $template->pathname, $self->stash, \$text )
      or throw $tmplt->error();

   $target->perms( $self->perms )->print( $text ); $target->close;

   return $target;
}

sub _test_distribution {
   my ($self, $args) = @_; __chdir( $self->_appldir );

   $ENV{TEST_SPELLING} = TRUE;
   $self->output ( 'Testing '.$self->_appldir );

   if ($self->builder eq 'DZ') {
      $self->run_cmd( 'dzil test', $self->quiet ? {} : { out => 'stdout' } );
   }
   else { $self->run_cmd( 'prove t', $self->quiet ? {} : { out => 'stdout' } ) }

   return;
}

# Private functions

sub __chdir {
   $_[ 0 ] or throw 'Directory not specified'; chdir $_[ 0 ];
   $_[ 0 ] eq getcwd or throw error => 'Path [_1] cannot change to',
                              args  => [ $_[ 0 ] ];
   return $_[ 0 ];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision - Create Perl distributions with VCS and selectable toolchain

=head1 Version

This documents version v0.3.$Rev: 44 $ of L<Module::Provision>

=head1 Synopsis

   # To reduce typing define a shell alias
   alias mp='module_provision --base ~/Projects'

   # Create a new distribution in your Projects directory
   mp dist Foo::Bar

   # Add another module
   cd ~/Projects/Foo-Bar
   mp module Foo::Bat

   # Add a program to the bin directory
   mp program foo-cli

   # Add another test script
   mp test 11another-one.t

   # Command line help
   mp -? | -H | -h [sub-command] | list_methods | dump_self

=head1 Description

L<Module::Provision> is used to create a skeletal CPAN distribution,
including basic builder scripts, tests, documentation, and module
code. It creates a VCS repository and, in the Git case, installs some
hooks that mimic the RCS Revision keyword expansion

On first use the directory F<~/.code_templates> is created and
populated with templates and an index file F<index.json>. The author
name, id, and email are derived from the system (the environment
variables C<AUTHOR> and C<EMAIL> take precedence) and stored in the
F<author>, F<author_id>, and F<author_email> files

If the default builder (C<MB>) is used, then the project file
F<Build.PL> loads C<inc::Bob> which instantiates an inline subclass of
L<Module::Build>. The code for the subclass is in
C<inc::SubClass>. The file C<inc::CPANTesting> allows for fine grained
control over which tests are run by which CPAN Testing smokers

If the Git VCS is used C<precommit> and C<commit-msg> hooks are
installed. The C<precommit> hook will expand the RCS Revision keyword
in files on the master branch if the file F<.distribution_name.rev>
exists in the parent of the working tree. The C<precommit> hook will
also update the version number and date/time stamp in the change log
(F<Changes>).  The C<commit-msg> hook will extract the first comment
line from the change log and use it as the commit message header. The
remainder of the commit message (if any) is used as the commit message
body. This means that so long as one detail line is added to the
change log no other commit message text is required. The following
makes for a suitable C<git log> alias:

   alias gl='git log -10 --pretty=format:"%h %ci %s"'

=head1 Configuration and Environment

Defines the following list of attributes which can be set from the
command line;

=over 3

=item C<base>

The directory which will contain the new project. Defaults to the users
home directory

=item C<branch>

The name of the initial branch to create. Defaults to F<master> for
Git and F<trunk> for SVN

=item C<builder>

Which of the three build systems to use. Defaults to C<MB>, which is
L<Module::Build>. Can be C<DZ> for L<Dist::Zilla> or C<MI> for
L<Module::Install>

=item C<force>

Overwrite the output files if they already exist

=item C<license>

The name of the license used on the project. Defaults to C<perl>

=item C<novcs>

Do not create or use a VCS. Defaults to C<FALSE>. Used by the test script

=item C<perms>

Permissions used to create files. Defaults to C<644>. Directories and
programs have the execute bit turned on if the corresponding read bit
is on

=item C<project>

The class name of the new project. Should be the first extra argument on the
command line

=item C<repository>

Name of the directory containing the SVN repository. Defaults to F<repository>

=item C<templates>

Location of the code templates in the users home directory. Defaults to
F<.code_templates>

=item C<vcs>

The version control system to use. Defaults to C<git>, can be C<svn>

=back

=head1 Subroutines/Methods

The following methods constitute the public API

=head2 create_directories

   $self->create_directories( $args );

Creates the required directories for the new distribution

=head2 dist

   $exit_code = $self->dist;

Create a new distribution specified by the module name on the command line

=head2 init_templates

   $exit_code = $self->init_templates;

Initialise the F<.code_templates> directory and create the F<index.json> file

=head2 module

   $exit_code = $self->module;

Creates a new module specified by the class name on the command line

=head2 post_hook

   $self->post_hook( $args );

Runs after the new distribution has been created

=head2 pre_hook

   $args = $self->pre_hook( {} );

Runs before the new distribution is created

=head2 program

   $exit_code = $self->program;

Creates a new program specified by the program name on the command line

=head2 render_templates

   $self->render_templates( $args );

Renders the list of templates in C<<$args->templates>> be repeatedly calling
calling L<Template> passing in the C<stash>

=head2 test

   $exit_code = $self->test;

Creates a new test specified by the test file name on the command line

=head1 Diagnostics

Add C<-D> to command line to turn on debug output

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Date::Format>

=item L<File::DataClass>

=item L<File::ShareDir>

=item L<Module::Metadata>

=item L<Perl::Version>

=item L<Pod::Markdown>

=item L<Template>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Provision.  Source
code is on Github git://github.com/pjfl/Module-Provision.git. Patches
and pull requests are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

L<Module::Starter> - For some of the documentation and tests

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

