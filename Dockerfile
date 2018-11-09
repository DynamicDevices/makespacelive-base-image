FROM resin/raspberrypi3-debian:stretch

RUN [ "cross-build-start" ]

# Install dependencies

RUN apt-get update \
    && apt-get install -y dnsmasq wireless-tools dbus xterm \
                          v4l-utils nano bc wget unzip netcat alsa-utils build-essential git usbutils openssh-server \
                          python3 python3-gi \
                          gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
                          gstreamer1.0-plugins-ugly gstreamer1.0-omx gstreamer1.0-alsa \
                          autoconf automake libtool pkg-config \
                          libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libraspberrypi-dev \
                          libmp3lame-dev libx264-dev yasm git libass-dev libfreetype6-dev libtheora-dev libvorbis-dev \
                          texi2html zlib1g-dev libomxil-bellagio-dev libasound2-dev

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

WORKDIR /usr/src/app

# Build FFMPEG
RUN cd ~ \
    && git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg 

RUN cd ~/ffmpeg \
    && ./configure --enable-libfreetype --enable-gpl --enable-nonfree --enable-libx264 --enable-libass \
                  --enable-libmp3lame --bindir="/usr/local/bin" --enable-omx --enable-omx-rpi --enable-indev=alsa --enable-outdev=alsa

RUN cd ~/ffmpeg \
    && make

RUN cd ~/ffmpeg \
    && make install

RUN [ "cross-build-end" ]  
