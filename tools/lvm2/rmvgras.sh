#!/bin/bash

start=1
end=45

for i in $(seq $start $end)
do
	crm configure delete vg"$i"	
done

crm status
