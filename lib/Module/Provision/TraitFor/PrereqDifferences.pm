# @(#)Ident: PrereqDifferences.pm 2013-05-15 17:36 pjf ;

package Module::Provision::TraitFor::PrereqDifferences;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev: 6 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(classfile is_member emit throw);
use English                qw(-no_match_vars);
use Module::Metadata;

# Public methods
sub prereq_diffs : method {
   my $self    = shift;

   $self->ensure_class_loaded( 'CPAN' );
   $self->ensure_class_loaded( 'Module::CoreList' );
   $self->ensure_class_loaded( 'Pod::Eventual::Simple' );

   my $field   = shift @{ $self->extra_argv } || q(requires);
   my $filter  = "_filter_${field}_paths";
   my $sources = $self->$filter( $self->_source_paths );
   my $depends = $self->_filter_dependents( $self->_dependencies( $sources ) );

   __emit_diffs( $self->_compare_prereqs_with_used( $field, $depends ) );
   return OK;
}

# Private methods
sub _compare_prereqs_with_used {
   my ($self, $field, $depends) = @_;

   my $file       = $self->project_file;
   my $prereqs    = $self->_prereq_data->{ $field };
   my $add_key    = "Would add these to the ${field} in ${file}";
   my $remove_key = "Would remove these from the ${field} in ${file}";
   my $update_key = "Would update these in the ${field} in ${file}";
   my $result     = {};

   for (grep { defined $depends->{ $_ } } keys %{ $depends }) {
      if (exists $prereqs->{ $_ }) {
         my $oldver = version->new( $prereqs->{ $_ } );
         my $newver = version->new( $depends->{ $_ } );

         if ($newver != $oldver) {
            $result->{ $update_key }->{ $_ }
               = $prereqs->{ $_ }.q( => ).$depends->{ $_ };
         }
      }
      else { $result->{ $add_key }->{ $_ } = $depends->{ $_ } }
   }

   for (keys %{ $prereqs }) {
      exists $depends->{ $_ }
         or $result->{ $remove_key }->{ $_ } = $prereqs->{ $_ };
   }

   return $result;
}

sub _consolidate {
   my ($self, $used) = @_; my (%dists, %result);

   for my $used_key (keys %{ $used }) {
      my ($curr_dist, $module, $used_dist); my $try_module = $used_key;

      while ($curr_dist = __dist_from_module( $try_module )
             and (not $used_dist
                  or  $curr_dist->base_id eq $used_dist->base_id)) {
         $module = $try_module;
         $used_dist or $used_dist = $curr_dist;
         $try_module =~ m{ :: }mx or last;
         $try_module =~ s{ :: [^:]+ \z }{}mx;
      }

      my $was = $module; $used_dist and not $curr_dist
         and $module = __recover_module_name( $used_dist->base_id )
         and $self->debug
         and $self->output( "Recovered ${module} from ${was}" );

      if ($module) {
         not exists $dists{ $module }
            and $dists{ $module } = $self->_version_from_module( $module );
      }
      else { $result{ $used_key } = $used->{ $used_key } }
   }

   $result{ $_ } = $dists{ $_ } for (keys %dists);

   return \%result;
}

sub _dependencies {
   my ($self, $paths) = @_; my $used = {};

   for my $path (@{ $paths }) {
      my $lines = __read_non_pod_lines( $path );

      for my $line (split m{ \n }mx, $lines) {
         my $modules = __parse_depends_line( $line ); $modules->[ 0 ] or next;

         for (@{ $modules }) {
            __looks_like_version( $_ ) and $used->{perl} = $_ and next;

            not exists $used->{ $_ }
               and $used->{ $_ } = $self->_version_from_module( $_ );
         }
      }
   }

   return $used;
}

sub _filter_dependents {
   my ($self, $used) = @_;

   my $perl_version = $used->{perl} || 5.008_008;
   my $core_modules = $Module::CoreList::version{ $perl_version };
   my $provides     = $self->get_meta->provides;

   return $self->_consolidate( { map   { $_ => $used->{ $_ }              }
                                 grep  { not exists $core_modules->{ $_ } }
                                 grep  { not exists $provides->{ $_ }     }
                                 keys %{ $used } } );
}

sub _filter_build_requires_paths {
   return [ grep { m{ \.t \z }mx } @{ $_[ 1 ] } ];
}

sub _filter_configure_requires_paths {
   my $file = $_[ 0 ]->project_file;

   return [ grep { m{ \A inc }mx or $_ eq $file } @{ $_[ 1 ] } ];
}

sub _filter_requires_paths {
   my $file = $_[ 0 ]->project_file;

   return [ grep { not m{ \A inc }mx and not m{ \.t \z }mx and $_ ne $file }
                @{ $_[ 1 ] } ];
}

