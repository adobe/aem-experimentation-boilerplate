# AEM Experimentation Boilerplate

This is a boilerplate for AEM experimentation. It builds upon the [AEM Boilerplate](https://github.com/adobe/aem-boilerplate) with these Configurations:

- Integration of the updated Experimentation Engine (V2) - see https://github.com/adobe/aem-experimentation/pull/28
- Sidekick configuration with the latest experimentation UI rail

## Environments

- Preview: https://main--aem-experimentation-boilerplate--adobe.aem.page/
- Live: https://main--aem-experimentation-boilerplate--adobe.aem.live/

## Documentation

Before using the aem-boilerplate, we recommand you to go through the documentation on https://www.aem.live/docs/ and more specifically:

1. [Developer Tutorial](https://www.aem.live/developer/tutorial)
2. [The Anatomy of a Project](https://www.aem.live/developer/anatomy-of-a-project)
3. [Web Performance](https://www.aem.live/developer/keeping-it-100)
4. [Markup, Sections, Blocks, and Auto Blocking](https://www.aem.live/developer/markup-sections-blocks)

## Installation

```sh
npm i
```

## Linting

```sh
npm run lint
```

## Local development

1. Create a new repository based on the `aem-boilerplate` template and add a mountpoint in the `fstab.yaml`
1. Add the [AEM Code Sync GitHub App](https://github.com/apps/aem-code-sync) to the repository
1. Install the [AEM CLI](https://github.com/adobe/helix-cli): `npm install -g @adobe/aem-cli`
1. Start AEM Proxy: `aem up` (opens your browser at `http://localhost:3000`)
1. Open the `{repo}` directory in your favorite IDE and start coding :)