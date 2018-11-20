FROM resin/raspberrypi3-debian:stretch

RUN [ "cross-build-start" ]

# Install dependencies
RUN apt-get update \
    && apt-get install -y dnsmasq wireless-tools dbus xterm \
                          v4l-utils nano bc wget unzip netcat alsa-utils build-essential git usbutils openssh-server \
                          python3 python3-gi python3-pip python3-setuptools python3-matplotlib\
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
                          default-jre \
                          build-essential autotools-dev automake autoconf \
                          libtool autopoint libxml2-dev zlib1g-dev libglib2.0-dev \
                          pkg-config bison flex python3 git gtk-doc-tools libasound2-dev \
                          libgudev-1.0-dev libxt-dev libvorbis-dev libcdparanoia-dev \
                          libpango1.0-dev libtheora-dev libvisual-0.4-dev iso-codes \
                          libgtk-3-dev libraw1394-dev libiec61883-dev libavc1394-dev \
                          libv4l-dev libcairo2-dev libcaca-dev libspeex-dev libpng-dev \
                          libshout3-dev libjpeg-dev libaa1-dev libflac-dev libdv4-dev \
                          libtag1-dev libwavpack-dev libpulse-dev libsoup2.4-dev libbz2-dev \
                          libcdaudio-dev libdc1394-22-dev ladspa-sdk libass-dev \
                          libcurl4-gnutls-dev libdca-dev libdirac-dev libdvdnav-dev \
                          libexempi-dev libexif-dev libfaad-dev libgme-dev libgsm1-dev \
                          libiptcdata0-dev libkate-dev libmimic-dev libmms-dev \
                          libmodplug-dev libmpcdec-dev libofa0-dev libopus-dev \
                          librsvg2-dev librtmp-dev libschroedinger-dev libslv2-dev \
                          libsndfile1-dev libsoundtouch-dev libspandsp-dev libx11-dev \
                          libxvidcore-dev libzbar-dev libzvbi-dev liba52-0.7.4-dev \
                          libcdio-dev libdvdread-dev libmad0-dev libmp3lame-dev \
                          libmpeg2-4-dev libopencore-amrnb-dev libopencore-amrwb-dev \
                          libsidplay1-dev libtwolame-dev libx264-dev libusb-1.0 \
                          python-gi-dev yasm python3-dev libgirepository1.0-dev \
                          gettext \
                          libjson-glib-dev libopus-dev libvpx-dev

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

WORKDIR /usr/src/app

# Build needed version of nice for gstreamer
RUN wget https://nice.freedesktop.org/releases/libnice-0.1.14.tar.gz
RUN tar xaf libnice-0.1.14.tar.gz && cd libnice-0.1.14 && ./configure && make -j4 install

# Clone gstreamer git repos if they are not there yet
RUN [ ! -d gstreamer ] && git clone git://anongit.freedesktop.org/git/gstreamer/gstreamer
RUN [ ! -d gst-plugins-base ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-base
RUN [ ! -d gst-plugins-good ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-good
RUN [ ! -d gst-plugins-bad ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-bad
RUN [ ! -d gst-plugins-ugly ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-ugly
RUN [ ! -d gst-omx ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-omx

RUN export LD_LIBRARY_PATH=/usr/local/lib/ && cd gstreamer && ./autogen.sh --disable-gtk-doc && make -j4 && make install

RUN cd gst-plugins-base && ./autogen.sh --disable-gtk-doc && make -j4 && make install

RUN cd gst-plugins-good && ./autogen.sh --disable-gtk-doc && make -j4 && make install

# Build gstreamer-plugins-bad
RUN cd gst-plugins-bad && ./autogen.sh --disable-gtk-doc \
 && export CFLAGS='-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/' \
 && export LDFLAGS='-L/opt/vc/lib' \
 && ./configure CFLAGS='-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/' LDFLAGS='-I/opt/vc/lib' \
--disable-gtk-doc --disable-opengl --enable-gles2 --enable-egl --disable-glx \
--disable-x11 --disable-wayland --enable-dispmanx \
--with-gles2-module-name=/opt/vc/lib/libGLESv2.so \
--with-egl-module-name=/opt/vc/lib/libEGL.so \
--enable-webrtc --disable-examples
RUN cd gst-plugins-bad && make CFLAGS+='-Wno-error -Wno-redundant-decls' LDFLAGS+='-L/opt/vc/lib' -j4 && sudo make install

# omx support
RUN cd gst-omx && export LDFLAGS='-L/opt/vc/lib' \
CFLAGS='-I/opt/vc/include -I/opt/vc/include/IL -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/IL' \
CPPFLAGS='-I/opt/vc/include -I/opt/vc/include/IL -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/IL' \
&& ./autogen.sh --disable-gtk-doc --with-omx-target=rpi \
&& make CFLAGS+='-Wno-error -Wno-redundant-decls' LDFLAGS+='-L/opt/vc/lib' -j4 \
&& sudo make install

# Setup gst-rpicamsrc
RUN git clone https://github.com/thaytan/gst-rpicamsrc.git
RUN cd gst-rpicamsrc && ./autogen.sh && make && make install

# Install FFMPEG Python bindings
#RUN pip3 install wheel
#RUN pip3 install ffmpeg-python

# Build FFMPEG
#RUN cd ~ \
#    && git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg 
#RUN cd ~/ffmpeg \
#    && ./configure --enable-libfreetype --enable-gpl --enable-nonfree --enable-libx264 --enable-libass \
#                  --enable-libmp3lame --bindir="/usr/local/bin" --enable-omx --enable-omx-rpi --enable-indev=alsa --enable-outdev=alsa
#RUN cd ~/ffmpeg \
#    && make
#RUN cd ~/ffmpeg \
#    && make install

# Build OpenCV (not working?)
#RUN cd ~ && git clone https://github.com/Itseez/opencv.git
#RUN cd ~ && cd opencv && git checkout 3.4.3
#RUN cd ~ && git clone https://github.com/opencv/opencv_contrib.git
#RUN cd ~ && cd opencv_contrib && git checkout 3.4.3
#RUN cd ~ && cd opencv && mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. && make && make install && ldconfig

RUN [ "cross-build-end" ]  