sub _is_perl_source {
   my ($self, $path) = @_;

   $path =~ m{ (?: \.pm | \.t | \.pl ) \z }imx and return TRUE;

   my $line = $self->io( $path )->getline; $line or return FALSE;

   return $line =~ m{ \A \#! (?: .* ) perl (?: \s | \z ) }mx ? TRUE : FALSE;
}

sub _prereq_data {
   my $self = shift; $self->chdir( $self->appldir );

   if ($self->builder eq 'MB') {
      my $cmd  = "${EXECUTABLE_NAME} Build.PL; ./Build prereq_data";

      return eval $self->run_cmd( $cmd )->stdout;
   }

   return {};
}

sub _source_paths {
   return [ grep { $_[ 0 ]->_is_perl_source( $_ ) }
                @{ $_[ 0 ]->get_manifest_paths } ];
}

sub _version_from_module {
   my ($self, $module) = @_;

   my $inc  = [ $self->libdir, @INC ];
   my $info = Module::Metadata->new_from_module( $module, inc => $inc );
   my $ver; $info and $info->version and $ver = $info->version;

   return $ver ? Perl::Version->new( $ver ) : undef;
}

# Private functions
sub __dist_from_module {
   my $module = CPAN::Shell->expand( 'Module', $_[ 0 ] );

   return $module ? $module->distribution : undef;
}

sub __draw_line {
    return emit q(-) x ($_[ 0 ] || 60);
}

sub __emit_diffs {
   my $diffs = shift; __draw_line();

   for my $table (sort keys %{ $diffs }) {
      emit $table; __draw_line();

      for (sort keys %{ $diffs->{ $table } }) {
         emit "'$_' => ".$diffs->{ $table }->{ $_ }.",";
      }

      __draw_line();
   }

   return;
}

sub __extract_statements_from {
   my $line = shift;

   return grep { length }
          map  { s{ \A \s+ }{}mx; s{ \s+ \z }{}mx; $_ } split m{ ; }mx, $line;
}

sub __looks_like_version {
    my $ver = shift;

    return defined $ver && $ver =~ m{ \A v? \d+ (?: \.[\d_]+ )? \z }mx;
}

sub __parse_depends_line {
   my $line = shift; my $modules = [];

   for my $stmt (__extract_statements_from( $line )) {
      if ($stmt =~ m{ \A (?: use | require ) \s+ }mx) {
         my (undef, $module, $rest) = split m{ \s+ }mx, $stmt, 3;

         # Skip common pragma and things that don't look like module names
         $module =~ m{ \A (?: lib | strict | warnings ) \z }mx and next;
         $module =~ m{ [^\.:\w] }mx and next;

         push @{ $modules }, $module eq q(base) || $module eq q(parent)
                          ? ($module, __parse_list( $rest )) : $module;
      }
      elsif ($stmt =~ m{ \A (?: with | extends ) \s+ (.+) }mx) {
         push @{ $modules }, __parse_list( $1 );
      }
      elsif ($stmt =~ m{ [>] ensure_class_loaded \( \s* (.+?) \s* \) }mx) {
         my $module = $1;
            $module = $module =~ m{ \A [q\'\"] }mx ? eval $module : $module;

         push @{ $modules }, $module;
      }
   }

   return $modules;
}

sub __parse_list {
   my $string = shift;

   $string =~ s{ \A q w* [\(/] \s* }{}mx;
   $string =~ s{ \s* [\)/] \z }{}mx;
   $string =~ s{ [\'\"] }{}gmx;
   $string =~ s{ , }{ }gmx;

   return grep { length && !m{ [^\.:\w] }mx } split m{ \s+ }mx, $string;
}

sub __read_non_pod_lines {
   my $path = shift; my $p = Pod::Eventual::Simple->read_file( $path );

   return join "\n", map  { $_->{content} }
                     grep { $_->{type} eq q(nonpod) } @{ $p };
}

sub __recover_module_name {
   my $id = shift;  my @parts = split m{ [\-] }mx, $id; my $ver = pop @parts;

   return  join '::', @parts;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::PrereqDifferences - Displays a prerequisite difference report

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::PrereqDifferences';

=head1 Version

This documents version v0.15.$Rev: 6 $ of
L<Module::Provision::TraitFor::PrereqDifferences>

=head1 Description

Displays a prerequisite difference report

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 prereq_diffs

   $exit_code = $self->prereq_diffs;

Displays a prerequisite difference report

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<CPAN>

=item L<Module::CoreList>

=item L<Moose::Role>

=item L<Pod::Eventual::Simple>

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
