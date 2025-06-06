~include .env

.PHONY: all test deploy

build:; forge build

test:; forge test