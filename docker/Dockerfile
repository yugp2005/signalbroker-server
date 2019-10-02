FROM elixir:1.7.4 AS build-env

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
       apt-get install -y --no-install-recommends \
               curl ca-certificates sudo locales \
               apt-transport-https \
               iproute2 can-utils \
               vim tmux \
               build-essential git make gcc cmake cmake-curses-gui

ENV LANG en_US.UTF-8
RUN echo "en_US.UTF-8 UTF-8" >/etc/locale.gen && locale-gen

# RUN curl -sO https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb \
#     && dpkg -i erlang-solutions_1.0_all.deb

# RUN apt-get install apt-transport-https ca-certificates

#RUN curl -s https://packages.erlang-solutions.com/debian/erlang_solutions.asc \
#     | apt-key add -
#RUN printf "deb https://packages.erlang-solutions.com/debian stretch contrib\n" \
#     >>/etc/apt/sources.list.d/erlang-solutions.list

#RUN apt-get update \
#    && DEBIAN_FRONTEND=noninteractive \
#       apt-get install -y --no-install-recommends \
#               esl-erlang \
#               elixir=1.7.4-*

# # For erlang dev env, code coverage etc
# RUN apt-get install -y --no-install-recommends \
#             erlang-dev erlang-tools erlang-common-test

ARG MIX_ENV=prod

# RUN uname -a
RUN mix local.hex --force
RUN mix local.rebar --force

COPY . /signalbroker/
WORKDIR /signalbroker
RUN rm -rf _build
RUN rm -rf deps
RUN mix deps.get
RUN mix release


FROM debian:stretch

# NOTE: libssl1.0.0 is a run-time dependency of service_client, which happens
# to not be installed on ubuntu:16.04 (raspbian has it, because it comes with
# curl pre-installed)
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
       apt-get install -y --no-install-recommends \
               locales \
               libssl1.1

ENV LANG en_US.UTF-8
RUN echo "en_US.UTF-8 UTF-8" >/etc/locale.gen && locale-gen

#EXPOSE 4040

WORKDIR /signalbroker

COPY --from=build-env signalbroker/_build ./_build/
COPY --from=build-env signalbroker/configuration ./_build/prod/rel/signal_server/configuration/

ENTRYPOINT ["_build/prod/rel/signal_server/bin/signal_server", "console"]
