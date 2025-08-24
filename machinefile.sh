#!/bin/sh

machinefile --host ${SSH_HOST} --port ${SSH_PORT} --user root --password password ${TARGET}/Machinefile .
