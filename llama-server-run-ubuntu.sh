#!/usr/bin/env sh

exec /home/maxim/projects/llama.cpp/build/bin/llama-server --models-preset ~/.lmstudio/models.ini --host 0.0.0.0 --port 1234
