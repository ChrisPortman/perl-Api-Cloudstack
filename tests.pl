#!/usr/bin/env perl

use strict;
use warnings;
use Api::Cloudstack;
use Data::Dumper;

my $DUMP_RESULT = 1;

#Enable/disable tests in this hash.  Keys match the name of a sub.
my %tests = (
    'createAccount' => 0,
    'createProject' => 0,
    'listAccounts'  => 0,
    'listSnapshots' => 1,
    'listProjects'  => 1,
);

my $cloud  = Api::Cloudstack->new( 
    'cloudServer' => 'cloudmgt.optusnet.com.au',
    'port'        => '443',
    'ssl'         => 1,
    'debug'       => 0,
    'apikey'      => '<yourApiKey>',
    'secret'      => '<yourApiSec>',
);

sub createAccount {
    print "Testing createAccount:\n";
    
    my $userFirst = 'Test';
    my $userLast  = 'Account';
    my $userName  = 'test account';
    my $userEmail = 'test.account@email.com';
    
    my $user = $cloud->createAccount(
        username  => $userName,
        password  => 'sdkjhsdkfjhsdjklfhsdlfhsdljfh',
        firstname => $userFirst,
        lastname  => $userLast,
        email     => $userEmail,
    );
    
    if ($user) {
        print "\tCreated user $userFirst $userLast\n";
        print Dumper($user) if $DUMP_RESULT;
        return 1;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError creating $userFirst $userLast: $error\n";
    }
    else {
        print "\tError creating $userFirst $userLast: Unknown error!\n";
    }
    
    return;
}

sub createProject {
    print "Testing createProject:\n";

    my $projectName = 'Test Project';
    my $projectDesc = 'This is a test Project';
    my $userName    = 'test user';

    my $project = $cloud->createProject(
        name        => $projectName,
        displaytext => $projectDesc,
        account     => $userName,
    );
    
    if ($project) {
        print "\tCreated project $projectName\n";
        print Dumper($project) if $DUMP_RESULT;
        return 1;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError creating project: $error\n";
    }
    else {
        print "\tError creating project: Unknown error!\n";
    }
    
    return;
}

sub listProjects {
    print "Testing listProjects:\n";

    my @projects = $cloud->listProjects();
    
    if (@projects) {
        print "\tRetrieved ".@projects." projects:\n";
        for my $proj (sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @projects) {
            print "\t\t".$proj->{'name'}."\n";
        }
        print Dumper(\@projects) if $DUMP_RESULT;
        return 1;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError fetching projects: $error\n";
    }
    else {
        print "\tError fetching projects: Unknown error!\n";
    }
    
    return;
}

sub listAccounts {
    print "Testing listAccounts:\n";
    
    my @accounts = $cloud->listAccounts('accounttype' => 0);
    
    if (@accounts) {
        print "\tRetrieved ".@accounts." accounts:\n";
        for my $acc (sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @accounts) {
            print "\t\t".$acc->{'name'}."\n";
        }
        print Dumper(\@accounts) if $DUMP_RESULT;
        return 1;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError fetching accounts: $error\n";
    }
    else {
        print "\tError fetching accounts: Unknown error!\n";
    }
    
    return;
}

sub listSnapshots {
    print "Testing listSnapshots:\n";
    
    my @snaps = $cloud->listSnapshots();
    
    if (@snaps) {
        print "\tRetrieved ".@snaps." snapshots:\n";
        for my $snap (sort { $a->{'name'} cmp $b->{'name'} } @snaps) {
            print "\t\t".$snap->{'name'}."\n";
        }
        print Dumper(\@snaps) if $DUMP_RESULT;
        return 1;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError fetching snapshots: $error\n";
    }
    else {
        print "\tError fetching snapshots: Unknown error!\n";
    }
    
    return;
}

for my $test ( keys %tests ) {
    next unless $tests{$test};
    
    eval "$test();";
    if ($@) {
        print "Could not execute test for $test: $@\n";
    }
}

exit;
