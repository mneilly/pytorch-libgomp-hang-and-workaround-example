#!/usr/bin/env bash

/usr/sbin/nginx

# The following hangs in the huggingface feature_extractor when
# torch.tensor(value) is called to convert the numpy array for
# the image into a tensor. Things hand in libgomp.

# Fails
/usr/bin/uwsgi --ini /uwsgi.ini --uid www-data --enable-threads

# The following pytorch issue discussed the problem and workarounds:
# https://github.com/pytorch/pytorch/issues/50669

# Use LD_PRELOAD libiomp5 to avoid use of libgomp. I'm using
# libomp-dev-11 instead of libmkl-dev.

# Workaround
# LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libiomp5.so \
# 	  /usr/bin/uwsgi --ini /uwsgi.ini --uid www-data --enable-threads
