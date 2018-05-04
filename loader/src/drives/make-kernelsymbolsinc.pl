#!/usr/bin/env perl
 
=head1 NAME
 
make-kernelsymbolsinc.pl
 
=head1 DESCRIPTION
 
This script extracts relevant symbols from a ld65-generated map file.
The resulting include file can be included in third-party assembly source code.
 
=head1 SYNOPSIS
 
  make-kernelsymbolsinc.pl drivecode1541.prg.map > kernelsymbols1541.inc
 
=cut
 
use strict;
use warnings;

use English qw( -no_match_vars ); # OS_ERROR etc.
 
 
main();
 
sub main
{
	my @input = read_file($ARGV[0]);
	my $symbols = extract_symbols(@input);
	my @names_sorted_by_address =
	    sort { $symbols->{$a} <=> $symbols->{$b} } keys %{$symbols};

	foreach my $name (@names_sorted_by_address) {
		print_symbol($name, $symbols->{$name});
	}

	return;
}
 
sub read_file
{
	my ($filename) = @ARG;
 
	open(my $fh, '<', $filename)
	    or die "cannot read file '$filename': $OS_ERROR";

	my @input = <$fh>;
	close $fh;

	return @input;
}
 
sub extract_symbols
{
	my @input = @ARG;
 
	my %symbols;
	my $current_list;
	foreach my $i (@input) {
 
		if ($i =~ qr{list.*?:}) {
			$current_list = $i;
		} elsif ($current_list =~ qr{Exports}) {
			if ( $i =~ qr{(\w+)\s+(\w+)\s+\w+\s+(\w+)\s+(\w+)} ) {
				# double-entry line
				$symbols{$1} = hex '0x' . $2;
				$symbols{$3} = hex '0x' . $4;
			} elsif ($i =~ qr{(\w+)\s+(\w+)\s+\w+}) {
				# single-entry line
				$symbols{$1} = hex '0x' . $2;
			}
		}
	}

	return \%symbols;
}
 
sub print_symbol
{
	my ($name, $address) = @ARG;
 
	my $address_length = ($address < 256) ? 2 : 4;
	my $printf_arg = '%-15s = $%.' . $address_length . "x\n";
	printf $printf_arg, $name, $address;

	return;
}
