# Changelog

## [2.1.0](https://github.com/this-is-tobi/tools/compare/act-runner-v2.0.6...act-runner-v2.1.0) (2026-08-04)


### Features

* **docker:** install runner tooling with mise ([c1808b5](https://github.com/this-is-tobi/tools/commit/c1808b5a87494115850875c3ffc1050fd0bc85e4))


### Bug Fixes

* **docker:** install libatomic1 in the runner images ([4cba083](https://github.com/this-is-tobi/tools/commit/4cba083da2c91f798a2129f4e1a6bf32ff22ab47))
* **docker:** scheduled dependency refresh ([bf4a32a](https://github.com/this-is-tobi/tools/commit/bf4a32a11a2791ceca802ad1bf12261d079d7790))


### Performance Improvements

* **docker:** merge the two apt layers in the ubuntu runners ([eebdd2b](https://github.com/this-is-tobi/tools/commit/eebdd2b7fd456dddbd11d38478f767ac2cca0ff3))


### Code Refactoring

* **docker:** drop awscli from runner images ([9b79696](https://github.com/this-is-tobi/tools/commit/9b79696dd865f1ce0df940c5d9c04db54a4d8e7b))


### Dependencies

* **deps:** update docker.io/ubuntu base image to 678c655 ([bc2317f](https://github.com/this-is-tobi/tools/commit/bc2317f85ca3423566029eab71c2b900aa35e909))
* **docker:** harden the image pipeline ([a7c2887](https://github.com/this-is-tobi/tools/commit/a7c2887ce29280c5f74c8c5669ca3b203d1f2919))
* **docker:** pin active base images by digest ([00875b1](https://github.com/this-is-tobi/tools/commit/00875b154f877dd214bcb6ed26189b5c8dedc935))

## [2.0.6](https://github.com/this-is-tobi/tools/compare/act-runner-v2.0.5...act-runner-v2.0.6) (2026-07-17)


### Bug Fixes

* **deps:** update docker.io/ubuntu base image to v26 ([5508bd2](https://github.com/this-is-tobi/tools/commit/5508bd2e612dfc93b4d65a94bf8cd9052369c647))

## [2.0.5](https://github.com/this-is-tobi/tools/compare/act-runner-v2.0.4...act-runner-v2.0.5) (2026-07-17)


### Bug Fixes

* **docker:** pin proto tool versions in act-runner build ([ccdefd6](https://github.com/this-is-tobi/tools/commit/ccdefd66a48ab7b7e34c885b08e846b49115688b))
