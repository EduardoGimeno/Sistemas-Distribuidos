#!/bin/bash

conexion=0

while [ "$conexion" -eq 0 ]
do
	echo "IPs de las maquinas del laboratorio 1.02"
	echo "========================================"
	echo "            155.210.154.191             "
	echo "            155.210.154.192             "
	echo "            155.210.154.193             "
	echo "            155.210.154.194             "
	echo "            155.210.154.195             "
	echo "            155.210.154.196             "
	echo "            155.210.154.197             "
	echo "            155.210.154.198             "
	echo "            155.210.154.199             "
	echo "            155.210.154.200             "
	echo "            155.210.154.201             "
	echo "            155.210.154.202             "
	echo "            155.210.154.203             "
	echo "            155.210.154.204             "
	echo "            155.210.154.205             "
	echo "            155.210.154.206             "
	echo "            155.210.154.207             "
	echo "            155.210.154.208             "
	echo "            155.210.154.209             "
	echo "            155.210.154.210             "
	echo ""
	
	echo -n "Introduzca una IP de la lista: "
	read ip
	echo ""

	echo "Testeo de conexion"
	echo "=================="
	ssh a721615@"$ip" exit
	if [ "$?" -ne 0 ]
	then
    		echo "$ip no es accesible"
    		echo "Intentelo de nuevo"
	else
		echo "¡Exito!"
		conexion=1
	fi 
done

echo ""
echo "Configuracion de la maquina"
echo "==========================="

echo -n "Introduzca el nombre del nodo: "
read nombre

echo -n "Introduzca el nombre de la cookie: "
read cookie

echo ""
echo -n "¿Lanzar mas maquinas? (y/n): "
read resp

if [ "$resp" = "y" ]
then
	gnome-terminal -e "./$0"
fi

ssh a721615@"$ip" iex --name "$nombre"@"$ip" --cookie "$cookie"
