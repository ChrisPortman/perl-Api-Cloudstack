#!/usr/bin/env perl

use strict;
use warnings;
use Api::Cloudstack;
use Data::Dumper;

my $SAFE = 1;
my $snapsDir = '/mnt/secondary/snapshots/';

my $cloud  = Api::Cloudstack->new( 
    'cloudServer' => 'itcloud',
    'port'        => '443',
    'ssl'         => 1,
    'debug'       => 0,
    'apikey'      => '<yourApiKey>',
    'secret'      => '<yourApiSec>',
);

sub listSnapsInCS {
    my $projectId = shift;
    
    my %args;
    $args{'projectid'} = $projectId if $projectId;
    
    my @snaps = $cloud->listSnapshots(%args);
    
    if (@snaps) {
        return wantarray ? @snaps : \@snaps;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError fetching snapshots: $error\n";
    }
    
    return;
}

sub listSnapsOnDisk {
    my @diskSnaps = `find $snapsDir -type f`;
    return wantarray ? @diskSnaps : \@diskSnaps;
}

sub listProjectsCS {
    my @projects = $cloud->listProjects();
    
    if (@projects) {
        return wantarray ? @projects : \@projects;
    }
    elsif ( my $error = $cloud->error() ) {
        print "\tError fetching projects: $error\n";
    }
    
    return;
}

my @projects  = map { $_->{id} } listProjectsCS();
my @diskSnaps = listSnapsOnDisk();

my %csSnaps;
for (@projects, undef) {
    my @snaps = listSnapsInCS($_);
    map { $csSnaps{$_->{name}} = 1 } @snaps;
}
    
print "Cloudstack projects:\n";
print "\t$_\n" for sort @projects;

print "\nAll Cloudstack snapshots:\n";
print "\t$_\n" for sort keys %csSnaps;

print "\nAll Filesystem snapshots:\n";
print "\t$_" for sort @diskSnaps;
print "\n";

for my $dsnap (@diskSnaps) {
    chomp($dsnap);
    my ($snapName) = $dsnap =~ m|/([^/]+)$|;
    
    unless ( $csSnaps{$snapName} ) {
        print "Deleting $dsnap\n";
        
        unless ($SAFE) {
            unlink $dsnap
              or warn "Failed to delete $dsnap: $!\n";
        }
    }
    else {
        print "NOT deleting $dsnap\n";
    }
}

exit;
