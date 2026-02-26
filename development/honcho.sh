#!/bin/bash

# DFP: Run all services within Procfile except `web` (we use debugger for that :)
honcho start socketio watch worker schedule worker

