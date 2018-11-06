#!/usr/bin/perl
#
# distribucion.pl

use strict;
use warnings;
use POSIX qw(ceil);
use List::Util qw/reduce/;
use Encode qw/encode decode/;
use utf8;
use opcion;
use centros;
use alumnos;

sub clasificacion($$$$$$$$) ;
sub ordenamiento($$$$$) ;
sub puedomover($$$$) ;
sub liberar($$$$$) ;
sub ucutf8($) ;
sub descripcion_distribucion($$$) ;
sub mejora($) ;
sub salvar($$) ;


$::mostrar_solucion=1;
$::debug=0;
$::soloCES=0;
while ($#ARGV > -1) {
	if ($ARGV[0] eq '-d') {
		$::debug++;
	} elsif ($ARGV[0] eq '--CES') {
		$::soloCES=1;
	} else {
		print "ERROR: uso: distribucion.pl [-d] [-d] [--CES]\n";
		exit(1);
	}
	shift;
}

binmode STDOUT, ':encoding(UTF-8)';

my $centros = new centros;
$centros->load_cupos("cupos.csv");
$centros->load_reserva("reserva.csv");
$centros->load_depto("depto.csv");
my $alumnos = new alumnos;
$alumnos->load_derivados_a_ces("derivados_a_ces.csv");
$alumnos->load_derivados_a_cetp("derivados_a_cetp.csv");
#$alumnos->load_vulnerabilidad("vulnerabilidad.csv");
$alumnos->load_alumnos("preins2019v3.csv");
$alumnos->load_alumnos("especialesv2.csv",99);
$alumnos->load_alumnos("noformalv2.csv",99);
$alumnos->verifico();

my $ci;
my %destino;
my %solucion;

# Asigno a todos la primer opción:
foreach $ci ($alumnos->alumnos) {
		$alumnos->asignar($ci,0);
		$centros->asignar($ci, $alumnos->opcion($ci,0)->dependid, $alumnos->alumno($ci));
}
%{$solucion{destino}} = %{$alumnos->{destino}};
$solucion{puntaje} = $centros->evaluar;
$solucion{nro} = 0;

print "Propuesta inicial #0: ".($solucion{puntaje}>-1 ? "puntaje ".sprintf("%.2f",$solucion{puntaje}) : "no es viable, tiene sobrecupos en ".$centros->sobrecupos." centros")."\n";

my $nrosolucion=0;

