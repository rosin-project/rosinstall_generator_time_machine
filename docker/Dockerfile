FROM ubuntu:xenial

# TODO: clean up layers

ARG BUILD_VERSION

LABEL maintainer="g.a.vanderhoorn@tudelft.nl"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.version=$BUILD_VERSION
LABEL org.label-schema.vcs-url="https://github.com/rosin-project/rosinstall_generator_time_machine.git"
LABEL org.label-schema.name="robust-rosin/rosinstall_generator_time_machine"
LABEL org.label-schema.description="Runtime infrastructure for rosinstall_generator_time_machine of the robust-rosin project."

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      git-core \
      python-distribute \
      python-pip \
      python-requests \
      python-setuptools \
      python-virtualenv \
      python-wheel \
      virtualenv \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# create virtualenvs
WORKDIR /rgtm
RUN virtualenv -p python2.7 pre141 \
 && virtualenv -p python2.7 post141

# setup pre venv
# use older version of setuptools or things won't build
RUN /rgtm/pre141/bin/pip --no-python-version-warning install -U 'pip<21.0' \
 && /rgtm/pre141/bin/pip --no-python-version-warning install -U wheel setuptools==20.1.1 \
 && /rgtm/pre141/bin/pip --no-python-version-warning install nose==1.3.7 \
 && /rgtm/pre141/bin/pip --no-python-version-warning install \
      git+https://github.com/rosin-project/rosdistro_python@rosin_bughunt_0.2.20#egg=rosdistro \
      rosinstall==0.7.2 \
      rosdep==0.10.24 \
      rosinstall_generator==0.1.5 \
      catkin_pkg==0.4.16 \
      rospkg==1.2.3 \
      distribute==0.7.3 \
      pyyaml==5.3 \
      vcstools==0.1.38 \
 && rm -rf /root/.cache/pip

# setup post venv
RUN /rgtm/post141/bin/pip --no-python-version-warning install -U 'pip<21.0' \
 && /rgtm/post141/bin/pip --no-python-version-warning install -U wheel setuptools==44.0.0 \
 && /rgtm/post141/bin/pip --no-python-version-warning install \
      git+https://github.com/rosin-project/rosdistro_python@rosin_bughunt_0.8.3_test#egg=rosdistro \
      rosinstall_generator \
 && rm -rf /root/.cache/pip

WORKDIR /rgtm/work
VOLUME ["/rgtm/work"]
CMD ["bash"]
