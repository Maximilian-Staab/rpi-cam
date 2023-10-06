# RPi-Cam

A sample project for a recent python version working with libcamera support in docker.

## Build

This project required the `buildx` docker driver for different target platforms. 
You can either use `buildx` or build the image on a Raspberry PI. 
I recommend to use `buildx` if you don't want to wait hours for the build to complete.


#### Install qemu support

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

#### Build the image
```bash
 docker buildx build --progress=plain --platform=linux/arm/v7 --load -t rpi-cam -f Dockerfile .
```

#### Run the image you build yourself

```bash
docker run --rm --name rpi-cam -it rpi-cam
```

## Using the pre-build image

Take a look at the `docker-compose.yml` to see which devices/volumes are required for this container to work.
Then either run or work on something yourself:

```bash
docker compose up
```

If you don't want to use compose, you can always use this:
```bash
docker run --rm --name rpi-cam -it ghcr.io/maximilian-staab/rpi-cam:latest
```
