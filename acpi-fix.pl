#!/usr/bin/perl

use strict;
use v5.10;
use warnings;

foreach my $file (glob("/sys/firmware/acpi/interrupts/*")) {
  say "opening $file ...";
  next unless open(my $f, '<', $file);
  say "opened $file..." ;
}
