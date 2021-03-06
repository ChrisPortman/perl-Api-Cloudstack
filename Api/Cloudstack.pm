#!/usr/bin/env perl

=head1 NAME

Api::Cloudstack

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

  my $cloud  = Api::Cloudstack->new( 
      'cloudServer' => 'cloudmgmt.mycorp.com',
      'apikey'      => 'your_users_key',
      'secret'      => 'your_users_secret',

      'port'        => '443', #Optional, defaults to 80 or 443 if ssl=>1                     
      'ssl'         => 1,     #Optional
      'debug'       => 1,     #Noisy logging
  );
  
  my $user = $cloud->createAccount(
      username  => 'userBob',
      password  => 'bobspass',
      firstname => 'Bob',
      lastname  => 'Smith',
      email     => 'bob@mymail.com',
  );

=head1 DESCRIPTION

This module provides an OO interface to the Cloudstack API.  Documentation
on the API can be found here:

L<http://cloudstack.apache.org/docs/api/apidocs-4.0.0/TOC_Root_Admin.html>

The genericCall method is the real workhorse of this module.  Theoretically
all API interfaces can be used directly via genericCall, however, abstracted
methods for specific API interfaces, where provided, will apply validation
and sensible returns based on the purpose of the interface.

=cut

=head1 DIAGNOSTICS

All methods from this module should return undef when a failure occurs.
Your application should check for a true response and use the B<error>
method to retrieve the latest error message.  See the documentation for
the B<error> method below.

=cut

package Api::Cloudstack;

use strict;
use warnings;
use Carp;

use JSON::XS;
use LWP::UserAgent;
use URI::Escape;
use Digest::SHA  qw(hmac_sha1);
use MIME::Base64;
use Data::Dumper;

=head1 METHODS

=head2 new

Create a new Api::Cloudstack object:

  my $cloud  = Api::Cloudstack->new( 
      'cloudServer' => 'cloudmgmt.mycorp.com',
      'apikey'      => 'your_users_key',
      'secret'      => 'your_users_secret',

      'port'        => '443', #Optional, defaults to 8080 or 8096 if ssl=>1                     
      'ssl'         => 1,     #Optional
      'debug'       => 1,     #Noisy logging
  );

=head3 Parameters

B<cloudServer> (required), is the address of the management console.

B<apikey> (required), is your users API key used to authorise the use of 
the API.  This is transmitted as part of the API uri.

B<secret> (required), is your users API secret used to authenticate the
API call.  The api uri is signed with this and is not transmitted.

B<port> (optional), the network port the management server listens on for
API calls.  Defaults to 8080 if not using SSL or 8096 if using SSL.

B<ssl> (optional), turns on the use of SSL.  Default is off.  Boolean.

B<debug> (optional), turns on debugging output to STDOUT.  Default is off Boolean.

=cut

sub new {
    my $class = shift;
    my %args = _processArgs( 'new', @_ )
      or return;
    
    $class = ref $class || $class;
    
    my $proto = 'http';
    my $uri   = '/?';
    
    $args{'cloudServer'}
      or croak "No cloud management server provided";
    
    unless ( 
      ($args{'cloudServer'} eq 'localhost' or $args{'cloudServer'} eq '127.0.0.1')
      or ( $args{'apikey'} and $args{'secret'} ) )
    {
        croak 'Remote calls to the API require "apikey" and "secret" args';
    }
    
    if ($args{'cloudServer'} eq 'localhost' or $args{'cloudServer'} eq '127.0.0.1') {
        $args{'port'} = $args{'port'} || '8096';
    }
    else {
        $args{'port'} = $args{'port'} || '8080';
        $uri = '/client/api?';
    }
    
    if ( $args{'ssl'} ) {
        $proto = 'https';
    }
    
    $args{'url'} = $proto.'://'.$args{'cloudServer'}.':'.$args{'port'}.$uri;
    
    
    my $obj = bless \%args, $class;
    
    return $obj;
}

=head2 createAccount

Creat an account in cloudstack

  my $user = $cloud->createAccount(
      username  => 'userBob',
      password  => 'bobspass',
      firstname => 'Bob',
      lastname  => 'Smith',
      email     => 'bob@mymail.com',
  );

=head3 Parameters

All parameters are required and self-explanitory.  All values are scalars.

=cut

