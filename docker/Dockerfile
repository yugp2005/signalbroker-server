FROM elixir:1.8.1 AS build-env

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

ARG MIX_ENV=prod

RUN mix local.hex --force
RUN mix local.rebar --force

COPY . /signalbroker/
WORKDIR /signalbroker
RUN rm -rf _build
RUN rm -rf deps
RUN mix deps.get
RUN mix test --only success
RUN mix release


FROM debian:stretch

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
       apt-get install -y --no-install-recommends \
               locales \
               libssl1.1

ENV LANG en_US.UTF-8
RUN echo "en_US.UTF-8 UTF-8" >/etc/locale.gen && locale-gen

WORKDIR /signalbroker

COPY --from=build-env signalbroker/_build ./_build/
COPY --from=build-env signalbroker/configuration ./_build/prod/rel/signal_server/configuration/

ENTRYPOINT ["_build/prod/rel/signal_server/bin/signal_server", "console"]
