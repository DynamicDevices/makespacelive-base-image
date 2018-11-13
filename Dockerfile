FROM resin/raspberrypi3-debian:stretch

RUN [ "cross-build-start" ]

# Install dependencies
RUN apt-get update \
    && apt-get install -y dnsmasq wireless-tools dbus xterm \
                          v4l-utils nano bc wget unzip netcat alsa-utils build-essential git usbutils openssh-server \
                          python3 python3-gi python3-matplotlib python3-matplotlib python3-pip \
                          gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
                          gstreamer1.0-plugins-ugly gstreamer1.0-omx gstreamer1.0-alsa \
                          autoconf automake libtool pkg-config \
                          libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libraspberrypi-dev \
                          libmp3lame-dev libx264-dev yasm git libass-dev libfreetype6-dev libtheora-dev libvorbis-dev \
                          texi2html zlib1g-dev libomxil-bellagio-dev libasound2-dev \
                          cmake \
                          ocl-icd-opencl-dev \
                          libjpeg-dev libtiff5-dev libjasper-dev libpng-dev \
                          libavcodec-dev libavformat-dev libswscale-dev libv4l-dev \
                          libgtk2.0-dev libatlas-base-dev gfortran \
			  apt-transport-https \
                          default-jre

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

WORKDIR /usr/src/app

# Install Jupyter
RUN python3 -m pip install jupyter

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

# Build OpenCV
RUN cd ~ && git clone https://github.com/Itseez/opencv.git

RUN cd ~ && cd opencv && git checkout 3.4.3

RUN cd ~ && git clone https://github.com/opencv/opencv_contrib.git

RUN cd ~ && cd opencv_contrib && git checkout 3.4.3

RUN cd ~ && cd opencv && mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. && make && make install && ldconfig

RUN [ "cross-build-end" ]  