sub createAccount {
    my $self = shift;
    my %args = $self->_processArgs( 'createAccount', @_ )
      or return;
    
    #Enforce the required params
    $args{'username'}
      or croak "createAccount requires a username argument";
    $args{'password'}
      or croak "createAccount requires a password argument";
    $args{'email'}
      or croak "createAccount requires an email argument";
    $args{'firstname'}
      or croak "createAccount requires a firstname argument";
    $args{'lastname'}
      or croak "createAccount requires a lastname argument";
    
    #Allow the account type to use the numerical vals as per the API
    #or our abstractions.
    unless ( $args{'accounttype'} and $args{'accounttype'} =~ /^[012]$/ )
    {
        $args{'accounttype'} =
            (not $args{'accounttype'}) 
              || ( lc($args{'accounttype'})    eq 'user')       ? '0'
          : lc($args{'accounttype'})           eq 'rootadmin'   ? '1' 
          : lc($args{'accounttype'})           eq 'domainadmin' ? '2'
          : die "Something really wrong"
          ;
    }
    
    #Default timezone is AUS EST.
    $args{'timezone'} = $args{'timezone'} || 'Australia/Canberra';
    
    my %validParams = (
        'accounttype'    => qr/^(?:[012]|user|rootadmin|domainadmin)$/i,
        'email'          => qr/[\w.-]+@[\w.-]+.\w{2,4}/i,
        'firstname'      => qr/^(?:[a-z'\s]+)$/i,
        'lastname'       => qr/^(?:[a-z'\s]+)$/i,
        'password'       => qr/^.+$/,
        'username'       => qr/^(?:[a-z'\s]+)$/i,
        'account'        => qr/^(?:[a-z'\s]+)$/i,
        'accountdetails' => qr/^.+$/, #Dont know what this is. Docs dont say
        'domainid'       => qr/^[a-z0-9\-]+/i,
        'networkdomain'  => qr/^.+$/, #Dont know what this is. Docs dont say
        'timezone'       => qr/[a-z]+\/[a-z]+/i,
    );
    
    $self->_validateParams('createAccount', \%args,\%validParams)
      or return;
      
    my $result = $self->genericCall(
        'command' => 'createAccount',
        %args,
    );
    
    return $result;
}

=head2 listAccounts

Return a list of hash refs detailing each account.  

  my @accounts = $cloud->listAccounts();

head3 Parameters

B<accounttype> (optional) List accounts by account type. Valid account types are 1 (admin), 2 (domain-admin), and 0 (user). Appears to default to "user" within the api if not specified.

B<domainid> (optional) list only resources belonging to the domain specified

B<id> (optional) list account by account ID

B<iscleanuprequired> (optional) list accounts by cleanuprequred attribute (values are true or false)

B<isrecursive> (optional) defaults to false, but if true, lists all resources from the parent specified by the domainId till leaves.

B<keyword> (optional) List by keyword

B<name> (optional) list account by account name

B<state> (optional) list accounts by state. Valid states are enabled, disabled, and locked.

B<listall> (implied) This is hard set to true.  This is because it makes sense that you would want all you can get plus, there appears to be a bug in the API where, although no parameters are required, if you submit no parameters, you get no results.  This ensures that you get results.

=cut

sub listAccounts {
    my $self = shift;
    my %args = $self->_processArgs( 'listAccounts', @_ );
    
    #Enforce the required params
    $args{'listall'} = 'true';

    #Allow the account type to use the numerical vals as per the API
    #or our abstractions.
    unless ( defined $args{'accounttype'} and $args{'accounttype'} =~ /^[012]$/ )
    {
        $args{'accounttype'} =
            (not $args{'accounttype'}) 
              || ( lc($args{'accounttype'})    eq 'user')       ? '0'
          : lc($args{'accounttype'})           eq 'rootadmin'   ? '1' 
          : lc($args{'accounttype'})           eq 'domainadmin' ? '2'
          : die "Something really wrong"
          ;
    }
    
    my %validParams = (
        'accounttype'       => qr/^(?:[012]|user|rootadmin|domainadmin)$/i,
        'domainid'          => qr/^[a-z0-9\-]+/i,
        'id'                => qr/^[a-z0-9\-]+/i,
        'iscleanuprequired' => qr/^(?:true|false)$/i,
        'isrecursive'       => qr/^(?:true|false)$/i,
        'keyword'           => qr/^[a-z0-9\-]+/i,
        'name'              => qr/^(?:[a-z'\s]+)$/i,
        'state'             => qr/^(?:enabled|disabled|locked)/,
        'listall'           => qr/^true$/,
    );
    $self->_validateParams('listAccounts', \%args,\%validParams)
      or return;
    
    my $result = $self->genericCall(
        'command' => 'listAccounts',
        %args,
    );
    
    my @results;
    
    if ($result->{listaccountsresponse}->{account}) {
        push @results, @{$result->{listaccountsresponse}->{account}};
    }

    return @results;
}

=head2 createProject

Creat a project in cloudstack

  my $project = $cloud->createProject(
      name        => 'myname',
      displaytext => 'This describes my project',
      account     => 'Owner',
      domainid    => 'Domain id of the account',
  );

=head3 Parameters

B<name> (required) is the name of the project.

B<displaytext> (required) is the description.

B<account> (optional) is the account who will be the administrator of the project.

B<domain> (optional) is the domain to look in for the account.  Defaults to the Root domain.
While this is technically optional, if you specify an account and that account is not in 
the Root domain, this becomes mandatory.

=cut


sub createProject {
    my $self = shift;
    my %args = $self->_processArgs( 'createProject', @_ )
      or return;
    
    #enfoce the required params
    $args{'name'}
      or croak "createProject requires a name argument";
    $args{'displaytext'}
      or croak "createProject requires a name argument";
    
    if ($args{'account'}) {
        #account requires a domain id.  If we didnt get one, use the 
        #root domain id.
        $args{'domainid'} = $args{'domainid'}
          || 'aa915d7c-8618-4d68-97f2-636f414a122e'; 
    }
    
    my %validParams = (
        'name'        => qr/^.+$/,
        'displaytext' => qr/^.+$/,
        'account'     => qr/^(?:[a-z'\s]+)$/i,
        'domainid'    => qr/^[a-z0-9\-]+/i,
    );
    $self->_validateParams('createProject', \%args,\%validParams)
      or return;
    
    my $result = $self->genericCall(
        'command' => 'createProject',
        %args,
    );
    
    return $result;
}

=head2 listProjects

Return a list of hashes containting details of all projects.

  my @projects = $cloud->listProjects();
  
=head3 Parameters

TODO

=cut

sub listProjects {
    my $self = shift;
    my %args = $self->_processArgs( 'listProjects', @_ );
    
    #Enforce the required params
    $args{'listall'} = 'true';

    my %validParams = (
        'account'           => qr/^(?:[a-z'\s]+)$/i,
        'displaytext'       => qr/^.+/,
        'domainid'          => qr/^[a-z0-9\-]+/i,
        'id'                => qr/^[a-z0-9\-]+/i,
        'isrecursive'       => qr/^(?:true|false)$/i,
        'keyword'           => qr/^[a-z0-9\-]+/i,
        'name'              => qr/^(?:[a-z'\s]+)$/i,
        'tags'              => qr/^[a-z0-9\-\s]+/i,
        'state'             => qr/^.+/,
        'listall'           => qr/^true$/,
    );
    $self->_validateParams('listProjects', \%args,\%validParams)
      or return;
    
    my $result = $self->genericCall(
        'command' => 'listProjects',
        %args,
    );

    my @results;
    
    if ($result->{listprojectsresponse}->{project}) {
        push @results, @{$result->{listprojectsresponse}->{project}};
    }

    return @results;
}

=head2 listSnapshots

Return a list of hashes containing the details of all the snapshots.

  my @snapshots = $cloud->listSnapshots();
  
=head3 Parameters

B<account> (optional) List resources by account. Must be used with the domainId parameter.

B<domainid> (optional) list only resources belonging to the domain specified

B<id> (optional) list account by account ID

B<intervaltype> (optional) valid values are HOURLY, DAILY, WEEKLY, and MONTHLY.

B<isrecursive> (optional) defaults to false, but if true, lists all resources from the parent specified by the domainId till leaves.

B<keyword> (optional) List by keyword

B<name> (optional) list snapshots by snapshot name

B<projectid> (optional) list snapshots by project.

B<snapshottype> (optional) valid values are MANUAL or RECURRING.

B<tags> (optional) List resources by tags (key/value pairs)

B<volumeid> (optional) the ID of the disk volume.

B<listall> (implied) This is hard set to true.  This is because it makes sense that you would want all you can get plus, there appears to be a bug in the API where, although no parameters are required, if you submit no parameters, you get no results.  This ensures that you get results.

=cut

sub listSnapshots {
    my $self = shift;
    my %args = $self->_processArgs( 'listSnapshots', @_ );
    
    #Enforce the required params
    $args{'listall'} = 'true';

    my %validParams = (
        'account'           => qr/^(?:[a-z'\s]+)$/i,
        'domainid'          => qr/^[a-z0-9\-]+/i,
        'id'                => qr/^[a-z0-9\-]+/i,
        'intervaltype'      => qr/^(?:HOURLY|DAILY|WEEKLY|MONTHLY)$/,
        'isrecursive'       => qr/^(?:true|false)$/i,
        'keyword'           => qr/^[a-z0-9\-]+/i,
        'name'              => qr/^(?:[a-z'\s]+)$/i,
        'projectid'         => qr/^[a-z0-9\-]+/i,
        'snapshottype'      => qr/^(?:MANUAL|RECURRING)$/,
        'tags'              => qr/^[a-z0-9\-\s]+/i,
        'volumeid'          => qr/^[a-z0-9\-]+/i,
        'listall'           => qr/^true$/,
    );
    $self->_validateParams('listSnapshots', \%args,\%validParams)
      or return;
    
    my $result = $self->genericCall(
        'command' => 'listSnapshots',
        %args,
    );

    my @results;
    
    if ($result->{listsnapshotsresponse}->{snapshot}) {
        push @results, @{$result->{listsnapshotsresponse}->{snapshot}};
    }

    return @results;
}

=head2 genericCall

This method is used by the other methods to actually make the calls to
the API, but can also be used directly where an abstracted method does not
exist for the API interface you want to use.

  my $result = $cloud->genericCall(
      command => 'apiInterfaceName',
      %argsAsPerApiRequirements,
  );

=head3 Parameters

The only required parameter is B<command> which is the name of the 
API interface as per the API documentation.  All other parameters depend
on the API interface being used.

The keys for the additional parameters should be the parameter names 
exactly as per the API documentation as they will be passed verbatim.  

No validation of parameters or their values will be done here, that work
should be done in the abstracted API interface methods or, where one
doesn't exist, in the application code.

=cut

sub genericCall {
    my $self = shift;
    my %args = $self->_processArgs( 'genericCall', @_ )
      or return;

    unless ( $args{'command'} ) {
        $self->error('No command supplied to genericCall');
        return;
    }

    # Add the respose type and API key to the list of call args
    $args{'response'} = 'json';

    if ( $self->{'apikey'} ) {
        $args{'apikey'} = $self->{'apikey'};
    }

    #build the URI
    my $uri;
    for my $key ( sort keys %args ) {
        my $value = uri_escape($args{$key});
        $uri .= "&$key=$value";
    }
    $uri =~ s/^&//;

    #if theres a secret, use it to sign the call and then add the sig to the URI
    if ( $self->{'secret'} ) {
        my $sig = encode_base64( hmac_sha1( lc($uri), $self->{'secret'} ) );
        chomp($sig);
        $sig    = uri_escape($sig);
        $uri   .= "&signature=$sig";
    }
    
    # Make the call
    my $url = $self->{'url'}.$uri;
    $self->_debug("DEBUG: API call URL is: $url");

    my $can_accept = HTTP::Message::decodable;
    my $ua = LWP::UserAgent->new();
    $ua->default_header('Accept-Encoding' => $can_accept);
    
    if ($LWP::UserAgent::VERSION >= 5.837) {
        $ua->ssl_opts(verify_hostname => 0);
    }
        
    my $request = HTTP::Request->new(GET => $url);
    my $result  = $ua->request($request);
    
    if ($result) {
        $self->_debug( Dumper($result) );
        #Extract the content and try to decode the JSON
        my $decoded;
        if (my $content = $result->decoded_content(charset => 'none')) {
            eval {
                $decoded = decode_json($content);
            };
            if ($@) {
                $self->error( "API call did not return a valid JSON string" );
                return;
            }
        }

        #look for an errorcode and error message
        for my $key ( keys %{$decoded} ){
            if ($decoded->{$key}->{'errorcode'}) {
                my $code  = $decoded->{$key}->{'errorcode'};
                my $error = $decoded->{$key}->{'errortext'};
                $self->error( "Code $code - $error" );
                return;
            }
        }
    
        if ( $result->is_success ) {
            return $decoded;
        }
        else {
            $self->error( 'Recieved a failure attempting to call the API on '
              .$self->{'cloudServer'}
              .': '
              .$result->status_line
            );
            return;
        }
    }
}

=head2 error

All methods, upon encountering an error should set an error state and
then return undef.

Your application should check each method call for a true return.  If it
does not get one, it can use the error method to retrieve the last error
encountered.

  unless ( $cloud->someMethod(...) ) {
      my $error = $cloud->error();
      die $error;
  }

=cut

sub error {
    my $self  = shift;
    my $error = shift;
    
    my $ret = $self->{'error'} || $error;
    $self->{'error'} = $error;
    
    return $ret;
}

# Validates the supplied args.  Does not enforce mandatory args, that
# should be done in the method before comming here.  This validates that
# supplied args are valid args for the API call and that they are in the
# correct format.
sub _validateParams {
    my $self        = shift;
    my $method      = shift;
    my $args        = shift;
    my $validations = shift;
    
    $method
      or ($self->error("_validateParams needs a method name") and return);
    $args
      or ($self->error("_validateParams needs args to validate") and return);
    $validations
      or ($self->error("_validateParams needs validation rules") and return);
    
    ref $args and ref $args eq 'HASH'
      or ($self->error("An internal error occured: _validateParams needs args in a hash ref") and return);
    ref $validations and ref $validations eq 'HASH'
      or ($self->error("An internal error occured: _validateParams needs validations in a hash ref") and return);
    
    for my $arg ( keys %{$args} ) {
        unless ($validations->{ lc($arg) }) {
            $self->error("$arg is not a valid argument for $method");
            return;
        }
        
        unless ( $args->{$arg} =~ $validations->{ lc($arg) } ) {
            $self->error( $args->{$arg}.' is not a valid value for '.$arg );
            return;
        }
    }
    
    return 1;
}

sub _processArgs {
    my $self   = shift if ref $_[0] eq __PACKAGE__;
    my $method = shift;
    my @args   = @_;
    my %validArgs;
    
    $method
      or ($self->error("Internal error: _processArgs called without method name") and return);
    @args
      or return;
    
    if ( defined $args[1] ) {
        #Args supplied as a list
        #Check for even number of elements and cast as a hash.
        for my $elem (@args) {
            if (ref $elem) {
                croak "Args supplied to $method as list must all be scalar, reference found.";
            }
        }
        
        if (scalar @args % 2) {
            croak "Odd number of scalar args supplied to $method";
        }

        %validArgs = @args;
    }
    elsif (ref $args[0] and ref $args[0] eq 'ARRAY') {
        #Check the reffed array for even elements and cast into hash
        my @args = @{$args[0]};

        for my $elem (@args) {
            if (ref $elem) {
                croak "Args supplied to $method as list must all be scalar, reference found.";
            }
        }
        
        if (scalar @args % 2) {
            croak "Odd number of scalar args supplied to $method";
        }

        %validArgs = @args;
    }
    elsif (ref $args[0] and ref $args[0] eq 'HASH') {
        #Just return the Hash
        %validArgs = %{$args[0]};
    }
    
    if (%validArgs) {
        return wantarray ? %validArgs : \%validArgs;
    }
    else {
        croak "Could not derive valid args for $method";
    }
    
    return; #shouldnt get here.
}

sub _debug {
    my $self = shift;
    my $log  = shift;
    
    return unless $self->{'debug'};
    
    chomp($log);
    
    print $log."\n";
    
    return;
}

=head1 CONFIGURATION AND ENVIRONMENT



=head1 DEPENDENCIES

Api::Cloudstack requires the following modules on your system:

=over 2

=item * 

JSON::XS

=item * 

LWP::UserAgent

=item * 

URI::Escape

=item * 

Digest::SHA

=item * 

MIME::Base64

=back

=head1 INCOMPATIBILITIES



=head1 BUGS AND LIMITATIONS



=head1 AUTHOR

Chris Portman

=head1 LICENSE AND COPYRIGHT

General open source license applies.

=cut

1;