foreach my $opc (1..3) {
	last if ($solucion{puntaje} > -1); # tengo una solución válida

	# voy a probar una nueva solución moviendo alumnos a la opción $opc
	$nrosolucion++;

	my %visitados;

	while (1) {
		my @sobrecupos = $centros->sobrecupos();
		last if ($#sobrecupos < 0); # encontre una solución sin centros llenos

		# elijo el liceo con mayor sobrecupo
		my $dependid;
		for (my $i=0; $i<=$#sobrecupos; $i++) {
			$dependid=$sobrecupos[$i];
			last if (!defined($visitados{$dependid}));
		}
		last if (defined($visitados{$dependid})); # ya están todos visitados

		($::debug > 1) && print "Analizo la opción ".($opc < 3 ? $opc : "predeterminada")." de $dependid\n";

		my $cambiados = liberar($opc,$dependid,$alumnos,$centros,\%visitados);

		($::debug) && print "Pude sacar $cambiados alumnos de $dependid\n";

		$visitados{$dependid} = 1;
	}

	$solucion{puntaje} = $centros->evaluar;
	$solucion{nro} = $nrosolucion;
	print "Propuesta #$solucion{nro}: ".($solucion{puntaje}>-1 ? "puntaje ".sprintf("%.2f",$solucion{puntaje}) : "no es viable, tiene sobrecupos en ".$centros->sobrecupos." centros")."\n";
}
%{$solucion{destino}} = %{$alumnos->{destino}};

# Intercambio alumnos para mejorar la solución, no cambia el puntaje
mejora($alumnos);

print "Propuesta final #$solucion{nro}: ".($solucion{puntaje}>-1 ? "puntaje ".sprintf("%.2f",$solucion{puntaje}) : "no es viable, tiene sobrecupos en ".$centros->sobrecupos." centros")."\n";

descripcion_distribucion($solucion{nro},$alumnos,$centros);

salvar("salida.csv",$alumnos);

exit(0);

######################################################################


sub clasificacion($$$$$$$$) {
	my ($faltas15,$faltas16,$faltas17,$nota,$af,$afampe,$tus,$tus2) = @_;

	my $clasificacion = 0;
	($tus ne "No") and $clasificacion++;
	($tus2 ne "No") and $clasificacion++;
	return $clasificacion;
}


# Evalúa una opción. Los puntajes mayores se consideran más prioritarios para los cambios de centro
sub ordenamiento($$$$$) {
	my ($ci,$opc,$alumnos,$centros,$rvisitados) = @_;
	my $puntaje;

  return 0 if (!defined($alumnos->opcion($ci,$opc)));

  # Criterio primario: favorezco a los que tengan en primera opción un liceo vacío
	my $dependid_opc = $alumnos->opcion($ci,$opc)->dependid;
	if (!defined($centros->grupos($dependid_opc))) {
		print "ERROR: No encuentro la cantidad de grupos para el centro $dependid_opc al considerar la opción $opc del alumno $ci\n";
		exit(1);
	}
	if (!defined($centros->grupos($dependid_opc)) || $centros->grupos($dependid_opc)==0) {
		# Este liceo no tiene grupos habilitados
		# print "ATENCIÓN:ordenamiento: centro $dependid_opc no tiene cantidad de grupos y fue elegido por $ci\n";
		return 0;
	}
	my $apg_opc = (keys %{$centros->alumnos($dependid_opc)}) / $centros->grupos($dependid_opc);
	$puntaje = ($apg_opc - $centros->apg($dependid_opc)) ** 2; # distancia del apg máximo * 1000

	if ($opc<=2 && defined($alumnos->opcion($ci,$opc+1))) {
		# tiene una opción propia más para considerar
		# Criterio secundario: desfavorezco a los que tengan segunda opción en un liceo vacío
		my $dependid_siguiente = $alumnos->opcion($ci,$opc+1)->dependid;
		if (! $rvisitados->{$dependid_siguiente} ) {
			if ($centros->libres($dependid_siguiente) > 0) {
				# hay lugar en el centro
				my $apg_siguiente = (keys %{$centros->alumnos($dependid_siguiente)}) / $centros->grupos($dependid_siguiente);
				$puntaje -= ($apg_siguiente - $centros->apg($dependid_siguiente)) ** 2; # distancia del apg máximo * -1
			}
		}
	}

	return $puntaje;
}

# Devuelve si puedo mover el alumno $ci desde el centro $dependid considerando sólo su opción $opc
sub puedomover($$$$) {
	my ($ci,$opc,$dependid,$alumnos) = @_;

	return 0 if ($alumnos->opcdestino($ci) >= $opc); # está en una opción peor a la que estoy considerando

	my $destino = $alumnos->destino($ci);
	return 0 if ($destino->dependid ne $dependid); # ya va a otro centro
	return 0 if ($destino->consejo eq 'Liceo' && $alumnos->vulnerable($ci)); # es vulnerable y está en un liceo

	my $predeterminada = $alumnos->predeterminada($ci);
	return 0 if (defined($predeterminada) && $predeterminada->dependid eq $destino->dependid); # no lo muevo si ya está en el centro predeterminado

	my $opcion = $alumnos->opcion($ci,$opc);
	return 0 if (!defined($opcion)); # no tiene la opcion opc

	($::soloCES) and return 0 if ($opcion->consejo ne 'Liceo');

	return 1;
}

sub liberar($$$$$) {
	my ($opc,$dependid,$alumnos,$centros,$rvisitados) = @_;

	my $cambiados = 0;
	my $sobrecupo = -($centros->libres($dependid));

	($::debug > 1) && print "Preciso liberar $sobrecupo lugares de $dependid\n";
	my %puedomover;
	foreach my $ci (keys %{$centros->alumnos($dependid)}) {
		next if (!puedomover($ci,$opc,$dependid,$alumnos));

		$puedomover{$ci} = 1;
	}
	if (! %puedomover) {
		($::debug > 1) && print "No puedo liberar lugares considerando la opción $opc\n";
		return 0;
	}
	($::debug > 1) && print " podría liberar hasta ".(keys %puedomover)." lugares en $dependid al mover a opc $opc\n";

	# ordeno y muevo primero a los que van a centros más libres
	while (%puedomover) {
		# elijo la ci que tiene mayor puntaje en ordenamiento()
		my $ci = (sort {ordenamiento($b,$opc,$alumnos,$centros,$rvisitados) <=> ordenamiento($a,$opc,$alumnos,$centros,$rvisitados)} keys %puedomover)[0];
		delete $puedomover{$ci};

		next if ($rvisitados->{ $alumnos->opcion($ci,$opc)->dependid }); # nunca muevo a centros ya visitados

		($::debug > 1) && print " saco a $ci porque puede ir a ".$alumnos->opcion($ci,$opc)->dependid."\n";

		$centros->mover($ci, $alumnos->destino($ci)->dependid, $alumnos->opcion($ci,$opc)->dependid);
		$alumnos->asignar($ci, $opc);
		$sobrecupo--;
		$cambiados++;
		last if ($sobrecupo<=0);
	}

	($::debug > 1) && print "Termina luego de liberar $dependid. Queda con sobrecupo de $sobrecupo\n";

	return $cambiados;
}

sub ucutf8($) {
	my ($texto) = @_;

	$texto = uc($texto);
	$texto =~ tr/áéíóúüñ/ÁÉÍÓÚÚÑ/;

	return $texto;
}

sub descripcion_distribucion($$$) {
	my ($nrosolucion,$alumnos,$centros) = @_;

	print "\nDescripción de la solución:\n\n";

	print "Los centros que están llenos en la solución #".$nrosolucion." son:\n";
	foreach my $dependid (sort {$centros->libres($a) <=> $centros->libres($b)} $centros->sobrecupos) {
		print "\tcentro $dependid: ".$centros->libres($dependid)." lugares libres\n";
	}
	print "\n";

	print "Los centros que están más vacíos en la solución #".$nrosolucion." son:\n";
	foreach my $dependid (sort {$centros->libres($b) <=> $centros->libres($a)} $centros->centros) {
		last if ($centros->libres($dependid) < 30);
		print "\tcentro $dependid: ".$centros->libres($dependid)." lugares libres\n";
	}
	print "\n";

	print "Cantidad de alumnos por opción:\n";
	my %opcion = (0=>0, 1=>0, 2=>0, 3=>0);
	my $predeterminados=0;
	my $enCES=0;
	foreach my $ci ($alumnos->alumnos) {
		$opcion{ $alumnos->opcdestino($ci) }++;
		if (defined($alumnos->predeterminada($ci)) && $alumnos->destino($ci)->consejo eq 'Liceo') {
			$enCES++; # tiene opción predeterminada y la opción destino es CES
			($alumnos->destino($ci)->dependid eq $alumnos->predeterminada($ci)->dependid) and $predeterminados++;
		}
	}
	printf "\tAlumnos en su opción inicial: %d\n",($opcion{0}+0);
	printf "\tAlumnos en su segunda opción: %d\n",($opcion{1}+0);
	printf "\tAlumnos en su tercer opción:  %d\n",($opcion{2}+0);
	printf "\tAlumnos en su opción predet:  %d\n",($opcion{3}+0);
	print "\n";
	($enCES) and print "\tAlumnos que quedaron en una opción igual a la predeterminada: $predeterminados de $enCES en CES = ".sprintf("%.2f %%",$predeterminados*100/$enCES)."\n";
	printf "\tSatisfacción general: %.2f %%\n",(($opcion{0}+$opcion{1}/2+$opcion{2}/4)*100/($opcion{0}+$opcion{1}+$opcion{2}+$opcion{3}));
	print "\n\n";

	print "Totales de la distribución:\n";
	printf "\tGrupos:  %d\n", reduce {$a+$b} map {$centros->grupos($_)} $centros->centros;
	printf "\tCupos:   %d\n", reduce {$a+$b} map {$centros->cupos($_)} $centros->centros;
	printf "\tAlumnos: %d\n", reduce {$a+$b} map {scalar(keys %{$centros->alumnos($_)})} $centros->centros;
	printf "\tReserva: %d\n", reduce {$a+$b} map {$centros->reserva($_)} $centros->centros;
	printf "\tSaldo:   %d\n", reduce {$a+$b} map {$centros->libres($_)} $centros->centros;
	print "\n\n";

	# Tabla que describe la solución por centro
	open(RESUMEN,">resumen.csv");
	printf "%15.15s %3.3s %20.20s %10.10s %10.10s %10.10s %10.10s %10.10s %10.10s %10.10s\n", "Departamento","#","Centro","Grupos","Lugares","CEIP","Especiales","NoFormal","Reserva","Saldo";
	printf RESUMEN "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n", "Departamento","#","Centro","Grupos","Lugares","CEIP","Especiales","NoFormal","Reserva","Saldo";
	foreach my $dependid (sort {$centros->depend2number($a) <=> $centros->depend2number($b)} $centros->centros) {
		($::soloCES) and next if ($dependid =~ /-.*-/);

		printf "%15.15s %3d %20.20s %10d %10d %10d %10d %10d %10d %10d\n",$centros->depto($dependid),$nrosolucion,$dependid,$centros->grupos($dependid),$centros->cupos($dependid),$centros->tag($dependid,"pre"),$centros->tag($dependid,"esp"),$centros->tag($dependid,"nof"),$centros->reserva($dependid),$centros->libres($dependid);
		printf RESUMEN "%s,%d,%s,%d,%d,%d,%d,%d,%d,%d\n",$centros->depto($dependid),$nrosolucion,$dependid,$centros->grupos($dependid),$centros->cupos($dependid),$centros->tag($dependid,"pre"),$centros->tag($dependid,"esp"),$centros->tag($dependid,"nof"),$centros->reserva($dependid),$centros->libres($dependid);
	}
	print "\n";
	close(RESUMEN);

	if ($::mostrar_solucion) {
		# Reporto alumnos para cada centro lleno:
		open(SALIDA,">paraCETP.csv");
		printf SALIDA "%s,%s,%s,%s\n", "Dependid","Documento","Tipo","País";
		foreach my $dependid_llena (sort {$centros->libres($a) <=> $centros->libres($a)} $centros->sobrecupos) {
			foreach my $ci ($alumnos->alumnos) {
				my $dependid = $alumnos->destino($ci)->dependid;
				next if ($dependid_llena ne $dependid);
				my $opc2 = $alumnos->opcion($ci,1);
				my $opc3 = $alumnos->opcion($ci,2);
				#next unless ($opc2 && $opc2->consejo eq 'UTU' || $opc3 && $opc3->consejo eq 'UTU');
				printf SALIDA "%s,%s,%s,%s\n", $alumnos->destino($ci)->dependid,$ci,$alumnos->tipodoc($ci),$alumnos->paisdoc($ci);
			}
		}
		close(SALIDA);
	}
}

# Mejora de la solución intercambiando alumnos
sub mejora($) {
	my ($alumnos) = @_;
	my $cambios = 0;

	# para alumnos que tienen el mismo liceo en más de una opción me aseguro que están en la mejor de las dos
	foreach my $ci ($alumnos->alumnos) {
		my $opc = $alumnos->opcdestino($ci);

		foreach (my $o=0; $o<$opc; $o++) {
			next if (!defined($alumnos->opcion($ci,$o)));
			if ($alumnos->opcion($ci,$o)->dependid eq $alumnos->destino($ci)->dependid) {
				$alumnos->asignar($ci, $o);
				$cambios++;
				($::debug) and print "MEJORA INDIVIDUAL: $ci pasa de opción $opc a opción $o manteniendo el liceo\n";
			}
		}
	}

	foreach my $opc (3,2,1) {
		print "Considero mejoras de alumnos en opc $opc\n";
		foreach my $ci ($alumnos->alumnos) {
			next if ($alumnos->opcdestino($ci) ne $opc);

			my $encontre = 0;

			my $liceo = $alumnos->destino($ci)->dependid;
			foreach (my $o=0; $o<$opc; $o++) {
				next if (!defined($alumnos->opcion($ci,$o)));
				my $mejor_liceo = $alumnos->opcion($ci,$o)->dependid;

				# recorro los alumnos de los liceos que son mejores para el alumno que quiero mejorar
				foreach my $otro_ci (keys %{$centros->alumnos($mejor_liceo)}) {
					for (my $otro_opc=0; $otro_opc<$alumnos->opcdestino($otro_ci); $otro_opc++) {
						next if (!defined($alumnos->opcion($otro_ci,$otro_opc)));
						next if ($alumnos->opcion($otro_ci,$otro_opc)->dependid ne $liceo);
						($::debug) and print "MEJORA: intercambio alumnos:\n";
						($::debug) and print "\t$ci (que pasa de centro ".$alumnos->destino($ci)->dependid." en opc ".$alumnos->opcdestino($ci)." a ".$alumnos->opcion($ci, $o)->dependid." en opc ".$o.")\n";
						($::debug) and print "\t$otro_ci (que pasa de centro ".$alumnos->destino($otro_ci)->dependid." en opc ".$alumnos->opcdestino($otro_ci)." a ".$alumnos->opcion($otro_ci, $otro_opc)->dependid." en opc $otro_opc)\n";
						$centros->mover($otro_ci, $alumnos->destino($otro_ci)->dependid, $alumnos->opcion($otro_ci,$otro_opc)->dependid);
						$alumnos->asignar($otro_ci, $otro_opc);
						$centros->mover($ci, $alumnos->destino($ci)->dependid, $alumnos->opcion($ci,$o)->dependid);
						$alumnos->asignar($ci, $o);
						$cambios += 2;
						$encontre = 1;
						last;
					}
					last if ($encontre);
				}
				last if ($encontre);
			}
		}
	}
	print "Se mejoró el centro de ".$cambios." alumnos manteniendo los cupos totales\n";
}

sub salvar_para_cetp($$) {
	my ($filename,$alumnos) = @_;

	open(SALIDA,">:utf8","$filename") || die "No se puede abrir $filename: $!";
	printf SALIDA "%s,%s\n", "Cédula","Dependid";
	foreach my $ci ($alumnos->alumnos) {
		if ($centros->libres( $alumnos->destino($ci)->dependid ) < -9) {
			my $opc2 = $alumnos->opcion($ci,2);
			my $opc3 = $alumnos->opcion($ci,3);
			if (! defined($opc2) || !defined($opc3)) {
				printf SALIDA "%s,%s\n", $ci,$alumnos->destino($ci)->dependid;
			}
		}
	}
	close(SALIDA);
}

sub salvar($$) {
	my ($filename,$alumnos) = @_;

	open(SALIDA,">:utf8","$filename") || die "No se puede abrir $filename: $!";
	printf SALIDA "%s,%s,%s,%s\n", "Documento","Tipo","País","Dependid";
	foreach my $ci ($alumnos->alumnos) {
		if ($alumnos->destino($ci)->consejo eq 'Liceo') {
			printf SALIDA "\"%s\",\"%s\",\"%s\",%s\n", $ci,$alumnos->tipodoc($ci),$alumnos->paisdoc($ci),$alumnos->destino($ci)->dependid;
		}
	}
	close(SALIDA);
}
