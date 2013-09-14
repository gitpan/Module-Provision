# @(#)Ident: CPANDistributions.pm 2013-09-03 12:33 pjf ;

package Module::Provision::TraitFor::CPANDistributions;

use namespace::sweep;
use version;  our $VERSION = qv( sprintf '0.23.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Crypt::Util qw( decrypt_from_config encrypt_for_config
                                 is_encrypted );
use Class::Usul::Functions   qw( throw );
use Class::Usul::Types       qw( NonEmptySimpleStr );
use English                  qw( -no_match_vars );
use HTTP::Request::Common    qw( POST );
use HTTP::Status;
use Scalar::Util             qw( blessed );
use Moo::Role;

requires qw( add_leader config debug distname dist_version dumper
             ensure_class_loaded info io loc log next_argv output yorn );

# Private attributes
has '_debug_http_method' => is => 'ro', isa => NonEmptySimpleStr,
   builder               => '_build__debug_http_method', init_arg => undef;

# Public methods
sub cpan_upload : method {
   my $self = shift; my $ver = $self->next_argv; my $file;

   if ($ver) { $file = $self->distname."-${ver}.tar.gz" }
   else {
      $file = $self->distname.'-'.$self->dist_version.'.tar.gz';
      -f $file or $file = $self->distname.'-v'.$self->dist_version.'.tar.gz';
   }

   -f $file or throw $self->loc( 'File [_1] not found', $file );

   $self->ensure_class_loaded( 'CPAN::Uploader' );

   my $args   = $self->_read_pauserc; $args->{subdir} //= lc $self->distname;
   my $prompt = $self->add_leader( $self->loc( 'Really upload to CPAN' ) );

   exists $args->{dry_run}
       or $args->{dry_run} = not $self->yorn( $prompt, FALSE, TRUE, 0 );

   CPAN::Uploader->upload_file( $file, $args );
   return OK;
}

sub delete_cpan_files : method {
   my $self   = shift;
   my $args   = $self->_read_pauserc; $args->{subdir} //= lc $self->distname;
   my $files  = $self->_convert_versions_to_paths( $self->extra_argv, $args );
   my $prompt = $self->loc( 'Really delete files from CPAN' );
      $prompt = $self->add_leader( $prompt );

   exists $args->{dry_run}
       or $args->{dry_run} = not $self->yorn( $prompt, FALSE, TRUE, 0 );

   if ($args->{dry_run}) {
      $self->output( 'By request, cowardly refusing to do anything at all' );
      $self->output( "The following would have been used to delete files:\n" );
      $self->dumper( $args  );
      $self->dumper( $files );
   }
   else { $self->_delete_files( $files, $args ) }

   return OK;
}

sub set_cpan_password : method {
   my $self = shift; my $args = $self->_read_pauserc;

   $args->{password} = $self->next_argv or throw $self->loc( 'No password' );
   $self->_write_pauserc( $args );
   return OK;
}

# Private methods
sub _build__debug_http_method {
   return $ENV{CPAN_DELETE_FILES_DISPLAY_HTTP_BODY}
        ? 'as_string' : 'headers_as_string';
}

sub _convert_versions_to_paths {
   my ($self, $versions, $args) = @_; my $paths = []; $args ||= {};

   my $distname = $self->distname;
   my $subdir   = $args->{subdir} ? $args->{subdir}.'/' : NUL;

   for my $version (@{ $versions || [] }) {
      for my $extn (qw(meta readme tar.gz)) {
         push @{ $paths }, "${subdir}${distname}-${version}.${extn}";
      }
   }

   return $paths;
}

sub _delete_files {
   my ($self, $files, $args) = @_; my $target = $args->{target} || 'PAUSE';

   $self->info( 'Registering to delete files with the [_1] web server',
                { args => [ $target ] } );
   $self->ensure_class_loaded( 'LWP::UserAgent' );

   my $agent   = LWP::UserAgent->new;

   $agent->agent( $self->_ua_string ); $agent->env_proxy;
   $args->{http_proxy} and $agent->proxy( http => $args->{http_proxy} );

   my $uri     = $args->{delete_files_uri} || $self->config->delete_files_uri;
   my $request = $self->_get_delete_request( $files, $args, $uri );

   $self->info( 'POSTing delete files request to [_1]', { args => [ $uri ] } );
   $self->_throw_on_error( $uri, $target, $agent->request( $request ) );
   return;
}

