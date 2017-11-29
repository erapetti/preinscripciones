#!/usr/bin/perl
#
# comparo_gpt.pl


open(GPT,"gpt_20171120.csv");

while(<GPT>) {
	next if (/^ORDENXDEP/);
	chop();
	@_ = split(',');

	next if ($_[3] =~ /^4/);

	$grupos_rf{$_[1]} += $_[5]+$_[6]+$_[7]+$_[8]+$_[9]+$_[10]+$_[11]+$_[12];
	$cupos_rf{$_[1]} += 30*$_[5] + 25*($_[6]+$_[7]+$_[8]+$_[9]+$_[10]+$_[11]+$_[12]);
}
close(GPT);


open(CUPOS,"cupos.csv");

while(<CUPOS>) {
	next if (/^#/);
	chop();
	@_ = split('\t');

	$grupos_dist{$_[0]} += $_[2];
}
close(CUPOS);

foreach my $dependid (sort {$a <=> $b} keys %grupos_rf)  {
	if ($grupos_rf{$dependid} != $grupos_dist{$dependid}) {
		printf STDERR "%4.4s: diferencia en cantidad de grupos, tiene %s en la distribución y %s en planilla de GruposPorTurno con apg=%g\n",$dependid,$grupos_dist{$dependid}+0,$grupos_rf{$dependid},$cupos_rf{$dependid}/$grupos_rf{$dependid};
	}
}

print "#DEPENDID\tAPG\tGRUPOS\n";
foreach my $dependid (sort {$a <=> $b} keys %grupos_rf)  {

	if ($grupos_rf{$dependid} == 0) {
		print STDERR "ERROR: La dependencia $dependid no tiene grupos\n";
		exit (1);
	}

	printf "%s\t%.4g\t%d\n", $dependid,$cupos_rf{$dependid}/$grupos_rf{$dependid},$grupos_rf{$dependid};
}

exit(0);

sub round {
  int( int($_[0]*10 + .5)/10 );
}
