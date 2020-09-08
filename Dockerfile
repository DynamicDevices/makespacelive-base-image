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
RUN apk add ffmpeg-dev git alpine-sdk libass-dev lame-dev pulseaudio-dev x264-dev meson alsa-lib-dev

#
# Build OpenH264
#
#RUN git clone https://github.com/cisco/openh264 && cd openh264 && meson build && meson configure --prefix=/build && meson compile install
RUN git clone https://github.com/cisco/openh264 
RUN cd openh264 && meson setup . build && meson configure build -Dprefix=/build && ninja -C build && ninja -C build install

#
# Clone gstreamer git repos if they are not there yet
#
RUN [ ! -d gstreamer ] && git clone git://anongit.freedesktop.org/git/gstreamer/gstreamer && cd gstreamer && git show

RUN [ ! -d gst-plugins-base ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-base && cd gst-plugins-base && git show
RUN [ ! -d gst-plugins-good ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-good && cd gst-plugins-good && git show
RUN [ ! -d gst-plugins-bad ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-bad && cd gst-plugins-bad && git show
RUN [ ! -d gst-plugins-ugly ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-plugins-ugly && cd gst-plugins-ugly && git show
RUN [ ! -d gst-omx ] && git clone git://anongit.freedesktop.org/git/gstreamer/gst-omx && cd gst-omx && git show

RUN apk add flex bison cmake gdk-pixbuf-dev gtk+3.0-dev libogg-dev libvorbis-dev orc-dev gstreamer-dev libcap-dev libjpeg raspberrypi-dev libgudev-dev sdl2-dev gobject-introspection-dev

#
# GStreamer
#

# TODO: Introspection fails? -Dintrospection=enabled
RUN export LD_LIBRARY_PATH=/usr/lib \
    && cd gstreamer && meson setup . build && meson configure build \
    -Dprefix=/build -Dtests=disabled -Dexamples=disabled -Ddoc=disabled -Dbenchmarks=disabled -Dcheck=enabled -Dintrospection=disabled \
    && meson configure build \
    && ninja -C build -j4 install

RUN cp -rpf /build/* /usr

# GStreamer plugins { base, good }
RUN export LD_LIBRARY_PATH=/usr/lib:/opt/vc/lib \
    && export LDFLAGS='-L/opt/vc/lib' && cd gst-plugins-base \
    && export CFLAGS='-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/' \
    && meson setup . build \
    && meson configure build \
    -Dprefix=/build -Dtests=disabled -Dexamples=disabled -Ddoc=disabled -Dbenchmarks=disabled -Dcheck=disabled -Dintrospection=disabled \
    && meson configure build \
    && ninja -C build -j4 install

RUN cp -rpf /build/* /usr

RUN apk add libsoup-dev

RUN cd gst-plugins-good && meson setup . build && meson configure build \
    -Dprefix=/build -Dtests=disabled -Dexamples=disabled -Ddoc=disabled -Dbenchmarks=disabled -Dcheck=disabled -Dintrospection=disabled \
    -Dpulse=enabled -Drpicamsrc=enabled -Drtp=enabled -Drtpmanager=enabled -Drtsp=enabled -Dv4l2=enabled \
    && meson configure build \
    && ninja -C build -j4 install

RUN cp -rpf /build/* /usr

#
# Build needed version of nice for Gstreamer plugins bad
#
#RUN wget https://nice.freedesktop.org/releases/libnice-0.1.14.tar.gz
#RUN tar xaf libnice-0.1.14.tar.gz && cd libnice-0.1.14 && ./configure --prefix=/build --with-gstreamer && make -j4 install
RUN apk add libnice-dev

#
# Build lksctp (configure???)
#
#RUN git clone git://github.com/sctp/lksctp-tools.git
#RUN cd lksctp-tools && git checkout lksctp-tools-1.0.17
#RUN cd lksctp-tools && ./bootstrap
RUN apk add lksctp-tools

#
# Build OpenCV (after we've built GStreamer so it gets detected)
#
RUN cd ~ && git clone https://github.com/Itseez/opencv.git
RUN cd ~ && cd opencv && git checkout 4.4.0
RUN cd ~ && git clone https://github.com/opencv/opencv_contrib.git
RUN cd ~ && cd opencv_contrib && git checkout 4.4.0

RUN apk add py3-numpy

RUN cd ~ && cd opencv && mkdir build && cd build && cmake -DOPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/build \
            -D ENABLE_NEON=ON \
            -D ENABLE_VFPV3=ON \
            -D BUILD_TESTS=OFF \
            -D INSTALL_PYTHON_EXAMPLES=OFF \
            -D BUILD_EXAMPLES=OFF .. \
            -DOPENCV_GENERATE_PKGCONFIG=ON 
RUN cd ~/opencv/build && make -j4
RUN cd ~/opencv/build &&  make install

RUN cp -rpf /build/* /usr

# NOTE: librtmp.pc is in here (!)
RUN apk add rtmpdump-dev libsrtp-dev tcl openssl-dev

# Build libsrt
RUN git clone https://github.com/Haivision/srt.git
RUN cd srt && chmod a+x configure  && ./configure --prefix=/build && make -j4 && make install
RUN cp -rpf /build/* /usr

RUN apk add vo-aacenc-dev

#
# Gstreamer-plugins-bad
#
RUN cd gst-plugins-bad && meson setup . build \
    && export CFLAGS='-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/ -Wno-error -Wno-redundant-decls' \
    && export LDFLAGS='-L/opt/vc/lib -L/usr/lib' \
    && export LD_LIBRARY_PATH=/usr/lib \
    && meson configure build \
    -Dprefix=/build -Dtests=disabled -Dexamples=disabled -Ddoc=disabled -Dintrospection=disabled \
    -Dopencv=enabled -Dopenh264=enabled -Drtmp=enabled -Drtmp2=enabled -Dsctp=enabled -Dsrt=enabled \
    -Dsrtp=enabled -Dv4l2codecs=enabled -Dvideofilters=enabled -Dvideoparsers=enabled -Dvoaacenc=enabled \
    -Dwebrtc=enabled \
    && meson configure build \
    && ninja -C build -j4 install

#
# GStreamer OMX support
#
#    && export LDFLAGS='-L/opt/vc/lib' \
#    && export CFLAGS='-I/opt/vc/include -I/opt/vc/include/IL -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/IL -Wno-error -Wno-redundant-decls' \
#    && export CPPFLAGS='-I/opt/vc/include -I/opt/vc/include/IL -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -I/opt/vc/include/IL' \
#

RUN export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/opt/vc/lib/pkgconfig \
    && cd gst-omx && meson setup . build -Dtarget=rpi \
    && meson configure build  -Dprefix=/build -Dgtk-doc=disabled -Dtarget=rpi -Dheader_path=/opt/vc/include/IL -Ddoc=disabled -Dexamples=disabled \
    && meson configure build \
    && ninja -C build -j4 install

#
# GStreamer  gst-rpicamsrc
#
#RUN git clone https://github.com/thaytan/gst-rpicamsrc.git
#RUN cd gst-rpicamsrc && ./autogen.sh --prefix=/build && make && make install

#
# Build FFMPEG
#
RUN git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg 

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
RUN apk add ffmpeg gstreamer libpulse raspberrypi raspberrypi-libs libsoup libnice lksctp-tools rtmpdump libsrtp openssl vo-aacenc alsa-utils libgudev wayland pango cairo-gobject directfb gtk+3.0 mesa-egl

# Copy across new ffmpeg files
COPY --from=build /src/ffmpeg/build/ /usr/
COPY --from=build /build/ /usr/

RUN ln -s /opt/vc/lib/libEGL.so /opt/vc/lib/libEGL.so.1

#RUN chmod +x launcher.sh
#CMD ["./launcher.sh"]

RUN [ "cross-build-end" ]  
