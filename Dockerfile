FROM balenalib/raspberrypi3-alpine as build

RUN [ "cross-build-start" ]

RUN mkdir -p /src
WORKDIR /src

##
## Setup & Install Dependencies
##

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# Install dependencies
RUN apk add ffmpeg-dev git alpine-sdk libass-dev lame-dev pulseaudio-dev x264-dev

#
# Build FFMPEG
#
RUN git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg 

RUN apk add alsa-lib-dev

# Grab firmware /opt/vc files
RUN wget https://github.com/raspberrypi/firmware/archive/1.20200819.tar.gz && tar xzf 1.20200819.tar.gz && cp -rpf firmware-1.20200819/opt /

RUN cd ffmpeg \
    && mkdir build \
    && ./configure --prefix=/build --enable-libfreetype --enable-gpl --enable-libx264 --enable-libass \
                  --enable-libmp3lame --prefix=build --enable-omx --enable-omx-rpi --enable-libpulse --enable-indev=alsa --enable-outdev=alsa --extra-ldflags="-latomic" \
    && make -j4 && make install

RUN [ "cross-build-end" ]  

FROM balenalib/raspberrypi3-alpine

RUN [ "cross-build-start" ]

WORKDIR /beemon

# Install standard ffmpeg
RUN apk add ffmpeg libpulse raspberrypi

# Copy across new ffmpeg files
COPY --from=build /src/ffmpeg/build/ /usr/

#RUN chmod +x launcher.sh
#CMD ["./launcher.sh"]

RUN [ "cross-build-end" ]  
