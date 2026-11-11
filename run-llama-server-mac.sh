#!/usr/bin/env sh
exec /Users/maxim/projects/llama.cpp/build/bin/llama-server \
  --models-preset /Users/maxim/scripts/llama-models.ini \
  --host 0.0.0.0 \
  --port 1234
