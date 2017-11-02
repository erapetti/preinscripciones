#!/usr/bin/perl
#
# distribucion.pl

use strict;
use POSIX qw(ceil);

$::FILE="preins2018v1.csv";

$::MAXINT=2**53;

my $DEPTO;

while($#ARGV>-1) {
	$DEPTO=uc(shift @ARGV);
}

if (! $DEPTO) {
	print "uso: distribucion.pl depto\n";
	exit(1);
}

my %alumnos = alumnos($::FILE,$DEPTO);

print "cant alumnos: ".keys(%alumnos)."\n";

my %cupos = cupos("cupos.csv");

my $ci;
my %destino;
my %solucion;

# Asigno a todos la primer opción:
foreach $ci (keys %alumnos) {

	$destino{$ci} = 0;
}
%{$solucion{destino}} = %destino;
$solucion{puntaje} = evaluar(0, \%alumnos, \%destino, \%cupos);
$solucion{nro} = 0;

print "Puntaje de la solución inicial: $solucion{puntaje}\n";

my $nrosolucion=0;
while($solucion{puntaje} == $::MAXINT) {
	$nrosolucion++;
	my ($liceo, $sobrecupo) = maslleno(\%alumnos,\%destino,\%cupos);
	liberar($liceo,$sobrecupo,\%alumnos,\%destino,\%cupos,\%solucion);
	$solucion{puntaje} = evaluar($nrosolucion, \%alumnos, \%destino, \%cupos);
	$solucion{nro} = $nrosolucion;
print "Puntaje de la solución #".$solucion{nro}.": $solucion{puntaje}\n";
}
%{$solucion{destino}} = %destino;

print "Puntaje de la mejor solución #".$solucion{nro}.": $solucion{puntaje}\n";

exit(0);

######################################################################

sub cupos($) {
	my ($file) = @_;

	my %cupos;

	open(CUPOS,$file);
	while(<CUPOS>) {
		s/"//g;
		chop();
		@_ = split('\t');
		$cupos{$_[0]} = {apg=>$_[1], grupos=>$_[2], total=>$_[1]*$_[2]};
	}
	close(CUPOS);

	return %cupos;
}

sub ruee($) {
	my ($nombre) = @_;

	($nombre eq "SIN INFORMACIÓN") && return undef;

	if (!defined($::ruee{nombre})) {
		# cargo los ruee desde el archivo
		open(FILE2,"$::FILE");
		while(<FILE2>) {
			s/"//g;
			chop();
			@_ = split('\t');
			$::ruee{nombre}{$_[32]} = $_[35];
			$::ruee{ruee}{$_[35]} = $_[32];
		}
		close(FILE2);
	}

	if (!defined($::ruee{nombre}{$nombre})) {
		print "ERROR: Liceo $nombre sin ruee\n";
		exit(1);
	}
	return $::ruee{nombre}{$nombre};
}

sub ruee2dependid($) {
	my ($ruee) = @_;

	return ($ruee eq "SIN INFORMACIÓN" ? undef : $ruee);
}

sub clasificacion($$$$$$$$) {
	my ($faltas15,$faltas16,$faltas17,$nota,$af,$afampe,$tus,$tus2) = @_;

	my $clasificacion = 0;
	($tus ne "No") and $clasificacion++;
	($tus2 ne "No") and $clasificacion++;
	return $clasificacion;
}

sub alumnos($$) {
	my ($file,$depto) = @_;

	my %alumnos;
	my %salteados;
	my $total_alumnos = 0;

	open(FILE,$file);
	while(<FILE>) {
		$total_alumnos++;
		s/"//g;
		chop();
		@_ = split('\t');

		if (uc($_[34]) ne $depto) {
			# opc1 es de otro departamento
			$salteados{'otro departamento en opc1'}++;
			next;
		}
		if ($_[23] ne "Si") {
			# no preinscribió
			$salteados{'no preinscribió'}++;
			next;
		}
		if ($_[33] ne 'Liceo') {
			# opc1 no es CES
			$salteados{'opc1 no es CES'}++;
			next;
		}
		if ($_[41] ne 'Liceo') {
			# opc2 no es CES, la dejo indefinida
			($_[40],$_[41],$_[42],$_[43]) = (undef,undef,undef,undef);
		}
		if ($_[47] ne 'Liceo') {
			# opc3 no es CES, la dejo indefinida
			($_[46],$_[47],$_[48],$_[49]) = (undef,undef,undef,undef);
		}
		if ($_[41] eq 'Liceo' && uc($_[34]) ne uc($_[42]) ||
		    $_[47] eq 'Liceo' && uc($_[34]) ne uc($_[48])) {
			print "Salteo a $_[18] porque tiene opciones en otro departamento\n";
			$salteados{'tiene opciones en otro departamento'}++;
			next;
		}

#		print "doc : ".$_[18]."\n";
#		print "prei: ".$_[23]."\n";
#		print "opc1: ".$_[32].", ".$_[33].", ".$_[34].", ".$_[35],"\n";
#		print "opc2: ".$_[40].", ".$_[41].", ".$_[42].", ".$_[43],"\n";
#		print "opc3: ".$_[46].", ".$_[47].", ".$_[48].", ".$_[49],"\n";
#		print "deft: ".$_[39]."\n";
#		print "fa15: ".$_[52]."\n";
#		print "fa16: ".$_[53]."\n";
#		print "fa17: ".$_[54]."\n";
#		print "nota: ".$_[55]."\n";
#		print "af  : ".$_[56]."\n";
#		print "afam: ".$_[57]."\n";
#		print "tus : ".$_[58]."\n";
#		print "tus2: ".$_[59]."\n";

		$alumnos{$_[18]} = [ ruee2dependid($_[35]), ruee2dependid($_[43]), ruee2dependid($_[49]), ruee($_[39]),
		                     clasificacion($_[52],$_[53],$_[54],$_[55],$_[56],$_[57],$_[58],$_[59]) ];
	}
	close(FILE);

	if (keys %salteados) {
		print "Cantidad de alumnos no procesados:\n";
		foreach $_ (sort {$salteados{$a} <=> $salteados{$b}} keys %salteados) {
			print "\t$_: $salteados{$_}\n";
		}
	}
	print "Total de alumnos: $total_alumnos\n";

	return %alumnos;
}

