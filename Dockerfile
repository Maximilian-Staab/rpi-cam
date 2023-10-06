FROM python:3.11-slim as base

ENV DEBIAN_FRONTEND="noninteractive" \
    # python envs
    PYTHONUNBUFFERED=1 \
    # prevents python creating .pyc files
    PYTHONDONTWRITEBYTECODE=1 \
    \
    # pip
    PIP_NO_CACHE_DIR=off \
    # PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    \
    # Fixes for cryptography builds
    CARGO_NET_GIT_FETCH_WITH_CLI=true \
    CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
    \
    # poetry
    # https://python-poetry.org/docs/configuration/#using-environment-variables
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    # make poetry create the virtual environment in the project's root
    # it gets named `.venv`
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    # do not ask any interactive question
    POETRY_NO_INTERACTION=1


RUN apt-get update && apt-get install --assume-yes --no-install-recommends  \
    build-essential  \
    cmake  \
    meson  \
    ninja-build  \
    qemu-user-static  \
    git \
    libssl-dev libffi-dev \
    python3-yaml python3-virtualenv python3-dev libpython3-dev python3-pkgconfig python3-pybind11 pybind11-dev  \
    python3-jinja2 python3-ply libcap-dev python3-cryptography libjpeg-dev libatlas-base-dev python3-numpy


# Use wheels whenever possible
RUN printf '[global]\nextra-index-url=https://www.piwheels.org/simple\n' > /etc/pip.conf

# These are required for building libcamera
RUN pip install PyYAML jinja2 ply

# Installed to give a similar experience to normal PIs
# rpi.gpio is only available on bookworm for now (oct. 2023)
# RUN apt-get install --assume-yes --no-install-recommends python3-rpi.gpio
RUN pip install RPi.GPIO

# Clone and build libcamera
RUN git clone https://github.com/raspberrypi/libcamera.git /libcamera

WORKDIR /libcamera
# one could either change `libdir` or add to the PYTHONPATH after `ninja -C build install`
RUN meson setup build --buildtype=release -Dpipelines=rpi/vc4 -Dipas=rpi/vc4 -Dv4l2=true -Dgstreamer=disabled -Dtest=false -Dlc-compliance=disabled -Dcam=disabled -Dqcam=disabled -Ddocumentation=disabled -Dpycamera=enabled -Dlibdir=lib
RUN ninja -C build install

# Clone and build kms++ (required by Picamera2)
RUN git clone https://github.com/tomba/kmsxx.git /kmsxx
WORKDIR /kmsxx
RUN #meson wrap install fmt
RUN apt-get install --assume-yes --no-install-recommends libdrm-dev libfmt-dev
RUN #meson wrap install libdrm-common libdrm2 libdrm-dev libdrm
RUN meson setup build --buildtype=release -Dpykms=enabled -Dlibdir=lib
RUN ninja -C build
# required for the python bindings
ENV PYTHONPATH=/kmsxx/build/py

# So libcamera.so.0.1 can be ound
RUN ldconfig

# Requirements for Picamera2
RUN apt-get install --assume-yes --no-install-recommends  \
    libtiff6  \
    libopenjp2-7 \
    libxcb1

# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:/root/.local/bin:$PATH"

# debian packaged version was too old for the new repository feature of poetry
RUN pip install poetry
RUN poetry --version

# NOTE: This only works when installing with pip: https://github.com/python-poetry/poetry/issues/6035
# Use system packages, so libcamera can be used
# RUN poetry config virtualenvs.options.system-site-packages true

# I had some issues with too many connections
RUN poetry config installer.max-workers 10

# Use system python
# Could be changed to a venv after futher tests.
# Previous tests had some issues with using libcamera in the venv, but that might be circumvented.
RUN poetry config virtualenvs.create false

RUN poetry config --list

WORKDIR /app

COPY pyproject.toml pyproject.toml
COPY rpi_cam rpi_cam
RUN poetry env info

# Done to avoid re-istalling already installed systme packages
# Locking inside the container due to different platform support
RUN poetry export --without-hashes --with dev -f requirements.txt -o requirements.txt
RUN pip install -r requirements.txt
# might interfere with already insalled packages
RUN #poetry install --no-interaction -vvv

CMD [ "poetry", "run", "rpi-cam"]
