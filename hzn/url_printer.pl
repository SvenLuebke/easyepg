#!/usr/bin/perl

#      Copyright (C) 2019-2020 Jan-Luca Neumann
#      https://github.com/sunsettrack4/easyepg
#
#      Collaborators:
#      - DeBaschdi ( https://github.com/DeBaschdi )
#
#  This Program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3, or (at your option)
#  any later version.
#
#  This Program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with easyepg. If not, see <http://www.gnu.org/licenses/>.

# ##############################
# HORIZON MANIFEST URL PRINTER #
# ##############################

use strict;
use warnings;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use utf8;

use JSON;
use Time::Piece;
use Time::Seconds;

my $pathMANI = '/tmp/mani';

# READ CHANNEL FILE
my $channels;
{
	local $/; #Enable 'slurp' mode
	open my $fh, '<', "/tmp/compare.json" or die;
	$channels = <$fh>;
	close $fh;
}

# READ SETTINGS FILE
my $settings;
{
	local $/; #Enable 'slurp' mode
    open my $fh, '<', "settings.json" or die;
    $settings = <$fh>;
    close $fh;
}

# READ Config FILE
my $config;
{
	local $/; #Enable 'slurp' mode
    open my $fh, '<', "config.json" or die;
    $config = <$fh>;
    close $fh;
}

# CONVERT JSON TO PERL STRUCTURES
my $channels_data  = decode_json($channels);
my $settings_data  = decode_json($settings);
my $config_data  = decode_json($config);

# SET DAY SETTING
my $day_setting  = $settings_data->{'settings'}{'day'};

# SET DATE VALUES
my @time   = (Time::Piece->new);
push (@time, $time[0] - 3600);
push (@time, $time[1] + 3600*24*$day_setting);

my $date_start = $time[1]->strftime('%s') . "000";
my $date_end   = $time[2]->strftime('%s') . "000";


# DEFINE COMPARE DATA
my $new_name2id = $channels_data->{'newname2id'};
my $new_id2name = $channels_data->{'newid2name'};
my $old_name2id = $channels_data->{'oldname2id'};
my $old_id2name = $channels_data->{'oldid2name'};
my @configname  = @{ $channels_data->{'config'} };


#
# DOWNLOAD CHANNEL MANIFESTS
#

foreach my $configname ( @configname ) {

	# DEFINE IDs
	my $new_id = $new_name2id->{$configname};
	my $old_id = $old_name2id->{$configname};

	# FIND CHANNEL NAME IN NEW CHANNEL LIST
	if( defined $new_id ) {

		if( $new_id ne $old_id) {
			print STDERR "[ CHLIST WARNING ] CHANNEL \"$configname\" received new channel ID!\n";
		}


		print "curl -s '$config_data->{'ProviderURL'}/listings?byStationId=" . $new_id . "&byStartTime=" . $date_start . "~" . $date_end . "&sort=startTime&range=1-10000' | grep \"$new_id\" > $pathMANI/$new_id\n";

	# IF CHANNEL NAME WAS NOT FOUND IN NEW CHANNEL LIST: TRY TO FIND OLD ID IN NEW CHANNEL LIST
	} elsif( defined $old_id ) {

		if( defined $new_id2name->{$old_id} ) {
			my $renamed_channel = $new_id2name->{$old_id};

			if( defined $old_name2id->{$renamed_channel} ) {
				print STDERR "[ CHLIST WARNING ] Renamed CHANNEL \"$renamed_channel\" (formerly known as \"$configname\") already exists in original channel list!\n";
			} elsif( not defined $old_name2id->{$renamed_channel} ) {
				print STDERR "[ CHLIST WARNING ] CHANNEL \"$configname\" received new channel name \"$renamed_channel\"!\n";

				my $renew_id = $new_name2id->{$renamed_channel};

				print "curl -s '$config_data->{'ProviderURL'}/listings?byStationId=" . $renew_id . "&byStartTime=" . $date_start . "~" . $date_end . "&sort=startTime&range=1-10000' | grep \"$renew_id\" > $pathMANI/$renew_id\n";

			}

		# IF OLD ID WAS NOT FOUND IN NEW CHANNEL LIST
		} else {
			print STDERR "[ CHLIST WARNING ] CHANNEL \"$configname\" not found in new channel list!\n";
		}

	# IF CHANNEL WAS NOT FOUND IN ANY CHANNEL LIST
	} else {
		print STDERR "[ CHLIST WARNING ] CHANNEL \"$configname\" not found in channel list!\n";
	}
}