sub _get_delete_request {
   my ($self, $files, $args, $uri) = @_;

   my @body = ( HIDDENNAME => $args->{user},
                SUBMIT_pause99_delete_files_delete => 'Delete', );

   for my $file (@{ $files }) {
      push @body, 'pause99_delete_files_FILE', $file;
   }

   my $request = POST( $uri, \@body );

   $request->authorization_basic( $args->{user}, $args->{password} );
   $self->_log_http_debug( 'REQUEST', $request );
   return $request;
}

sub _log_http_debug {
   my ($self, $type, $obj, $msg) = @_; $self->debug or return;

   my $method = $self->_debug_http_method;

   $self->log->debug( $_ ) for ( $msg ? $msg : (),
                                 "----- ${type} BEGIN -----\n",
                                          $obj->$method()."\n",
                                 "----- ${type} END -------\n" );
   return;
}

sub _read_pauserc {
   my $self = shift; my $dir = $self->config->my_home; my $attr = {};

   for ($self->io( [ $dir, q(.pause) ] )->chomp->getlines) {
      ($_ and $_ !~ m{ \A \s* \# }mx) or next;

      my ($k, $v) = m{ \A \s* (\w+) (?: \s+ (.+))? \z }mx;

      exists $attr->{ $k }
         and throw $self->loc( 'Multiple enties for [_1]', $k );
      $attr->{ $k } = $v || NUL;
   }

   my $pword; exists $attr->{password}
      and $pword = $attr->{password} and is_encrypted( $pword )
      and $attr->{password} = decrypt_from_config( $self->config, $pword );

   return $attr;
}

sub _throw_on_error {
   my ($self, $uri, $target, $response) = @_;

   defined $response or throw $self->loc
      ( 'Request completely failed - we got undef back: [_1]', $OS_ERROR );

   if ($response->is_error) {
      my $class = blessed $self || $self;

      $response->code == RC_NOT_FOUND and throw $self->loc
         (  "PAUSE's CGI for handling messages seems to have moved!\n".
            "(HTTP response code of 404 from the [_1] web server)\n".
            "It used to be: [_2]\nPlease inform the maintainer of [_3]\n",
            $target, $uri, $class );

      throw $self->loc( "Request failed error code [_1]\n  Message: [_2]\n",
                        $response->code, $response->message );
   }

   $self->_log_http_debug( 'RESPONSE', $response, 'Looks OK!' );
   $self->info( '[_1] delete request sent ok [[_2]]',
                { args => [ $target, $response->code ] } );
   return;
}

sub _ua_string {
   my $self  = shift;
   my $class = blessed $self || $self;
   my $ver   = $class->VERSION // 'dev';

   return "${class}/${ver}";
}

sub _write_pauserc {
   my ($self, $attr) = @_;

   my $file = $self->config->my_home->catfile( '.pause' );

   $attr->{password} = encrypt_for_config( $self->config, $attr->{password} );

   $file->println( "${_} ".$attr->{ $_ } ) for (sort keys %{ $attr });

   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::CPANDistributions - Uploads/Deletes distributions to/from CPAN

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::CPANDistributions';

=head1 Version

This documents version v0.23.$Rev: 1 $ of
L<Module::Provision::TraitFor::CPANDistributions>

=head1 Description

Uploads/Deletes distributions to/from CPAN

=head1 Configuration and Environment

Reads PAUSE account data from F<~/.pause>

Defines no attributes

=head1 Subroutines/Methods

=head2 cpan_upload - Uploads a distribution to CPAN

   $exit_code = $self->cpan_upload;

Uses L<CPAN::Uploader> to do the heavy lifting

=head2 delete_cpan_files - Deletes a distribution from CPAN

   $exit_code = $self->delete_cpan_files;

You must specify the version of the distribution to delete

=head2 set_cpan_password - Set the PAUSE server password

   $exit_code = $self->set_cpan_password;

Sets the password used to connect to the PAUSE server. Once used the
command line program C<cpan-upload> will not work since it cannot
decrypt the password in the configuration file F<~/.pause>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<CPAN::Uploader>

=item L<HTTP::Message>

=item L<LWP::UserAgent>

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
