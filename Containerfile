# SPDX-License-Identifier: MPL-2.0
# Verification image for the Julia package; sibling packages are pinned source
# dependencies, not evidence that the projects have a shared database purpose.
#   podman build -t skein-check .
FROM docker.io/library/julia:1.12.6@sha256:3688355d393347055ab3fe866dbb4231e5840ab9808382618996958f6f4a2489
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
RUN git init AcceleratorGate.jl \
 && git -C AcceleratorGate.jl fetch --depth 1 https://github.com/hyperpolymath/AcceleratorGate.jl.git b24e9f00d89edd5a4a7940252799737024c32d41 \
 && git -C AcceleratorGate.jl checkout --detach FETCH_HEAD \
 && git init KnotTheory.jl \
 && git -C KnotTheory.jl fetch --depth 1 https://github.com/hyperpolymath/KnotTheory.jl.git 58a904d28212817053a14f73b415fd30a434857c \
 && git -C KnotTheory.jl checkout --detach FETCH_HEAD
WORKDIR /workspace/Skein.jl
COPY Project.toml Manifest.toml ./
COPY src/ src/
COPY ext/ ext/
COPY test/ test/
RUN julia --startup-file=no --project=. -e 'using Pkg; Pkg.Registry.add("General"); Pkg.resolve(); Pkg.instantiate(); Pkg.test()'
CMD ["julia", "--startup-file=no", "--project=.", "-e", "using Skein; println(\"Skein loaded\")"]
