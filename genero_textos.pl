#!/usr/bin/perl
#
# genero_textos.pl


use strict;

#############################
## cupos de los liceos
##

my %cupos;
open(CUPOS,"cupos.csv");
while(<CUPOS>) {
	next if (/^#/);
	next if (/^\s*$/);
	if (/,/) {
		print "load_cupos: Se encontraron comas en el archivo cupos.csv y las cifras decimales hay que separarlas por puntos\n";
		exit(1);
	}

	s/"//g;
	chop();
	@_ = split('\t');

	if (!defined($cupos{$_[0]})) {
		# primera vez que aparece este centro en el archivo
		$cupos{$_[0]} = {apg=>$_[1], grupos=>$_[2], cupo=>$_[1]*$_[2], reserva=>0, total=>$_[1]*$_[2]};
	} elsif ($_[2] > 0) {
		# acumulo los valores con lo que ya tenía
		$cupos{$_[0]}{grupos} += $_[2];
		$cupos{$_[0]}{cupo} += $_[1]*$_[2];
		$cupos{$_[0]}{apg} = $cupos{$_[0]}{cupo} / $cupos{$_[0]}{grupos};
		$cupos{$_[0]}{reserva} = 0; # nop
		$cupos{$_[0]}{total}  = $cupos{$_[0]}{cupo} - 0;
	}
}
close(CUPOS);

# redondeo los decimales
foreach $_ (keys %cupos) {
	$cupos{$_}{cupo} = int($cupos{$_}{cupo});
}


#############################
## direcciones de los liceos
##

my %direcciones;
open(DIRECCIONES,"direcciones.csv");
while(<DIRECCIONES>) {
	chop();
	s/  +/ /g;
	s/ ?, ?/,/g;
	s/ $//;
	@_ = split(',');

	$direcciones{$_[0]} = {DeptoId=>$_[1],DeptoNombre=>$_[2],LugarId=>$_[3],LugarDesc=>$_[4],LocId=>$_[5],LocNombre=>$_[6],LugarDireccion=>$_[7],DependDesc=>$_[8]};
}
close(DIRECCIONES);


#############################
## turnos de los liceos
##

my %turnos;
open(GPT,"gpt_20171120.csv");
while(<GPT>) {
	next if (/^DEPENDID/);
	chop();
	@_ = split(',');

	$_[3] =~ s/E//;

	$turnos{$_[1]}{$_[3]} = 1;
}
close(GPT);

#############################
## resultado de la distribución
##

my %destino;
my %alumnos;
open(DIST,"distribucionCCDD.csv");
while(<DIST>) {
	next if (/^Documento/);
	chop();
	@_ = split(',');


	$destino{$_[0]} = $_[1];

	$_[1] =~ s/-49$//;
	
	$alumnos{$_[1]}{$_[0]} = 1;
}
close(DIST);

# planes: día turno/alt frecuencia horario
my @planes = (
	{ dia => 12, 2 => {desde => '14:00', hasta => '17:45', frecuencia=>2},
	           alt => {desde => '10:00', hasta => '11:45', frecuencia=>2} },
	{ dia => 13, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
	{ dia => 14, 2 => {desde => '16:00', hasta => '17:45', frecuencia=>3},
	           alt => {desde => '10:00', hasta => '11:45', frecuencia=>3} },
	{ dia => 15, 2 => {desde => '16:00', hasta => '17:45', frecuencia=>3},
	           alt => {desde => '10:00', hasta => '11:45', frecuencia=>3} },
	{ dia => 18, 2 => {desde => '16:00', hasta => '17:45', frecuencia=>3},
	           alt => {desde => '10:00', hasta => '11:45', frecuencia=>3} },
	{ dia => 19, 2 => {desde => '16:00', hasta => '17:45', frecuencia=>3},
	           alt => {desde => '10:00', hasta => '11:45', frecuencia=>3} },
	{ dia => 20, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
	{ dia => 21, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
	{ dia => 22, 1 => {desde => '08:00', hasta => '11:45', frecuencia=>3},
	             2 => {desde => '14:00', hasta => '17:45', frecuencia=>3} },
);


my %horarios;
foreach my $dependid (sort {$a <=> $b} keys %alumnos) {

	if (!defined($cupos{$dependid}) || !defined($cupos{$dependid}{grupos})) {
		print STDERR "ERROR: El liceo $dependid no tiene cupos\n";
		exit(1);
	}

	my $alumnos = scalar(keys %{$alumnos{$dependid}});
	print STDERR "$dependid: ".$alumnos." grupos=".$cupos{$dependid}{grupos}." apg=".int($alumnos/$cupos{$dependid}{grupos})."\n";

	if (!defined($turnos{$dependid}{1})) {
		print STDERR "$dependid no tiene turno 1\n";
	}
	if (!defined($turnos{$dependid}{2})) {
		print STDERR "$dependid no tiene turno 2\n";
	}

	my @alumnos = keys $alumnos{$dependid};

	for my $plan (@planes) {
		last if ($#alumnos < 0);

		my $dia = $plan->{dia};
		my $encontre_turno = 0;

		foreach my $turnobase (1,2,'alt') {
			my $turno = $turnobase;
			last if ($#alumnos < 0);
			next if (!defined($plan->{$turno}));
			next if (!defined($turnos{$dependid}{$turno}) && !(!$encontre_turno && $turno eq 'alt'));

			$encontre_turno = defined($turnos{$dependid}{$turno});

			$plan->{$turno}{desde} =~ /(\d\d):(\d\d)/;
			my $hora = $1;
			my $minuto = $2;
			my $puesto = 1;
			(defined($horarios{$dependid}{$dia}{desde})) or $horarios{$dependid}{$dia}{desde} = sprintf "%02d:%02d",$hora,$minuto;
			$horarios{$dependid}{$dia}{$turno}{frecuencia} += $plan->{$turno}{frecuencia};

			while (my $cedula = shift @alumnos) {

				($horarios{$dependid}{$dia}{hasta} > sprintf "%02d:%02d",$hora,$minuto) or $horarios{$dependid}{$dia}{hasta} = sprintf "%02d:%02d",$hora,$minuto;

				if ($dependid>1000 && $dependid<1100) {
					# MONTEVIDEO
					printf "%s,%sPara la inscripción 2018 debe ir al Liceo Nº %2d (%s) el %d de diciembre a las %02d:%02d llevando:\n- Cédula de Identidad y Carné de Salud Adolescente del alumno\n- Cédula del adulto responsable de la inscripción\n\nConsejo de Educación Secundaria%s\n",$cedula,'"',$dependid%100,$direcciones{$dependid}{LugarDireccion},$dia,$hora,$minuto,'"';
				} elsif ($dependid>200 && $dependid<300 || $dependid>900 && $dependid<1000) {
					# CANELONES Y MALDONADO
					printf "%s,%sPara la inscripción 2018 debe ir al Liceo de %s (%s) el %d de diciembre en el turno de la %s llevando:\n- Cédula de Identidad y Carné de Salud Adolescente del alumno\n- Cédula del adulto responsable de la inscripción\n\nConsejo de Educación Secundaria%s\n",$cedula,'"',$direcciones{$dependid}{DependDesc},$direcciones{$dependid}{LugarDireccion},$dia,($hora<13 ? "mañana" : "tarde"),'"';
				} else {
					# INTERIOR
					printf "%s,%sPara la inscripción 2018 debe ir al Liceo de %s (%s) llevando:\n- Cédula de Identidad y Carné de Salud Adolescente del alumno\n- Cédula del adulto responsable de la inscripción\n\nConsejo de Educación Secundaria%s\n",$cedula,'"',$direcciones{$dependid}{DependDesc},$direcciones{$dependid}{LugarDireccion},'"';
				}

				$puesto ++;
				if ($puesto > $plan->{$turno}{frecuencia}) {
					$puesto = 1;
					$minuto += 15;
					if ($minuto == 60) {
						$minuto = 0;
						$hora ++;
					}
					last if ($plan->{$turno}{hasta} lt sprintf "%02d:%02d",$hora,$minuto);
				}
			}
		}
	}
}

foreach my $dependid (sort {$a <=> $b} keys %horarios) {
	foreach my $dia (sort {$a <=> $b} keys %{$horarios{$dependid}}) {
		printf STDERR "%d\t%s\t%s",$dependid,$direcciones{$dependid}{DeptoNombre},$direcciones{$dependid}{DependDesc};
		printf STDERR "\t%s","$dia/12 desde $horarios{$dependid}{$dia}{desde} hasta $horarios{$dependid}{$dia}{hasta} con ".max(max($horarios{$dependid}{$dia}{1}{frecuencia},$horarios{$dependid}{$dia}{2}{frecuencia}),$horarios{$dependid}{$dia}{alt}{frecuencia})." alumnos cada 15 minutos";
		print STDERR "\n";
	}
}
exit(0);

######################################################################


sub trim($) {
	my ($texto) = @_;

	$texto =~ s/^ +//;
	$texto =~ s/ +$//;

	return $texto;
}

sub max($$) {
	return ($_[0] >= $_[1] ? $_[0] : $_[1]);
}
