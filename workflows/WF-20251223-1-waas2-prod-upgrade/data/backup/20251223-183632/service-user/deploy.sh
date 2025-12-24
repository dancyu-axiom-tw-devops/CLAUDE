#!/bin/bash

kustomize build . | kubectl apply -f -



