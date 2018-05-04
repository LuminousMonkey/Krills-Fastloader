#!/usr/bin/env perl

=head1 NAME

compressedfileconverter.pl

=head1 DESCRIPTION

This script converts files compressed by ByteBoozer, Doynax-LZ and Taboo LevelCrush
so they can be loaded and decompressed in-place, on the fly.

=head1 SYNOPSIS

  compressedfileconverter.pl [bb|dnx|lc] compressed_infile uncompressed_infile outfile

=cut

use strict;
use warnings;


my %types = (
    ''    => 0,
    'bb'  => 1,
    'dnx' => 2,
    'lc'  => 3
);

my $type = '';
if (scalar @ARGV == 4) {
    $type = shift @ARGV;
}

if (!($type ~~ %types) or (scalar @ARGV != 3)) {
   die "Usage: $0 [bb|dnx|lc] compressed_infile uncompressed_infile outfile\n";
}

my $uncompressed_infile = shift @ARGV;
my $compressed_infile   = shift @ARGV;
my $converted_outfile   = shift @ARGV;


open UNCOMPRESSED, $uncompressed_infile
    or die "\nCan't open uncompressed file $uncompressed_infile for reading: $!\n";
binmode UNCOMPRESSED;

my $uncompressed_address;
read(UNCOMPRESSED, $uncompressed_address, 2);
my $uncompressed_data;
my $uncompressed_size = read(UNCOMPRESSED, $uncompressed_data, 65536);
$uncompressed_address = unpack("S", $uncompressed_address);
close UNCOMPRESSED;


open COMPRESSED, $compressed_infile
    or die "\nCan't open compressed file $compressed_infile for reading: $!\n";
binmode COMPRESSED;

if ($type eq 'bb') {
    # remove packed data loading address
    my $compressed_address;
    read(COMPRESSED, $compressed_address, 2);
}
my $compressed_data;
my $compressed_size = read(COMPRESSED, $compressed_data, 65536);
close COMPRESSED;


open CONVERTED, ">$converted_outfile"
    or die "\nCan't open converted file $converted_outfile for writing: $!\n";
binmode CONVERTED;

my $offset = ($type eq 'dnx') ? 2 : 0; # prepend unpacked address for Doynax-LZ
my $safety_margin = ($type eq 'dnx') ? 1 : 3;
$compressed_size += $offset;
my $converted_address = $uncompressed_address + $uncompressed_size + $safety_margin - $compressed_size;


$converted_address = pack("S", $converted_address);
print CONVERTED $converted_address;
if ($offset) {
    $uncompressed_address = pack("S", $uncompressed_address);
    print CONVERTED $uncompressed_address;
}
print CONVERTED $compressed_data;
close CONVERTED;

exit 0;
