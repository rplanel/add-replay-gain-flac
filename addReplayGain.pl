#!/usr/bin/perl -w
# addReplayGain.pl --- Add replay gain to flac file in music library
# Author: titus <titus@titus-laptop>
# Created: 27 Apr 2011
# Version: 0.01

use warnings;
use strict;
use Getopt::Long;
use Data::Dumper;
use File::Find;
use Encode qw( encode decode );

my ($music_lib,$verbose);

GetOptions(
    'lib=s'     => \$music_lib,
    'verbose|v' => \$verbose,
    ) or die;




my $add_replay_gain = 0;

my %options = (
    ## method call before wanted (in @_ all element (file + dir) in current dir )
    preprocess => sub {
        my $tmp  = "## Process directory $File::Find::dir ##";
        my $sep = '#' x length($tmp);
        my $msg = "\n$sep\n$tmp\n$sep\n";
	my @selectElems;
        my $album_replay_gain;
        my $current_album_gain;
        my $has_file = 0;
        my $find_flac = 0;
        $add_replay_gain = 0;
        
      ELEMS:
        for my $elem (@_) {

            if ( -d $elem && $elem !~ /^\./) {
                push @selectElems, $elem; 
            }
            else {
                $has_file = 1;
                $elem =~ s/\`/\\`/g;
                
                if ( $elem =~ /^.*\.flac$/) {
                    $find_flac = 1;
                    ## check if has replay gain ##
                    $current_album_gain    = undef;
                    $current_album_gain    = [split(/=/, `metaflac --show-tag=REPLAYGAIN_ALBUM_GAIN "$File::Find::dir/$elem"`)]->[1];# extract album gain value
                    $album_replay_gain = $current_album_gain if !defined $album_replay_gain;
                    
                    if (!defined $current_album_gain) {
                        # $msg .= "-Didn't find any album replay gain for the file: \"$elem\"\n";
                        $add_replay_gain = 1;
                        push (@selectElems, $elem);
                        last ELEMS;
                    }
                    if ($current_album_gain ne $album_replay_gain) {
                        # $msg .= "-$elem : album replay gain = $current_album_gain while for the other = $album_replay_gain\n";
                        $add_replay_gain = 1;
                        push (@selectElems, $elem);
                        last ELEMS;
                    }
                }
            }
        }
        if ( $verbose || $add_replay_gain ) {
            if ( $has_file ) { ## Don't want to display any message when directory is empty
                if ( !$find_flac ) {
                    $msg .=  "=> Didn't find any flac file in the directory: $File::Find::dir\n";
                }
                elsif ( !$add_replay_gain) {
                    ##$msg .= "=> No need to add replay gain\n\n";
                }
                print $msg;
            }
        }
	# print STDERR Dumper(\@selectElems);
	return @selectElems;
    },

    ####################
    wanted     => sub {
        if ( $add_replay_gain ) {
            my $dir = $File::Find::dir;
##            print '-Add replay gain to "',$dir,'"',"\n";
            `metaflac --add-replay-gain "$dir"/*.flac`;
        }
    },

    
    postprocess => sub {
        if ( $verbose || $add_replay_gain ) {
            my $dir = $File::Find::dir;
	    my $verboseMsg = [];
	    my $headers = ['TRACK_TITLE','TRACK_REPLAY_GAIN','ALBUM_REPLAY_GAIN'];
	    my $maxLength = {
		'track_gain' => length($headers->[1]),
		'album_gain' => length($headers->[2]),
		'filename'   => length($headers->[0]),
	    };

            opendir(my $dh, $dir) || die;
	    
            while(my $file = readdir $dh) {
                next if (!-f $file || $file !~ /^.*\.flac$/);
                $file =~ s/\`/\\`/g;
                my $album_gain = [split(/=/, `metaflac --show-tag=REPLAYGAIN_ALBUM_GAIN "$File::Find::dir/$file"`)]->[1];# extract album gain value
                my $track_gain = [split(/=/, `metaflac --show-tag=REPLAYGAIN_TRACK_GAIN "$File::Find::dir/$file"`)]->[1];# extract album gain value
                if ( !defined $album_gain || !defined $track_gain ) {
                    print "!!! Problem : no replay gain for flac file : $file\n";
                    exit;
                }
                chomp $track_gain;
                chomp $album_gain;
		
		
		
		push(
		    @$verboseMsg,
		    {
			'track_gain' => $track_gain,
			'album_gain' => $album_gain,
			'filename'   => $file
		    });
		
                # Update the max length
		$maxLength->{track_gain} = getMaxLength($track_gain,$maxLength->{track_gain});
		$maxLength->{album_gain} = getMaxLength($album_gain,$maxLength->{album_gain});
		$maxLength->{filename} = getMaxLength($file,$maxLength->{filename});
	    }
            closedir $dh;
	    
	    ## Print message
	    my $max_filename = $maxLength->{filename}+1;
	    my $max_track = $maxLength->{track_gain};
	    printf "%-${max_filename}s   %-${max_track}s   %s\n",$headers->[0], $headers->[1], $headers->[2] if scalar @$verboseMsg > 0; 
	    foreach my $msg (@$verboseMsg) {
		my $str = sprintf("%.${max_filename}s.. %.${max_track}s.. %s\n",decode("utf8",$msg->{filename}).' '.'.' x ${max_filename}, $msg->{track_gain}.' '.'.' x $max_track, $msg->{album_gain});
		
		print encode("utf8",$str);
	    }
	    
            $add_replay_gain = 0;
        }
    },
    );


find(\%options,$music_lib);


sub getMaxLength {
    my ($string, $max) = @_;
    my $length = length(decode("utf8",$string));
    return ($length > $max) ? $length : $max;
}

# print Dumper(\%replayGain_added);



__END__

    =head1 NAME

    addReplayGain.pl - Describe the usage of script briefly

    =head1 SYNOPSIS

    addReplayGain.pl [options] args

    -opt --long      Option description

    =head1 DESCRIPTION

    Stub documentation for addReplayGain.pl, 

    =head1 AUTHOR

    titus, E<lt>titus@titus-laptopE<gt>

    =head1 COPYRIGHT AND LICENSE

    Copyright (C) 2011 by titus

    This program is free software; you can redistribute it and/or modify
    it under the same terms as Perl itself, either Perl version 5.8.2 or,
    at your option, any later version of Perl 5 you may have available.

    =head1 BUGS

    None reported... yet.

    =cut
