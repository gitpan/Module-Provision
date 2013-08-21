# @(#)Ident: AddingFiles.pm 2013-06-30 18:47 pjf ;

package Module::Provision::TraitFor::AddingFiles;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.21.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( classfile throw );
use Moo::Role;

requires qw( add_to_vcs appldir binsdir exec_perms libdir loc method
             module_abstract next_argv output project
             render_template stash testdir );

# Construction
around 'generate_metadata' => sub {
   my ($next, $self, @args) = @_; my $mdf = $self->$next( @args );

   $mdf and $self->appldir->catfile( $mdf )->exists
        and $self->add_to_vcs( $mdf );

   return $mdf;
};

# Public methods
sub module : method {
   my $self = shift; my $target = $self->_get_target( 'libdir', \&classfile );

   $self->output( 'Adding new module' );
   $target = $self->render_template( 'perl_module.pm', $target );
   $self->add_to_vcs( $target, 'module' );
   return OK;
}

sub program : method {
   my $self = shift; my $target = $self->_get_target( 'binsdir' );

   $self->output( 'Adding new program' );
   $target = $self->render_template( 'perl_program.pl', $target );
   chmod $self->exec_perms, $target->pathname;
   $self->add_to_vcs( $target, 'program' );
   return OK;
}

sub test : method {
   my $self = shift; my $target = $self->_get_target( 'testdir' );

   $self->output( 'Adding new test' );
   $target = $self->render_template( '10test_script.t', $target );
   $self->add_to_vcs( $target, 'test' );
   return OK;
}

# Private methods
sub _get_target {
   my ($self, $dir, $f) = @_;

   my $car      = $self->next_argv or throw $self->loc( 'No target specified' );
   my $abstract = $self->next_argv
               || ($self->method eq 'program' ? $self->_program_abstract
                                              : $self->module_abstract );

   $self->project; # Force evaluation of lazy attribute

   my $target   = $self->$dir->catfile( $f ? $f->( $car ) : $car );

   $target->perms( $self->perms )->assert_filepath;

   if    ($self->method eq 'module')  { $self->stash->{module      } = $car }
   elsif ($self->method eq 'program') { $self->stash->{program_name} = $car }

   $self->method ne 'test' and $self->stash->{abstract} = $abstract;

   return $target;
}

sub _program_abstract {
   return $_[ 0 ]->loc( 'One-line description of the programs purpose' );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::AddingFiles - Adds additional files to the project

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::AddingFiles';

=head1 Version

This documents version v0.21.$Rev: 1 $ of L<Module::Provision::TraitFor::AddingFiles>

=head1 Description

Adds additional modules, programs, and tests to the project

=head1 Configuration and Environment

Requires the following attributes to be defined in the consuming
class; C<add_to_vcs>, C<appldir>, C<binsdir>, C<exec_perms>, C<libdir>,
C<module_abstract>, C<render_template>, C<stash>, and C<testdir>

Modifies the C<generate_metadata> method. If C<generate_metadata> returns
a pathname and the file exists it is added to the VCS

Defines no attributes

=head1 Subroutines/Methods

=head2 module - Create a new Perl module file

   $exit_code = $self->module;

Creates a new module specified by the class name on the command line

=head2 program - Create a new Perl program file

   $exit_code = $self->program;

Creates a new program specified by the program name on the command line

=head2 test - Create a new Perl test script

   $exit_code = $self->test;

Creates a new test specified by the test file name on the command line

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Moose::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
