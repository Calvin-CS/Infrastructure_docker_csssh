#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace staging \
	csssh \
	./csssh \
	--set image.repository=calvincs.azurecr.io \
	--dry-run
