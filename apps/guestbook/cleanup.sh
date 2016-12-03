#!/bin/bash

kubectl delete deployments,services -l "app in (redis, guestbook)"