sub maslleno($$$) {
	my ($ralumnos,$rdestino,$rcupos) = @_;
	my ($peorliceo,$peorsobrecupo);

	# Cuento los alumnos por liceo:
	my %cant;
	foreach my $ci (keys %$rdestino) {
		my $liceo = $ralumnos->{$ci}[$rdestino->{$ci}];
		$cant{$liceo}++;
	}
	foreach my $liceo (keys %cant) {
		if ($rcupos->{$liceo}{total} < $cant{$liceo}) {
			# este liceo tiene sobrecupo
			if (!defined($peorsobrecupo) || $peorsobrecupo < $cant{$liceo}-$rcupos->{$liceo}{total}) {
				# este liceo es el que va teniendo más sobrecupo
				$peorliceo=$liceo;
				$peorsobrecupo=$cant{$liceo}-$rcupos->{$liceo}{total};
			}
		}
	}
	return ($peorliceo,$peorsobrecupo);
}

sub evaluar($$$$) {
	my ($nrosolucion,$ralumnos,$rdestino,$rcupos) = @_;

	my $puntaje = 0;


	# Cuento los alumnos por liceo:
	my %cant;
	foreach my $ci (keys %$rdestino) {
		my $liceo = $ralumnos->{$ci}[$rdestino->{$ci}];
		$cant{$liceo}++;
	}

	foreach my $liceo (keys %cant) {
		if (!defined($rcupos->{$liceo})) {
			print "ERROR: No está definido el cupo para la dependencia $liceo\n";
			exit(0);
		}
		if ($rcupos->{$liceo}{total} < $cant{$liceo}) {
#			print "INFO: Solución #".$nrosolucion.": Sobrecupo en $liceo: ".$cant{$liceo}." alumnos\n";
			return $::MAXINT; # no hay cupos suficientes
		}
		
#print "liceo $liceo saldo ".($rcupos->{$liceo}{total} - $cant{$liceo})." ";
		$puntaje += (($rcupos->{$liceo}{total} - $cant{$liceo}) / $rcupos->{$liceo}{grupos}) ** 2;
	}
#print " puntaje ".int($puntaje)."\n";

	return $puntaje;
}

sub liberar($$$$$$) {
	my ($liceo,$sobrecupo,$ralumnos,$rdestino,$rcupos,$rsolucion) = @_;

	# Cuento los alumnos por liceo:
	my %cant;
	foreach my $ci (keys %$rdestino) {
		my $liceo = $ralumnos->{$ci}[$rdestino->{$ci}];
		$cant{$liceo}++;
	}

print "Preciso liberar $sobrecupo lugares de $liceo\n";
	foreach my $opc (1..3) {
		my @puedomover;
		foreach my $ci (keys %$ralumnos) {
			next if ($rdestino->{$ci} >= $opc);
			next if ($ralumnos->{$ci}[$rdestino->{$ci}] ne $liceo); # va a otro liceo
			next if ($ralumnos->{$ci}[4]!=0); # es vulnerable
			next if (!defined($ralumnos->{$ci}[$opc])); # no tiene la opcion opc
			next if ($cant{$ralumnos->{$ci}[$opc]} >= $rcupos->{$ralumnos->{$ci}[$opc]}{total}); # el nuevo liceo está lleno

			push @puedomover, $ci;
		}
print " sobrecupo $sobrecupo, puedo liberar ".$#puedomover." lugares en $liceo al mover a opc $opc\n";
		if ($sobrecupo >= $#puedomover) {
			# los muevo a todos
			foreach my $ci (@puedomover) {
				$rdestino->{$ci} = $opc;
			}
			$sobrecupo-=$#puedomover;
		} else {
			# ordeno y muevo a los que van a liceos más libres
			foreach my $ci (sort {$cant{$ralumnos->{$a}[$opc]}/$rcupos->{$ralumnos->{$a}[$opc]}{grupos} <=> $cant{$ralumnos->{$b}[$opc]}/$rcupos->{$ralumnos->{$b}[$opc]}{grupos}} @puedomover) {

				next if ($cant{$ralumnos->{$ci}[$opc]} >= $rcupos->{$ralumnos->{$ci}[$opc]}{total});

print "saco a $ci porque puede ir a ".$ralumnos->{$ci}[$opc]." que tiene ".$cant{$ralumnos->{$ci}[$opc]}." alumnos y ".$rcupos->{$ralumnos->{$ci}[$opc]}{grupos}." grupos y apg ".$cant{$ralumnos->{$ci}[$opc]}/$rcupos->{$ralumnos->{$ci}[$opc]}{grupos}."\n";

				$cant{$ralumnos->{$ci}[$rdestino->{$ci}]}--;
				$rdestino->{$ci} = $opc;
				$cant{$ralumnos->{$ci}[$rdestino->{$ci}]}++;
				$sobrecupo--;
				last if ($sobrecupo<=0);
			}
		}
		last if ($sobrecupo<=0);
	}
print "Termina luego de liberar $liceo. Queda con sobrecupo de $sobrecupo\n";
}
