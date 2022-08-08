#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace production \
	csssh \
	./csssh \
	--dry-run
